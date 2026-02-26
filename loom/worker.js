export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(request),
      });
    }

    // Health check
    if (url.pathname === "/health") {
      return json({ ok: true }, 200, corsHeaders(request));
    }

    // Route: only /chat
    if (url.pathname !== "/chat") {
      return new Response("Not found", {
        status: 404,
        headers: corsHeaders(request),
      });
    }

    // Method: only POST
    if (request.method !== "POST") {
      return new Response("Only POST allowed", {
        status: 405,
        headers: corsHeaders(request),
      });
    }

    // Secret
    const apiKey = env.OPENAI_API_KEY;
    if (!apiKey || typeof apiKey !== "string" || apiKey.trim().length < 10) {
      return json(
        {
          error: "Missing/invalid OPENAI_API_KEY in Worker secrets",
          gotType: typeof apiKey,
        },
        500,
        corsHeaders(request)
      );
    }

    // Body
    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400, corsHeaders(request));
    }

    // Expected app payload:
    // { messages: [{role, content}], context: {...}, client: {...} }
    const messages = Array.isArray(body?.messages) ? body.messages : null;
    const context = body?.context ?? null;
    const client = body?.client ?? null;

    if (!messages || messages.length === 0) {
      return json({ error: "Missing messages[]" }, 400, corsHeaders(request));
    }

    // Normalize/sanitize messages and remove app-level system messages
    const normalizedMessages = messages
      .filter((m) => m && typeof m === "object")
      .map((m) => ({
        role: normalizeRole(m.role),
        content: flattenContent(m.content),
      }))
      .filter((m) => m.content.length > 0);

    const nonSystemMessages = normalizedMessages.filter((m) => m.role !== "system");

    if (nonSystemMessages.length === 0) {
      return json(
        { error: "No usable non-system messages provided" },
        400,
        corsHeaders(request)
      );
    }

    // Make context measurable/verifiable
    const contextInfo = safeJSONStringifyWithMeta(context, 60_000);
    const contextString = contextInfo.text;
    const contextBytes = contextString ? byteLength(contextString) : 0;
    const contextHash = contextString ? await sha256Hex(contextString) : null;
    const contextKeys =
      context && typeof context === "object" && !Array.isArray(context)
        ? Object.keys(context).slice(0, 40)
        : [];
    const placeholderSignals = collectPlaceholderSignals(context);

    const workerPromptVersion = "grounding-cta-v3";

    const coreInstructions = [
      "You are Loom, an assistant embedded inside the Loom iOS app.",
      "You MUST ground your answers in APP_CONTEXT_JSON when it is provided.",
      "Use APP_CONTEXT_METADATA and dataInventory/appGuide in APP_CONTEXT_JSON to understand what data exists before answering.",
      "If APP_CONTEXT_JSON exists, include at least 2 concrete details from it when answering planning/focus questions.",
      "Do NOT give generic productivity advice unless tied to specific APP_CONTEXT_JSON details.",
      "If APP_CONTEXT_JSON is empty/missing, explicitly say you do not have the user's app context.",
      "Do not hallucinate stats, outcomes, categories, scores, action blocks, or goals not present in APP_CONTEXT_JSON.",
      "Use logic: if a field value looks like a placeholder (e.g., 'Test', 'TBD', 'N/A', 'Placeholder'), do not treat it as meaningful user intent.",
      "If a placeholder appears relevant to the question, explicitly call it out as a placeholder/low-signal entry and suggest a concrete replacement.",
      "",
      "CTA / action guidance (important):",
      "- If confidence is high and the next step is practical, return 1-3 CTA actions.",
      "- If confidence is low or next step is unclear, return zero actions.",
      "- Prefer actions that directly help the user act inside Loom.",
      "- When a fulfillment area appears to need more daily execution (e.g., slipping score, weak execution patterns), consider suggesting a practical Little Win.",
      "- If you return one or more actions, do NOT end the message with a question (the buttons are the CTA). End with a clear recommendation statement instead.",
      "",
      "Supported action types (app-compatible):",
      "1) createAction",
      '   payload: { "text": "string" }',
      "2) createOutcome",
      '   payload: { "title": "string", "category": "string" }',
      "3) createLittleWin",
      '   payload: { "categoryID": "uuid-string (preferred if available)", "categoryName": "string fallback", "activity": "practical repeatable little win text (daily/most days)" }',
      "",
      "For createLittleWin:",
      "- Recommend BOTH the category and the Little Win activity.",
      "- The activity should be small, practical, and executable (e.g., 5-20 minutes, specific trigger/time/context if possible).",
      "- The activity should be repeatable (daily or most days), not a one-off weekly task.",
      "- Avoid wording like 'this week' inside the Little Win text itself.",
      "- Prefer categories with low weekly score or weak recent execution signals when evidence supports it.",
      "",
      "Return JSON ONLY in this exact shape:",
      "{",
      '  "message": "string",',
      '  "actions": [',
      '    { "id": "string", "title": "string", "type": "createLittleWin", "payload": { "categoryID": "uuid?", "categoryName": "string", "activity": "string" } }',
      "  ],",
      '  "debug": {',
      '    "usedContext": true,',
      '    "contextKeys": ["..."],',
      '    "evidence": ["path.or.field.used", "..."],',
      '    "confidence": "high|medium|low"',
      "  }",
      "}",
      "",
      "Rules for debug.evidence:",
      "- Include paths/names from APP_CONTEXT_JSON actually used in reasoning.",
      '- Reference dataInventory section IDs when helpful (e.g., "dataInventory:fulfillment_current").',
      "- Use an empty array if no context was used.",
      "",
      "Keep the answer concise, specific, and useful.",
    ].join("\n");

    const groundedMessages = [
      { role: "system", content: coreInstructions },
      {
        role: "system",
        content: [
          "APP_CONTEXT_METADATA:",
          JSON.stringify(
            {
              hasContext: contextBytes > 0,
              contextBytes,
              contextKeys,
              contextTruncated: contextInfo.truncated,
              placeholderSignals,
              workerPromptVersion,
              client,
            },
            null,
            2
          ),
        ].join("\n"),
      },
      {
        role: "system",
        content: `APP_CONTEXT_JSON:\n${contextBytes > 0 ? contextString : "{}"}`,
      },
      ...nonSystemMessages,
    ];

    const model = env.OPENAI_MODEL || "gpt-4o-mini";
    const temperature = 0.2;

    let upstreamText = "";
    let upstreamContentType = null;
    let upstreamStatus = null;

    try {
      const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: groundedMessages,
          temperature,
          max_tokens: 900,
          response_format: { type: "json_object" },
        }),
      });

      upstreamStatus = upstream.status;
      upstreamContentType = upstream.headers.get("Content-Type");
      upstreamText = await upstream.text();

      if (!upstream.ok) {
        return json(
          {
            error: "OpenAI error",
            status: upstreamStatus,
            body: truncate(upstreamText, 2000),
            debug: buildWorkerDebug({
              model,
              contextBytes,
              contextHash,
              contextKeys,
              contextInfo,
              workerPromptVersion,
              messages,
              nonSystemMessages,
              upstreamStatus,
              upstreamContentType,
              parseMode: "upstream_error",
            }),
          },
          502,
          corsHeaders(request)
        );
      }
    } catch (e) {
      return json(
        {
          error: "Upstream fetch failed",
          details: String(e),
          debug: buildWorkerDebug({
            model,
            contextBytes,
            contextHash,
            contextKeys,
            contextInfo,
            workerPromptVersion,
            messages,
            nonSystemMessages,
            upstreamStatus,
            upstreamContentType,
            parseMode: "upstream_fetch_failed",
          }),
        },
        502,
        corsHeaders(request)
      );
    }

    // Parse Chat Completions content safely
    let parsedModelJSON = null;
    let parseMode = "unknown";

    try {
      const raw = JSON.parse(upstreamText);
      const content = raw?.choices?.[0]?.message?.content;

      let contentString = "";
      if (typeof content === "string") {
        contentString = content;
      } else if (Array.isArray(content)) {
        contentString = content
          .map((part) => (typeof part?.text === "string" ? part.text : ""))
          .join("");
      }

      parsedModelJSON = contentString ? JSON.parse(contentString) : null;
      parseMode = "chat_completions_json";
    } catch {
      parsedModelJSON = null;
      parseMode = "parse_failed";
    }

    const normalized = normalizeAssistantJSON(parsedModelJSON, upstreamText);

    const modelDebug =
      normalized.debug && typeof normalized.debug === "object" ? normalized.debug : {};
    const modelEvidence = Array.isArray(modelDebug.evidence)
      ? modelDebug.evidence.filter((x) => typeof x === "string").slice(0, 20)
      : [];

    const claimedUsedContext =
      typeof modelDebug.usedContext === "boolean" ? modelDebug.usedContext : null;

    const confidence = typeof modelDebug.confidence === "string" ? modelDebug.confidence : null;

    const finalUsedContext =
      typeof claimedUsedContext === "boolean"
        ? claimedUsedContext
        : contextBytes > 0 && modelEvidence.length > 0;

    // Validate/normalize actions for app compatibility
    const actions = normalizeActions(normalized.actions, context);

    const out = {
      message: finalizeAssistantMessage(normalized.message, actions),
      actions,
      debug: {
        ...buildWorkerDebug({
          model,
          contextBytes,
          contextHash,
          contextKeys,
          contextInfo,
          workerPromptVersion,
          messages,
          nonSystemMessages,
          upstreamStatus,
          upstreamContentType,
          parseMode,
        }),
        usedContext: finalUsedContext,
        claimedUsedContext,
        evidence: modelEvidence,
        confidence,
      },
    };

    return json(out, 200, corsHeaders(request));
  },
};

