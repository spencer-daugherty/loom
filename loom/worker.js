const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DIAGNOSTIC_CACHE_TTL_SECONDS = 60 * 60 * 24 * 14; // 14 days

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (url.pathname === "/purpose/vision/autowrite") {
      return handlePurposeVisionAutowrite(request, env);
    }

    if (url.pathname === "/chat") {
      return handleChat(request, env);
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

    const systemPrompt = [
      "You generate first-signup diagnostic insights for Loom.",
      "Write it as if I was a 5th grader: simple words, short sentences, no jargon.",
      "",
      "Hard rules:",
      "- Use ONLY these fields as grounding: stress, breaksFirst, areas, planningStyle, firstChange.",
      "- Do not use any external context or generic productivity advice.",
      "- Do not repeat or closely paraphrase the exact option text the user picked.",
      "- Do not praise, hype, reward, or motivate. No cheerleading.",
      "- Do not list, rename, or restate the selected 'areas'. You may refer to them only as 'different parts of life'.",
      "",
      "Output requirements:",
      "- rootCause: 2–3 short sentences, max 40 words total.",
      "- nextDirection: 2–3 short sentences, max 40 words total.",
      "- Explain the mechanism (what is happening) rather than feelings or labels.",
      "- nextDirection must describe one structural shift Loom will introduce (not a checklist).",
      "",
      "Output JSON ONLY in this exact shape:",
      '{"rootCause":"2-3 short sentences.","nextDirection":"2-3 short sentences."}',
      "",
      "If you cannot produce a specific, grounded output confidently from the diagnostic answers, return JSON only:",
      '{"error":"insufficient_signal"}'
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
        model: "gpt-5.1",
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
  timeoutMs,
  reasoningEffort = "low",
  allowRetry = true
}) {
  const firstAttempt = {
    maxOutputTokens: Math.max(120, maxOutputTokens),
    timeoutMs: Math.max(6000, timeoutMs),
    promptSuffix: ""
  };
  const secondAttempt = {
    maxOutputTokens: Math.max(260, Math.floor(maxOutputTokens * 1.8)),
    timeoutMs: Math.max(12000, timeoutMs + 4000),
    promptSuffix: "\nReturn final JSON now. Keep each field short."
  };
  const attempts = allowRetry ? [firstAttempt, secondAttempt] : [firstAttempt];

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
      timeoutMs: attempt.timeoutMs,
      reasoningEffort
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

async function handleChat(request, env) {
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

  if (!isPurposeVisionChatRequest(payload)) {
    return json({ error: "Unsupported chat intent on minimal worker." }, 400, corsHeaders(request));
  }

  const latestUserMessage = extractLatestUserMessage(payload);
  return purposeVisionAutowriteResponse({
    request,
    apiKey,
    payload,
    currentVision: extractCurrentVisionFromInstruction(latestUserMessage),
    previousSuggestions: [],
    mode: extractVisionModeFromInstruction(latestUserMessage)
  });
}

async function handlePurposeVisionAutowrite(request, env) {
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
    return json({
      error: "Invalid JSON body",
      details: buildVisionTroubleshootingDetails("invalid_json_body", {
        feature: "purpose_vision_autowrite"
      })
    }, 400, corsHeaders(request));
  }
  if (!payload || typeof payload !== "object" || !payload.context || typeof payload.context !== "object") {
    return json({
      error: "Invalid payload",
      details: buildVisionTroubleshootingDetails("invalid_payload", {
        feature: "purpose_vision_autowrite",
        reason: "context is required"
      })
    }, 400, corsHeaders(request));
  }

  const currentVision = normalizeSuggestion(payload.currentVision || "");
  const previousSuggestions = uniqueOrdered(
    (Array.isArray(payload.previousSuggestions) ? payload.previousSuggestions : [])
      .map((x) => normalizeSuggestion(String(x ?? "")))
      .filter(Boolean)
  ).slice(0, 8);
  const mode = String(payload.mode || "newVision").trim().toLowerCase() === "rewordvision"
    ? "rewordVision"
    : "newVision";

  return purposeVisionAutowriteResponse({
    request,
    apiKey,
    payload,
    currentVision,
    previousSuggestions,
    mode
  });
}

