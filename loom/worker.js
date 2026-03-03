const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DIAGNOSTIC_CACHE_TTL_SECONDS = 60 * 60 * 24 * 14; // 14 days

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (url.pathname !== "/diagnostic/insights") {
      return json({ error: "Not found" }, 404, corsHeaders(request));
    }

    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405, corsHeaders(request));
    }

    const apiKey = typeof env.OPENAI_API_KEY === "string" ? env.OPENAI_API_KEY.trim() : "";
    if (!apiKey) {
      return json({ error: "Server misconfigured" }, 500, corsHeaders(request));
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400, corsHeaders(request));
    }

    const validationError = validateDiagnosticPayload(payload);
    if (validationError) {
      return json({ error: "Invalid diagnostic payload", details: validationError }, 400, corsHeaders(request));
    }

    const diagnostic = payload.diagnostic;
    const client = payload.client || {};
    const startedAt = Date.now();

    const normalizedDiagnostic = canonicalizeDiagnostic({
      stress: diagnostic.stress,
      breaksFirst: diagnostic.breaksFirst,
      areas: diagnostic.areas,
      planningStyle: diagnostic.planningStyle,
      firstChange: diagnostic.firstChange
    });
    const diagnosticHash = await sha256Hex(JSON.stringify(normalizedDiagnostic));
    const cacheKey = new Request(`https://loom-cache.internal/diagnostic/${diagnosticHash}`);

    if (env.DEBUG_DIAGNOSTIC !== "1") {
      const cached = await caches.default.match(cacheKey);
      if (cached) {
        try {
          const cachedJSON = await cached.json();
          if (cachedJSON && typeof cachedJSON === "object") {
            return json(cachedJSON, 200, corsHeaders(request));
          }
        } catch {
          // Ignore cache decode issue and continue.
        }
      }
    }

    // One-call prompt kept concise to reduce prompt tokens.
    const systemPrompt = [
      "You generate Loom's first-signup diagnostic insights.",
      "Ground ONLY in stress, breaksFirst, areas, planningStyle, firstChange.",
      "Do not summarize, restate, or closely paraphrase selected options.",
      "Interpret mechanism-level patterns, not moods.",
      "Use areas only as multi-domain coverage context; do not list/rename selected areas.",
      "Tone: calm, direct, analytical. No hype, praise, or generic advice.",
      "Explain it like I'm a 5th grader. Use simple words and no jargon.",
      "rootCause: 2 short sentences, <=22 words.",
      "nextDirection: 2 short sentences, <=22 words.",
      "nextDirection must describe a structural shift, not a checklist.",
      "Return JSON with keys: rootCause, nextDirection, error.",
      "For normal output, set error=''.",
      "If the answers do not provide enough signal, set error='insufficient_signal' and set rootCause/nextDirection to empty strings."
    ].join("\n");

    const schema = {
      name: "loom_diagnostic_insights",
      strict: true,
      schema: {
        type: "object",
        additionalProperties: false,
        properties: {
          rootCause: { type: "string" },
          nextDirection: { type: "string" },
          error: { type: "string" }
        },
        required: ["rootCause", "nextDirection", "error"]
      }
    };

    const result = await callOpenAIResponsesJSON({
      apiKey,
      model: "gpt-5.1",
      systemPrompt,
      userPayload: {
        diagnostic: normalizedDiagnostic,
        client: {
          appVersion: nonEmptyString(client.appVersion) || null,
          platform: "ios",
          screen: "diagnostic_insights"
        }
      },
      responseSchema: schema,
      maxOutputTokens: 180,
      timeoutMs: 18000
    });

    if (result.error) {
      return json({ error: result.error, details: result.details }, result.status, corsHeaders(request));
    }

    const parsed = result.json;
    if (parsed && typeof parsed.error === "string" && parsed.error.trim() !== "") {
      return json({ error: "Couldn’t generate insights" }, 422, corsHeaders(request));
    }

    const rootCause = normalizeInsightText(parsed?.rootCause);
    const nextDirection = normalizeInsightText(parsed?.nextDirection);

    if (!isValidInsightText(rootCause) || !isValidInsightText(nextDirection)) {
      return json({ error: "Couldn’t generate insights" }, 422, corsHeaders(request));
    }

    const responseBody = { rootCause, nextDirection };
    if (env.DEBUG_DIAGNOSTIC !== "1") {
      const cacheResponse = new Response(JSON.stringify(responseBody), {
        status: 200,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": `public, max-age=0, s-maxage=${DIAGNOSTIC_CACHE_TTL_SECONDS}`
        }
      });
      await caches.default.put(cacheKey, cacheResponse);
    }

    if (env.DEBUG_DIAGNOSTIC === "1") {
      responseBody.debug = {
        usedFields: ["stress", "breaksFirst", "areas", "planningStyle", "firstChange"],
        model: "gpt-5",
        latencyMs: Date.now() - startedAt
      };
    }

    return json(responseBody, 200, corsHeaders(request));
  }
};