// ---------------- helpers ----------------

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

function json(obj, status = 200, headers = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

function normalizeRole(role) {
  const r = String(role || "").toLowerCase();
  if (r === "system" || r === "user" || r === "assistant") return r;
  return "user";
}

function flattenContent(content) {
  if (typeof content === "string") return content.trim();

  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        if (part && typeof part.text === "string") return part.text;
        if (part && typeof part.value === "string") return part.value;
        return "";
      })
      .join("")
      .trim();
  }

  if (content == null) return "";

  try {
    return String(content).trim();
  } catch {
    return "";
  }
}

function normalizeAssistantJSON(parsed, fallbackText) {
  if (parsed && typeof parsed === "object" && typeof parsed.message === "string") {
    return {
      message: parsed.message,
      actions: Array.isArray(parsed.actions) ? parsed.actions : [],
      debug: parsed.debug && typeof parsed.debug === "object" ? parsed.debug : null,
    };
  }

  if (parsed && typeof parsed === "object" && typeof parsed.reply === "string") {
    return {
      message: parsed.reply,
      actions: Array.isArray(parsed.actions) ? parsed.actions : [],
      debug: parsed.debug && typeof parsed.debug === "object" ? parsed.debug : null,
    };
  }

  return {
    message: truncate(fallbackText, 1200),
    actions: [],
    debug: { usedContext: false, evidence: [], confidence: "low" },
  };
}