async function purposeVisionAutowriteResponse({
  request,
  apiKey,
  payload,
  currentVision,
  previousSuggestions,
  mode
}) {
  const requestMeta = {
    feature: "purpose_vision_autowrite",
    mode: String(mode || ""),
    hasCurrentVision: Boolean(String(currentVision || "").trim()),
    previousSuggestionsCount: Array.isArray(previousSuggestions) ? previousSuggestions.length : 0,
    requestId: nonEmptyString(payload?.client?.requestId) || null,
    requestHash: nonEmptyString(payload?.client?.requestHash) || null
  };

  const diagnostic = extractDiagnosticFromChatPayload(payload);
  const normalizedDiagnostic = canonicalizeDiagnosticForVision(diagnostic);

  const diagnosticPrompt = [
    "You generate first-signup diagnostic insights for Loom.",
    "Write it as if I was a 5th grader: simple words, short sentences, no jargon.",
    "",
    "Hard rules:",
    "- Use ONLY these fields as grounding: stress, breaksFirst, areas, planningStyle, firstChange.",
    "- Do not use any external context or generic productivity advice.",
    "- Do not repeat or closely paraphrase the exact option text the user picked.",
    "- Do not praise, hype, reward, or motivate. No cheerleading.",
    "- Do not list, rename, or restate the selected 'areas'. You may refer to them only as 'different parts of life'.",
    "",
    "Output requirements:",
    "- rootCause: 2–3 short sentences, max 40 words total.",
    "- nextDirection: 2–3 short sentences, max 40 words total.",
    "- Explain the mechanism (what is happening) rather than feelings or labels.",
    "- nextDirection must describe one structural shift Loom will introduce (not a checklist).",
    "",
    "Output JSON ONLY in this exact shape:",
    '{"rootCause":"2-3 short sentences.","nextDirection":"2-3 short sentences."}',
    "",
    "If you cannot produce a specific, grounded output confidently from the diagnostic answers, return JSON only:",
    '{"error":"insufficient_signal"}'
  ].join("\n");

  const insightSchema = {
    name: "loom_diagnostic_insights_for_purpose",
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

  let rootCause = "";
  let nextDirection = "";
  const insightResult = await callOpenAIResponsesJSON({
    apiKey,
    model: "gpt-5.1",
    systemPrompt: diagnosticPrompt,
    userPayload: { diagnostic: normalizedDiagnostic },
    responseSchema: insightSchema,
    maxOutputTokens: 130,
    timeoutMs: 8000,
    reasoningEffort: "none",
    allowRetry: false
  });
  if (!insightResult.error) {
    const parsedInsight = insightResult.json || {};
    if (!(typeof parsedInsight.error === "string" && parsedInsight.error.trim() !== "")) {
      rootCause = normalizeInsightText(parsedInsight.rootCause);
      nextDirection = normalizeInsightText(parsedInsight.nextDirection);
    }
  }
  const hasStrongDiagnosticContext = isValidInsightText(rootCause) && isValidInsightText(nextDirection);

  const personalizationHash = await sha256Hex(
    JSON.stringify({
      areas: normalizedDiagnostic.areas,
      rootCause: hasStrongDiagnosticContext ? rootCause : "",
      nextDirection: hasStrongDiagnosticContext ? nextDirection : ""
    })
  );

  const currentVisionSentence = extractFirstSentence(currentVision || "");
  const areaThemeTerms = deriveAreaThemeTerms(normalizedDiagnostic.areas);
  const systemPrompt = [
    "You generate Purpose Vision suggestions for Loom users.",
    "Use simple 5th-grade language: clear words, short sentences, no jargon.",
    "Create big-picture, long-horizon life direction in first person.",
    "Output 2 options when possible; 1 is acceptable if only one strong option is available.",
    "Each option should be 2 short complete sentences and under 38 words.",
    "Prefer action-led phrasing like: I live, I build, I am.",
    "Avoid fluffy or motivational clichés.",
    "Use fulfillment-area themes only for scope; never list raw area names.",
    "Do not mention Loom, AI, diagnostics, root cause, or next direction.",
    "If mode is rewordVision, preserve the core meaning of the current vision.",
    "If mode is newVision, generate directionally fresh alternatives.",
    "If a finance/wealth theme exists, include 'financial independence'.",
    "Return JSON only:",
    '{"visions":["option1","option2"],"error":""}',
    "If only one strong option exists, return one vision.",
    "If nothing meaningful can be generated, return:",
    '{"visions":[],"error":"insufficient_signal"}',
    "",
    mode === "rewordVision"
      ? "Mode: rewordVision."
      : "Mode: newVision.",
    currentVisionSentence
      ? `Current vision sentence to preserve exactly: "${currentVisionSentence}"`
      : "No current vision sentence available to preserve.",
    areaThemeTerms.length > 0
      ? `Fulfillment-area theme terms to incorporate in sentence 2: ${areaThemeTerms.join(", ")}`
      : "No fulfillment-area theme terms available."
  ].join("\n");

  const visionSchema = {
    name: "loom_purpose_vision_autowrite",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        visions: {
          type: "array",
          items: { type: "string" },
          minItems: 0,
          maxItems: 2
        },
        error: { type: "string" }
      },
      required: ["visions", "error"]
    }
  };

  const visionResult = await callOpenAIResponsesJSON({
    apiKey,
    model: "gpt-5.1",
    systemPrompt,
    userPayload: {
      mode,
      currentVision: currentVision || "",
      currentVisionSentence,
      areaThemeTerms,
      rootCause: hasStrongDiagnosticContext ? rootCause : "",
      nextDirection: hasStrongDiagnosticContext ? nextDirection : "",
      differentPartsOfLife: normalizedDiagnostic.areas.length
    },
    responseSchema: visionSchema,
    maxOutputTokens: 260,
    timeoutMs: 14000,
    reasoningEffort: "none",
    allowRetry: false
  });
  if (visionResult.error) {
    return json({
      error: visionResult.error,
      details: buildVisionTroubleshootingDetails("vision_model_error", {
        ...requestMeta,
        model: "gpt-5.1",
        areasCount: normalizedDiagnostic.areas.length,
        upstream: visionResult.details ? truncate(String(visionResult.details), 1400) : null
      })
    }, visionResult.status, corsHeaders(request));
  }

  if (typeof visionResult.json?.error === "string" && visionResult.json.error.trim() !== "") {
    return json({
      error: "Couldn’t generate insights",
      details: buildVisionTroubleshootingDetails("insufficient_signal", {
        ...requestMeta,
        model: "gpt-5.1",
        areasCount: normalizedDiagnostic.areas.length,
        modelError: visionResult.json.error
      })
    }, 422, corsHeaders(request));
  }

  const suggestions = Array.isArray(visionResult.json?.visions)
    ? visionResult.json.visions
      .map((x) => normalizeSuggestion(String(x ?? "")))
      .filter(Boolean)
      .slice(0, 2)
    : [];
  if (suggestions.length === 0) {
    return json({
      error: "Couldn’t generate insights",
      details: buildVisionTroubleshootingDetails("no_usable_suggestions", {
        ...requestMeta,
        model: "gpt-5.1",
        areasCount: normalizedDiagnostic.areas.length,
        returnedVisionCount: Array.isArray(visionResult.json?.visions) ? visionResult.json.visions.length : 0
      })
    }, 422, corsHeaders(request));
  }

  return json({
    message: JSON.stringify({
      suggestions,
      confidence: "high"
    }),
    suggestions,
    actions: [],
    debug: {
      model: "gpt-5.1",
      personalizationHash,
      hasStrongDiagnosticContext
    }
  }, 200, corsHeaders(request));
}