async function callOpenAIResponsesJSON({
  apiKey,
  model,
  systemPrompt,
  userPayload,
  responseSchema,
  maxOutputTokens,
  timeoutMs
}) {
  const attempts = [
    {
      maxOutputTokens: Math.max(160, maxOutputTokens),
      timeoutMs: Math.max(15000, timeoutMs),
      promptSuffix: ""
    },
    {
      maxOutputTokens: Math.max(450, Math.floor(maxOutputTokens * 2.3)),
      timeoutMs: Math.max(28000, timeoutMs + 10000),
      promptSuffix: "\nReturn final JSON now. Keep each field short."
    }
  ];

  let lastError = {
    error: "Missing model output",
    details: "No attempts executed.",
    status: 502
  };

  for (let i = 0; i < attempts.length; i += 1) {
    const attempt = attempts[i];
    const attemptResult = await performOpenAIResponsesAttempt({
      apiKey,
      model,
      systemPrompt: `${systemPrompt}${attempt.promptSuffix}`,
      userPayload,
      responseSchema,
      maxOutputTokens: attempt.maxOutputTokens,
      timeoutMs: attempt.timeoutMs
    });

    if (attemptResult.ok) {
      return attemptResult.result;
    }

    lastError = attemptResult.result;
    if (!attemptResult.retryable) {
      return lastError;
    }
  }

  return lastError;
}

async function performOpenAIResponsesAttempt({
  apiKey,
  model,
  systemPrompt,
  userPayload,
  responseSchema,
  maxOutputTokens,
  timeoutMs
}) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), Math.max(1000, timeoutMs | 0));

  let openAIResponse;
  try {
    openAIResponse = await fetch(OPENAI_RESPONSES_URL, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        input: [
          {
            role: "system",
            content: [
              { type: "input_text", text: systemPrompt }
            ]
          },
          {
            role: "user",
            content: [
              { type: "input_text", text: JSON.stringify(userPayload) }
            ]
          }
        ],
        reasoning: {
          effort: "low"
        },
        text: {
          format: {
            type: "json_schema",
            name: responseSchema.name,
            schema: responseSchema.schema,
            strict: responseSchema.strict
          }
        },
        max_output_tokens: maxOutputTokens
      })
    });
  } catch (e) {
    clearTimeout(t);
    const isAbort = e && typeof e === "object" && String(e.name) === "AbortError";
    return {
      ok: false,
      retryable: isAbort,
      result: {
        error: isAbort ? "Upstream timeout" : "Upstream request failed",
        details: isAbort ? "Model request exceeded timeout" : null,
        status: 502
      }
    };
  } finally {
    clearTimeout(t);
  }

  const upstreamText = await openAIResponse.text();

  if (!openAIResponse.ok) {
    return {
      ok: false,
      retryable: false,
      result: {
        error: "Upstream model error",
        details: truncate(upstreamText, 1000),
        status: 502
      }
    };
  }

  let parsed;
  try {
    parsed = JSON.parse(upstreamText);
  } catch {
    return {
      ok: false,
      retryable: false,
      result: { error: "Invalid upstream JSON", status: 502 }
    };
  }

  const obj = extractResponsesParsedObject(parsed);
  if (obj && typeof obj === "object") {
    return { ok: true, retryable: false, result: { json: obj, status: 200 } };
  }

  const retryableMissingOutput = shouldRetryMissingOutput(parsed);
  return {
    ok: false,
    retryable: retryableMissingOutput,
    result: {
      error: "Missing model output",
      details: truncate(upstreamText, 1000),
      status: 502
    }
  };
}