function normalizeActions(actions, context) {
  if (!Array.isArray(actions)) return [];

  const categoryLookup = buildFulfillmentCategoryLookup(context);

  return actions
    .filter((a) => a && typeof a === "object")
    .map((a, idx) => {
      const type = typeof a.type === "string" ? a.type.trim() : "";
      const title = typeof a.title === "string" ? a.title.trim() : "";
      const id =
        typeof a.id === "string" && a.id.trim().length > 0 ? a.id.trim() : `act-${idx + 1}`;
      const payload =
        a.payload && typeof a.payload === "object" && !Array.isArray(a.payload) ? { ...a.payload } : {};

      if (type === "createLittleWin") {
        if (typeof payload.activity !== "string" || !payload.activity.trim()) {
          payload.activity =
            title.replace(/^Add Little Win:\s*/i, "").trim() || "Small daily practice";
        }
        payload.activity = normalizeLittleWinActivityText(payload.activity);
        if (!payload.activity || looksLikePlaceholderValue(payload.activity)) {
          return null;
        }

        const categoryID = typeof payload.categoryID === "string" ? payload.categoryID.trim() : "";
        const categoryName =
          typeof payload.categoryName === "string" ? payload.categoryName.trim() : "";

        if (categoryID && categoryLookup.byID.has(categoryID)) {
          payload.categoryName = payload.categoryName || categoryLookup.byID.get(categoryID);
        } else if (categoryName) {
          const matched = categoryLookup.byNameLower.get(categoryName.toLowerCase());
          if (matched) {
            payload.categoryID = payload.categoryID || matched.id;
            payload.categoryName = payload.categoryName || matched.name;
          }
        }

        const resolvedCategoryName =
          typeof payload.categoryName === "string" ? payload.categoryName.trim() : "";
        const activity = typeof payload.activity === "string" ? payload.activity.trim() : "";

        return {
          id,
          title: title || buildLittleWinTitle(resolvedCategoryName, activity),
          type: "createLittleWin",
          payload: {
            ...(payload.categoryID ? { categoryID: String(payload.categoryID) } : {}),
            ...(resolvedCategoryName ? { categoryName: resolvedCategoryName } : {}),
            activity,
          },
        };
      }

      if (type === "createAction") {
        const text =
          typeof payload.text === "string" && payload.text.trim() ? payload.text.trim() : title;
        return { id, title: title || text || "Create Action", type: "createAction", payload: { text } };
      }

      if (type === "createOutcome") {
        const outcomeTitle =
          typeof payload.title === "string" && payload.title.trim() ? payload.title.trim() : title;
        const category =
          typeof payload.category === "string" && payload.category.trim()
            ? payload.category.trim()
            : "Mind & Meaning";
        return {
          id,
          title: title || outcomeTitle || "Create Outcome",
          type: "createOutcome",
          payload: { title: outcomeTitle, category },
        };
      }

      return null;
    })
    .filter(Boolean)
    .slice(0, 3);
}