async function performOpenAIResponsesAttempt({
  apiKey,
  model,
  systemPrompt,
  userPayload,
  responseSchema,
  maxOutputTokens,
  timeoutMs,
  reasoningEffort
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
          effort: reasoningEffort
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

function normalizeSuggestion(value) {
  const text = String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "";
  const sentenceMatches = text.match(/[^.!?]+[.!?]/g);
  if (sentenceMatches && sentenceMatches.length > 0) {
    const firstTwo = sentenceMatches.slice(0, 2).map((s) => s.trim()).filter(Boolean).join(" ");
    if (firstTwo) return firstTwo;
  }
  return /[.!?]$/.test(text) ? text : `${text}.`;
}

function normalizedSuggestionKey(value) {
  return normalizeSuggestion(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
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

function buildVisionTroubleshootingDetails(code, details = {}) {
  const cleaned = {};
  for (const [key, value] of Object.entries(details || {})) {
    if (value === null || value === undefined || value === "") continue;
    cleaned[key] = value;
  }
  return {
    code: String(code || "unknown"),
    ...cleaned
  };
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

function extractDiagnosticFromChatPayload(payload) {
  const current = payload?.context?.personalization?.current ?? {};
  const personalization = payload?.context?.personalization ?? {};
  const diagnostic = payload?.context?.diagnostic ?? {};

  const pick = (...values) => {
    for (const value of values) {
      const text = String(value ?? "").trim();
      if (text) return text;
    }
    return "";
  };
  const pickArray = (...values) => {
    for (const value of values) {
      if (!Array.isArray(value)) continue;
      const cleaned = value.map((x) => String(x ?? "").trim()).filter(Boolean);
      if (cleaned.length > 0) return cleaned;
    }
    return [];
  };

  const stress = pick(
    current?.stressSource,
    personalization?.stressSource,
    diagnostic?.stress
  );
  const breaksFirst = pick(
    current?.breakPoint,
    personalization?.breakPoint,
    diagnostic?.breaksFirst
  );
  const areas = pickArray(
    current?.lifeAreasSelected,
    personalization?.lifeAreasSelected,
    diagnostic?.areas
  );
  const planningStyle = pick(
    current?.planningReality,
    personalization?.planningReality,
    diagnostic?.planningStyle
  );
  const firstChange = pick(
    current?.desiredChange,
    personalization?.desiredChange,
    diagnostic?.firstChange
  );
  return { stress, breaksFirst, areas, planningStyle, firstChange };
}

function extractLatestUserMessage(payload) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const m = messages[i];
    if (String(m?.role || "").toLowerCase() === "user") {
      return String(m?.content ?? "");
    }
  }
  return "";
}

function extractCurrentVisionFromInstruction(instruction) {
  const text = String(instruction || "");
  const match = text.match(/Current Vision:\s*([^\n\r]*)/i);
  if (!match) return "";
  const value = String(match[1] || "").trim();
  if (!value || value === "<empty>") return "";
  return value;
}

function extractVisionModeFromInstruction(instruction) {
  const text = String(instruction || "").toLowerCase();
  if (text.includes("vision mode: reword vision")) return "rewordVision";
  return "newVision";
}

function extractFirstSentence(text) {
  const normalized = String(text || "").replace(/\s+/g, " ").trim();
  if (!normalized) return "";
  const match = normalized.match(/.+?[.!?](?=\s|$)/);
  return match ? match[0].trim() : normalized;
}

function deriveAreaThemeTerms(areas) {
  const source = Array.isArray(areas) ? areas : [];
  const mapped = [];
  const add = (value) => {
    const clean = String(value || "").trim();
    if (clean) mapped.push(clean);
  };

  for (const raw of source) {
    const area = String(raw || "").toLowerCase();
    if (area.includes("wealth") || area.includes("finance") || area.includes("money")) {
      add("financial independence");
    } else if (area.includes("health") || area.includes("fitness") || area.includes("wellness")) {
      add("strong health");
    } else if (area.includes("family") || area.includes("relationship") || area.includes("friends")) {
      add("deep relationships");
    } else if (area.includes("career") || area.includes("work") || area.includes("business")) {
      add("meaningful work");
    } else if (area.includes("faith") || area.includes("spiritual")) {
      add("spiritual grounding");
    } else if (area.includes("learning") || area.includes("education") || area.includes("growth")) {
      add("lifelong growth");
    } else if (area.includes("fun") || area.includes("recreation") || area.includes("travel")) {
      add("rich experiences");
    } else if (area.includes("community") || area.includes("service") || area.includes("impact")) {
      add("positive impact");
    }
  }

  return uniqueOrdered(mapped).slice(0, 6);
}

function isPurposeVisionChatRequest(payload) {
  const intent = String(payload?.client?.intent || "").trim().toLowerCase();
  const screen = String(payload?.client?.screen || "").trim().toLowerCase();
  const latestMessage = extractLatestUserMessage(payload).toLowerCase();

  const intentMatches = intent === "autowrite_purpose" || intent === "autowrite";
  const screenMatches =
    screen === "purpose_vision" ||
    screen === "purposevision" ||
    screen === "purpose_start_vision" ||
    screen === "";
  const messageLooksLikeVision =
    latestMessage.includes("purpose vision") ||
    latestMessage.includes("current vision:") ||
    latestMessage.includes("vision mode:");

  return (intentMatches && screenMatches) || (intentMatches && messageLooksLikeVision);
}

function canonicalizeDiagnosticForVision(input) {
  const normalized = canonicalizeDiagnostic(input || {});

  return {
    stress: normalized.stress || "unknown",
    breaksFirst: normalized.breaksFirst || "unknown",
    areas: normalized.areas.slice(0, 7),
    planningStyle: normalized.planningStyle || "unknown",
    firstChange: normalized.firstChange || "unknown"
  };
}