function extractResponsesParsedObject(parsed) {
  // Responses API commonly returns an `output` array with content parts.
  const out = Array.isArray(parsed?.output) ? parsed.output : [];
  for (const item of out) {
    const content = Array.isArray(item?.content) ? item.content : [];
    for (const part of content) {
      // Structured Outputs often place the parsed JSON here:
      if (part && typeof part === "object" && part.type === "output_text") {
        // sometimes `text` is a stringified JSON, sometimes `parsed` exists
        if (part.parsed && typeof part.parsed === "object") return part.parsed;
        if (typeof part.text === "string") {
          const txt = part.text.trim();
          if (!txt) continue;
          try {
            return JSON.parse(txt);
          } catch {
            // ignore
          }
        }
      }
      // fallback: some variants may store parsed directly on the part
      if (part?.parsed && typeof part.parsed === "object") return part.parsed;
    }
  }

  // extra fallback: output_text convenience field
  if (typeof parsed?.output_text === "string") {
    const txt = parsed.output_text.trim();
    if (txt) {
      try {
        return JSON.parse(txt);
      } catch {
        return null;
      }
    }
  }

  return null;
}

function shouldRetryMissingOutput(parsed) {
  const status = String(parsed?.status || "").toLowerCase();
  const incompleteReason = String(parsed?.incomplete_details?.reason || "").toLowerCase();
  if (status === "incomplete" && incompleteReason === "max_output_tokens") {
    return true;
  }

  const outputItems = Array.isArray(parsed?.output) ? parsed.output : [];
  if (outputItems.length > 0) {
    const onlyReasoning = outputItems.every((item) => String(item?.type || "").toLowerCase() === "reasoning");
    if (onlyReasoning) return true;
  }

  return false;
}

function canonicalizeDiagnostic(input) {
  const normalize = (value) => String(value ?? "").trim();
  const areas = uniqueOrdered(
    (Array.isArray(input?.areas) ? input.areas : [])
      .map((x) => normalize(x))
      .filter(Boolean)
  ).sort((a, b) => a.localeCompare(b, "en", { sensitivity: "base" }));

  return {
    stress: normalize(input?.stress),
    breaksFirst: normalize(input?.breaksFirst),
    areas,
    planningStyle: normalize(input?.planningStyle),
    firstChange: normalize(input?.firstChange)
  };
}

function uniqueOrdered(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const key = item.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(item);
  }
  return result;
}

async function sha256Hex(text) {
  const bytes = new TextEncoder().encode(String(text ?? ""));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  const arr = Array.from(new Uint8Array(digest));
  return arr.map((b) => b.toString(16).padStart(2, "0")).join("");
}

function validateDiagnosticPayload(payload) {
  if (!payload || typeof payload !== "object") return "Body must be an object";
  if (!payload.diagnostic || typeof payload.diagnostic !== "object") return "diagnostic is required";

  const diagnostic = payload.diagnostic;
  const stringFields = ["stress", "breaksFirst", "planningStyle", "firstChange"];
  for (const key of stringFields) {
    if (!nonEmptyString(diagnostic[key])) {
      return `${key} must be a non-empty string`;
    }
  }

  if (!Array.isArray(diagnostic.areas)) {
    return "areas must be an array";
  }
  if (diagnostic.areas.length < 3 || diagnostic.areas.length > 7) {
    return "areas must contain 3-7 items";
  }
  for (const item of diagnostic.areas) {
    if (!nonEmptyString(item)) {
      return "areas must contain only non-empty strings";
    }
  }

  return null;
}

function nonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : "";
}

function normalizeInsightText(value) {
  if (typeof value !== "string") return "";
  return value.replace(/\s+/g, " ").trim();
}

function isValidInsightText(value) {
  if (!value) return false;

  // Word cap to enforce brevity
  const words = value.split(/\s+/).filter(Boolean);
  if (words.length > 22) return false;

  const sentences = value
    .split(/[.!?]+/)
    .map((s) => s.trim())
    .filter(Boolean);

  return sentences.length >= 2 && sentences.length <= 3;
}

function truncate(value, maxChars) {
  const text = typeof value === "string" ? value : "";
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}…`;
}

function corsHeaders(request) {
  const origin = request.headers.get("Origin");
  return {
    "Access-Control-Allow-Origin": origin || "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Vary": "Origin",
    "Content-Type": "application/json; charset=utf-8"
  };
}

function json(payload, status, headers = {}) {
  return new Response(JSON.stringify(payload), {
    status,
    headers
  });
}