function buildLittleWinTitle(categoryName, activity) {
  if (categoryName && activity) return `Add Little Win to ${categoryName}: ${activity}`;
  if (activity) return `Add Little Win: ${activity}`;
  if (categoryName) return `Add Little Win to ${categoryName}`;
  return "Add Little Win";
}

function buildFulfillmentCategoryLookup(context) {
  const byID = new Map();
  const byNameLower = new Map();

  try {
    const cats = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
    for (const c of cats) {
      const id = typeof c?.id === "string" ? c.id.trim() : "";
      const name = typeof c?.name === "string" ? c.name.trim() : "";
      if (id && name) {
        byID.set(id, name);
        byNameLower.set(name.toLowerCase(), { id, name });
      }
    }
  } catch {
    // ignore
  }

  return { byID, byNameLower };
}

function buildWorkerDebug({
  model,
  contextBytes,
  contextHash,
  contextKeys,
  contextInfo,
  workerPromptVersion,
  messages,
  nonSystemMessages,
  upstreamStatus,
  upstreamContentType,
  parseMode,
}) {
  return {
    model,
    usedContext: contextBytes > 0,
    contextBytes,
    contextHash,
    contextKeys,
    contextTruncated: !!contextInfo?.truncated,
    contextChars: Number.isFinite(contextInfo?.originalChars) ? contextInfo.originalChars : null,
    workerPromptVersion,
    parseMode,
    receivedMessageCount: Array.isArray(messages) ? messages.length : 0,
    forwardedMessageCount: Array.isArray(nonSystemMessages) ? nonSystemMessages.length : 0,
    strippedSystemMessages:
      Array.isArray(messages) && Array.isArray(nonSystemMessages)
        ? messages.length - nonSystemMessages.length
        : 0,
    upstreamStatus: upstreamStatus ?? null,
    upstreamContentType: upstreamContentType ?? null,
  };
}

