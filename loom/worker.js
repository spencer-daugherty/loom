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
    const isFollowUpPromptMode = detectFollowUpPromptMode(nonSystemMessages);

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

    const workerPromptVersion = isFollowUpPromptMode ? "followup-prompts-v1" : "grounding-cta-v3";

    const coreInstructions = isFollowUpPromptMode ? [
      "You generate follow-up prompt chips for the Loom iOS app.",
      "Use APP_CONTEXT_JSON and the recent chat transcript to decide whether showing follow-up prompts is high-value.",
      "Only suggest follow-up prompts when confidence is high they will help the user make a better decision or take a better next step.",
      "If confidence is not high, return no prompts.",
      "Prompts must be concise, high-value, and actionable.",
      "Avoid repeating what the assistant just said, and avoid generic prompts.",
      "Only suggest prompts tied to concepts clearly represented in APP_CONTEXT_JSON (e.g., Fulfillment Areas, Outcomes/Objectives, Action Blocks, Little Wins, Capture, Purpose, Vacation Mode, Recently Deleted).",
      "Do NOT suggest prompts about unsupported/ambiguous concepts unless explicitly represented (e.g., 'skills' if no skills dataset is present).",
      "Target 1-3 prompts, each under 80 characters (hard max 120).",
      "Return JSON ONLY in this exact shape:",
      '{"showSuggestions":true,"prompts":["string"],"confidence":"high"}',
      "or",
      '{"showSuggestions":false,"prompts":[],"confidence":"low"}'
    ].join("\n") : [
      "You are Loom, an assistant embedded inside the Loom iOS app.",
      "You MUST ground your answers in APP_CONTEXT_JSON when it is provided.",
      "Use APP_CONTEXT_METADATA and dataInventory/appGuide in APP_CONTEXT_JSON to understand what data exists before answering.",
      "If APP_CONTEXT_JSON exists, include at least 2 concrete details from it when answering planning/focus questions.",
      "Do NOT give generic productivity advice unless tied to specific APP_CONTEXT_JSON details.",
      "If APP_CONTEXT_JSON is empty/missing, explicitly say you do not have the user's app context.",
      "If APP_CONTEXT_JSON exists but the user's requested concept is not explicitly tracked (for example 'skills' when no skills dataset is present), say you have app context but that concept is not directly tracked, then offer the closest useful alternative based on tracked data.",
      "Do not hallucinate stats, outcomes, categories, scores, action blocks, or goals not present in APP_CONTEXT_JSON.",
      "Use logic: if a field value looks like a placeholder (e.g., 'Test', 'TBD', 'N/A', 'Placeholder'), do not treat it as meaningful user intent.",
      "If a placeholder appears relevant to the question, explicitly call it out as a placeholder/low-signal entry and suggest a concrete replacement.",
      "",
      "CTA / action guidance (important):",
      "- If confidence is high and the next step is practical, return 1-3 CTA actions.",
      "- If confidence is low or next step is unclear, return zero actions.",
      "- Prefer actions that directly help the user act inside Loom.",
      "- When a fulfillment area appears to need more daily execution (e.g., slipping score, weak execution patterns), consider suggesting a practical Little Win.",
      "- Target 2-3 high-quality Little Wins per Fulfillment Area (not 0, and not more than 3).",
      "- You may return multiple Little Win suggestions for the same category ONLY if confidence is high that each is distinct and high value.",
      "- Review existing Little Wins in the target category for quality and specificity. If one is weak/generic/placeholder or clearly improvable, suggest revising/replacing it.",
      "- If you return one or more actions, do NOT end the message with a question (the buttons are the CTA). End with a clear recommendation statement instead.",
      "- Before suggesting createLittleWin, check APP_CONTEXT_JSON fulfillmentCategories[].littleWins for that category and avoid repeating an existing Little Win.",
      "- If a candidate Little Win already exists, propose a different practical repeatable Little Win (if confidence remains high) or return no action.",
      "- Respect the Loom UI constraint: each Fulfillment Area can have at most 3 Little Wins.",
      "- If a category already has 3 Little Wins and improvement is still needed, suggest a replaceLittleWin action instead of createLittleWin.",
      "- For replaceLittleWin, identify the weakest/lowest-signal current Little Win (especially placeholders like 'Test') and propose a stronger replacement.",
      "",
      "Supported action types (app-compatible):",
      "1) createAction",
      '   payload: { "text": "string" }',
      "2) createOutcome",
      '   payload: { "title": "string", "category": "string" }',
      "3) createLittleWin",
      '   payload: { "categoryID": "uuid-string (preferred if available)", "categoryName": "string fallback", "activity": "practical repeatable little win text (daily/most days)" }',
      "4) replaceLittleWin",
      '   payload: { "categoryID": "uuid-string (preferred if available)", "categoryName": "string fallback", "replaceActivity": "existing little win to replace", "activity": "new practical repeatable little win text (daily/most days)" }',
      "   (Use replaceLittleWin for both true replacements and revisions of an existing Little Win.)",
      "",
      "For createLittleWin:",
      "- Recommend BOTH the category and the Little Win activity.",
      "- The activity should be small, practical, and executable (e.g., 5-20 minutes, specific trigger/time/context if possible).",
      "- The activity should be repeatable (daily or most days), not a one-off weekly task.",
      "- Avoid wording like 'this week' inside the Little Win text itself.",
      "- Keep Little Win text card-friendly: target ~50 characters when possible, and never exceed 150 characters.",
      "- Prefer categories with low weekly score or weak recent execution signals when evidence supports it.",
      "For replaceLittleWin:",
      "- Use when the category already has 3 Little Wins.",
      "- Prefer replacing placeholders/generic entries first (e.g., Test/TBD).",
      "- If no clearly weak Little Win exists, choose the least specific one and say why in the message.",
      "- Keep the replacement activity text card-friendly: target ~50 characters, max 150 characters.",
      "",
      "Return JSON ONLY in this exact shape:",
      "{",
      '  "message": "string",',
      '  "actions": [',
      '    { "id": "string", "title": "string", "type": "createLittleWin", "payload": { "categoryID": "uuid?", "categoryName": "string", "activity": "string" } }',
      '    // or: { "id": "string", "title": "string", "type": "replaceLittleWin", "payload": { "categoryID": "uuid?", "categoryName": "string", "replaceActivity": "string", "activity": "string" } }',
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
          max_tokens: isFollowUpPromptMode ? 350 : 900,
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

    if (isFollowUpPromptMode) {
      const followUp = normalizeFollowUpPromptPayload(parsedModelJSON, upstreamText);
      const out = {
        message: JSON.stringify(followUp),
        actions: [],
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
          usedContext: contextBytes > 0,
          claimedUsedContext: null,
          evidence: [],
          confidence: followUp.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
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

function detectFollowUpPromptMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Generate 0-3 high-confidence follow-up prompts for the user to ask next in Loom.");
}

function normalizeFollowUpPromptPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const promptsSource = Array.isArray(raw?.prompts)
    ? raw.prompts
    : (Array.isArray(raw?.suggestions) ? raw.suggestions : []);

  const prompts = promptsSource
    .filter((x) => typeof x === "string")
    .map((x) => x.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .map((x) => truncateAtWordBoundary(x, 120))
    .filter((x) => isSupportedFollowUpPrompt(x))
    .filter(Boolean)
    .slice(0, 3);

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw) ? confidenceRaw : (prompts.length > 0 ? "medium" : "low");

  const explicitShow = typeof raw?.showSuggestions === "boolean"
    ? raw.showSuggestions
    : (typeof raw?.show === "boolean" ? raw.show : null);

  const showSuggestions = explicitShow != null
    ? (explicitShow && prompts.length > 0 && confidence !== "low")
    : (prompts.length > 0 && confidence === "high");

  return {
    showSuggestions,
    prompts: showSuggestions ? prompts : [],
    confidence: showSuggestions ? confidence : "low",
  };
}

function isSupportedFollowUpPrompt(prompt) {
  const p = String(prompt || "").trim().toLowerCase();
  if (!p) return false;

  const unsupportedConcepts = [
    " skill ",
    "skills",
    "certification",
    "resume",
    "interview prep"
  ];
  if (unsupportedConcepts.some((term) => p.includes(term))) return false;

  return true;
}

function normalizeActions(actions, context) {
  if (!Array.isArray(actions)) return [];

  const categoryLookup = buildFulfillmentCategoryLookup(context);
  const pendingCreatesByCategoryID = new Map();
  const seenLittleWinSuggestions = new Set();

  return actions
    .filter((a) => a && typeof a === "object")
    .map((a, idx) => {
      const type = typeof a.type === "string" ? a.type.trim() : "";
      const title = typeof a.title === "string" ? a.title.trim() : "";
      const id =
        typeof a.id === "string" && a.id.trim().length > 0 ? a.id.trim() : `act-${idx + 1}`;
      const payload =
        a.payload && typeof a.payload === "object" && !Array.isArray(a.payload) ? { ...a.payload } : {};

      const normalizedType = type === "reviseLittleWin" ? "replaceLittleWin" : type;

      if (normalizedType === "createLittleWin") {
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
        const resolvedCategory = resolveCategoryRef({ categoryID: payload.categoryID, categoryName: resolvedCategoryName }, categoryLookup);
        const categoryKey = resolvedCategory.id || (resolvedCategory.name || resolvedCategoryName).toLowerCase();
        const dedupeKey = `${categoryKey}|${normalizeComparableText(activity)}`;
        if (!categoryKey || seenLittleWinSuggestions.has(dedupeKey)) {
          return null;
        }
        if (isDuplicateLittleWinSuggestion({ categoryID: resolvedCategory.id, categoryName: resolvedCategory.name, activity }, categoryLookup)) {
          return null;
        }
        const pendingCreates = pendingCreatesByCategoryID.get(categoryKey) || 0;
        const effectiveCount = resolvedCategory.count + pendingCreates;
        if (effectiveCount >= 3) {
          const replaceActivity = chooseReplaceableLittleWin(resolvedCategory, categoryLookup);
          if (!replaceActivity) return null;
          seenLittleWinSuggestions.add(dedupeKey);
          return {
            id,
            title: buildReplaceLittleWinTitle(resolvedCategory.name || resolvedCategoryName, replaceActivity, activity),
            type: "replaceLittleWin",
            payload: {
              ...(resolvedCategory.id ? { categoryID: String(resolvedCategory.id) } : {}),
              ...((resolvedCategory.name || resolvedCategoryName) ? { categoryName: resolvedCategory.name || resolvedCategoryName } : {}),
              replaceActivity,
              activity,
            },
          };
        }
        pendingCreatesByCategoryID.set(categoryKey, pendingCreates + 1);
        seenLittleWinSuggestions.add(dedupeKey);

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

      if (normalizedType === "replaceLittleWin") {
        if (typeof payload.activity !== "string" || !payload.activity.trim()) {
          payload.activity = title.replace(/^Replace Little Win:\s*/i, "").trim() || "";
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
        const resolvedCategory = resolveCategoryRef({ categoryID: payload.categoryID, categoryName: resolvedCategoryName }, categoryLookup);
        let replaceActivity = typeof payload.replaceActivity === "string" ? payload.replaceActivity.trim() : "";
        if (!replaceActivity) {
          replaceActivity = chooseReplaceableLittleWin(resolvedCategory, categoryLookup) || "";
        }
        if (!replaceActivity) return null;

        const activity = typeof payload.activity === "string" ? payload.activity.trim() : "";
        const categoryKey = resolvedCategory.id || (resolvedCategory.name || resolvedCategoryName).toLowerCase();
        const dedupeKey = `${categoryKey}|${normalizeComparableText(activity)}`;
        if (!categoryKey || seenLittleWinSuggestions.has(dedupeKey)) return null;
        if (normalizeComparableText(replaceActivity) === normalizeComparableText(activity)) return null;
        if (isDuplicateLittleWinSuggestion({ categoryID: resolvedCategory.id, categoryName: resolvedCategory.name || resolvedCategoryName, activity }, categoryLookup)) {
          return null;
        }
        seenLittleWinSuggestions.add(dedupeKey);

        return {
          id,
          title: title || buildReplaceLittleWinTitle(resolvedCategory.name || resolvedCategoryName, replaceActivity, activity),
          type: "replaceLittleWin",
          payload: {
            ...(resolvedCategory.id ? { categoryID: String(resolvedCategory.id) } : {}),
            ...((resolvedCategory.name || resolvedCategoryName) ? { categoryName: resolvedCategory.name || resolvedCategoryName } : {}),
            replaceActivity,
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

function buildReplaceLittleWinTitle(categoryName, replaceActivity, activity) {
  const base = categoryName ? `Replace Little Win in ${categoryName}` : "Replace Little Win";
  if (activity) return `${base}: ${activity}`;
  if (replaceActivity) return `${base} (${replaceActivity})`;
  return base;
}

function buildFulfillmentCategoryLookup(context) {
  const byID = new Map();
  const byNameLower = new Map();
  const littleWinsByCategoryID = new Map();
  const littleWinsByCategoryNameLower = new Map();

  try {
    const cats = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
    for (const c of cats) {
      const id = typeof c?.id === "string" ? c.id.trim() : "";
      const name = typeof c?.name === "string" ? c.name.trim() : "";
      const littleWins = Array.isArray(c?.littleWins)
        ? c.littleWins.filter((x) => typeof x === "string").map((x) => x.trim()).filter(Boolean)
        : [];
      if (id && name) {
        byID.set(id, name);
        byNameLower.set(name.toLowerCase(), { id, name });
        littleWinsByCategoryID.set(id, littleWins);
        littleWinsByCategoryNameLower.set(name.toLowerCase(), littleWins);
      }
    }
  } catch {
    // ignore
  }

  return { byID, byNameLower, littleWinsByCategoryID, littleWinsByCategoryNameLower };
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

function isDuplicateLittleWinSuggestion(candidate, categoryLookup) {
  const activity = normalizeComparableText(candidate?.activity);
  if (!activity) return false;

  const categoryID = typeof candidate?.categoryID === "string" ? candidate.categoryID.trim() : "";
  const categoryName = typeof candidate?.categoryName === "string" ? candidate.categoryName.trim() : "";

  let existing = [];
  if (categoryID && categoryLookup?.littleWinsByCategoryID?.has(categoryID)) {
    existing = categoryLookup.littleWinsByCategoryID.get(categoryID) || [];
  } else if (categoryName && categoryLookup?.littleWinsByCategoryNameLower?.has(categoryName.toLowerCase())) {
    existing = categoryLookup.littleWinsByCategoryNameLower.get(categoryName.toLowerCase()) || [];
  }

  if (!Array.isArray(existing) || existing.length === 0) return false;
  return existing.some((item) => normalizeComparableText(item) === activity);
}

function resolveCategoryRef(candidate, categoryLookup) {
  const categoryID = typeof candidate?.categoryID === "string" ? candidate.categoryID.trim() : "";
  const categoryName = typeof candidate?.categoryName === "string" ? candidate.categoryName.trim() : "";

  if (categoryID && categoryLookup?.byID?.has(categoryID)) {
    const name = categoryLookup.byID.get(categoryID) || categoryName || "";
    const littleWins = categoryLookup.littleWinsByCategoryID?.get(categoryID) || [];
    return { id: categoryID, name, littleWins, count: littleWins.length };
  }
  if (categoryName && categoryLookup?.byNameLower?.has(categoryName.toLowerCase())) {
    const match = categoryLookup.byNameLower.get(categoryName.toLowerCase());
    const littleWins = categoryLookup.littleWinsByCategoryID?.get(match.id) || categoryLookup.littleWinsByCategoryNameLower?.get(categoryName.toLowerCase()) || [];
    return { id: match.id, name: match.name, littleWins, count: littleWins.length };
  }
  return { id: categoryID || "", name: categoryName || "", littleWins: [], count: 0 };
}

function chooseReplaceableLittleWin(resolvedCategory, categoryLookup) {
  const littleWins = Array.isArray(resolvedCategory?.littleWins) ? resolvedCategory.littleWins : [];
  if (littleWins.length === 0) return "";

  const placeholder = littleWins.find((x) => looksLikePlaceholderValue(x));
  if (placeholder) return placeholder;

  const genericTerms = ["exercise", "workout", "health", "call", "family", "friends", "relationship", "read", "journal"];
  const ranked = littleWins
    .map((text) => {
      const normalized = normalizeComparableText(text);
      const tokens = normalized.split(" ").filter(Boolean);
      const genericScore = genericTerms.some((term) => normalized === term || normalized.includes(`${term} `) || normalized.includes(` ${term}`)) ? 1 : 0;
      const specificityScore = tokens.length;
      return { text, genericScore, specificityScore, rawLen: String(text).trim().length };
    })
    .sort((a, b) => {
      if (a.genericScore !== b.genericScore) return b.genericScore - a.genericScore;
      if (a.specificityScore !== b.specificityScore) return a.specificityScore - b.specificityScore;
      return a.rawLen - b.rawLen;
    });

  return ranked[0]?.text || "";
}

function normalizeComparableText(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\b(this week|weekly)\b/g, " ")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
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
  s = truncateAtWordBoundary(s, 150);

  if (!s) return "";
  return s;
}

function truncateAtWordBoundary(value, maxLen) {
  const s = String(value || "").trim();
  if (!s || s.length <= maxLen) return s;
  const rough = s.slice(0, maxLen);
  const lastSpace = rough.lastIndexOf(" ");
  if (lastSpace > 12) return rough.slice(0, lastSpace).trim();
  return rough.trim();
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