function finalizeAssistantMessage(message, actions) {
  let text = typeof message === "string" ? message.trim() : "";
  if (!text) return "";

  if (Array.isArray(actions) && actions.length > 0) {
    text = stripTrailingQuestionParagraph(text);
  }

  return text.trim();
}

function stripTrailingQuestionParagraph(text) {
  const parts = text
    .split(/\n{2,}/)
    .map((p) => p.trim())
    .filter(Boolean);

  if (parts.length === 0) return text;
  const last = parts[parts.length - 1];
  if (!/\?\s*$/.test(last)) return text;

  const lower = last.toLowerCase();
  const likelyCtaQuestion =
    lower.includes("would you like") ||
    lower.includes("should i") ||
    lower.includes("do you want me to") ||
    lower.includes("want me to create");

  if (likelyCtaQuestion) {
    parts.pop();
    return parts.join("\n\n");
  }

  return text;
}

function normalizeLittleWinActivityText(value) {
  let s = typeof value === "string" ? value.trim() : "";
  if (!s) return "";

  s = s
    .replace(/\bonce this week\b/gi, "on most days")
    .replace(/\bthis week\b/gi, "")
    .replace(/\bweekly\b/gi, "most days")
    .replace(/\s{2,}/g, " ")
    .trim();

  s = s.replace(/^[,.;:\-\s]+|[,.;:\-\s]+$/g, "").trim();

  if (!s) return "";
  return s;
}

function looksLikePlaceholderValue(value) {
  const s = String(value || "").trim().toLowerCase();
  if (!s) return true;

  const exact = new Set([
    "test",
    "testing",
    "todo",
    "tbd",
    "n/a",
    "na",
    "none",
    "placeholder",
    "sample",
    "example",
    "asdf",
    "qwerty",
    "-"
  ]);
  if (exact.has(s)) return true;
  if (/^test\d*$/.test(s)) return true;
  if (/^placeholder\d*$/.test(s)) return true;
  return false;
}

function collectPlaceholderSignals(context) {
  const matches = [];
  try {
    const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
    for (const c of categories.slice(0, 10)) {
      const categoryName = typeof c?.name === "string" ? c.name.trim() : "Unknown";
      const littleWins = Array.isArray(c?.littleWins) ? c.littleWins : [];
      for (const lw of littleWins.slice(0, 8)) {
        if (looksLikePlaceholderValue(lw)) {
          matches.push(`fulfillmentCategories.${categoryName}.littleWins:${String(lw)}`);
        }
      }
    }
  } catch {
    return [];
  }
  return matches.slice(0, 12);
}

function safeJSONStringifyWithMeta(value, maxChars) {
  try {
    const raw = JSON.stringify(value ?? {});
    if (raw.length > maxChars) {
      return {
        text: raw.slice(0, maxChars) + `…(truncated ${raw.length - maxChars} chars)`,
        truncated: true,
        originalChars: raw.length,
      };
    }
    return { text: raw, truncated: false, originalChars: raw.length };
  } catch {
    return { text: "{}", truncated: false, originalChars: 2 };
  }
}

function truncate(s, n) {
  if (!s || typeof s !== "string") return "";
  return s.length <= n ? s : s.slice(0, n) + "…";
}

function byteLength(str) {
  return new TextEncoder().encode(str).length;
}

async function sha256Hex(str) {
  const data = new TextEncoder().encode(str);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const arr = Array.from(new Uint8Array(digest));
  return arr.map((b) => b.toString(16).padStart(2, "0")).join("");
}
