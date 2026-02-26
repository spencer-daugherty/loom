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
    const isAutoGroupMode = detectAutoGroupMode(nonSystemMessages);
    const isReflectReadableInsightsMode = detectReflectReadableInsightsMode(nonSystemMessages);
    const isFulfillmentReadableInsightMode = detectFulfillmentReadableInsightMode(nonSystemMessages);
    const isPurposeReadableInsightMode = detectPurposeReadableInsightMode(nonSystemMessages);

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

    const workerPromptVersion = isAutoGroupMode
      ? "autogroup-v1"
      : (isFollowUpPromptMode
        ? "followup-prompts-v1"
        : (isReflectReadableInsightsMode
          ? "reflect-readable-insights-v1"
          : (isFulfillmentReadableInsightMode
            ? "fulfillment-readable-insights-v1"
            : (isPurposeReadableInsightMode ? "purpose-readable-insights-v1" : "grounding-cta-v3"))));

    const coreInstructions = isAutoGroupMode ? [
      "You generate AutoGroup plans for Loom Plan Step 3 (Group).",
      "Use the provided Capture actions and APP_CONTEXT_JSON to group only the high-confidence items.",
      "Use Fulfillment Areas as inspiration when relevant, but group by topic/relatedness.",
      "Obvious practical topic clusters are valid even if they do not map perfectly to a Fulfillment Area (e.g., home/house chores, fitness/health, work/business, errands, food/cooking).",
      "It is allowed to leave ambiguous or low-confidence actions ungrouped.",
      "Do not force weak items into a group just to maximize coverage.",
      "If there are at least 2 clear topical groups with 3+ actions each, treat that as high confidence even when some actions remain ungrouped.",
      "Hard constraints:",
      "- Return JSON ONLY",
      "- confidence must be high to return groups; otherwise return confidence=low and groups=[]",
      "- Minimum 2 groups",
      "- Each group must contain at least 3 actionIDs",
      "- Maximum 8 groups",
      "- Use only actionIDs from the prompt",
      "- Do not duplicate actionIDs across groups",
      '- If a group aligns to a Fulfillment Area, set fulfillmentArea to one of the provided names exactly; otherwise use ""',
      "Return JSON exactly in this shape:",
      '{"confidence":"high","reason":"short string","groups":[{"name":"string","fulfillmentArea":"string","actionIDs":["uuid"]}]}',
      "or",
      '{"confidence":"low","reason":"short string","groups":[]}'
    ].join("\n") : isFollowUpPromptMode ? [
      "You generate follow-up prompt chips for the Loom iOS app.",
      "Use APP_CONTEXT_JSON and the recent chat transcript to decide whether showing follow-up prompts is high-value.",
      "Only suggest follow-up prompts when confidence is high they will help the user make a better decision or take a better next step.",
      "If confidence is not high, return no prompts.",
      "Prompts must be concise, high-value, and actionable.",
      "Avoid repeating what the assistant just said, and avoid generic prompts.",
      "Prefer prompts that help the user improve or edit data inside Loom (not generic external lifestyle advice).",
      "Prefer prompts that could plausibly lead to a Loom CTA action (add/replace/revise/clarify/connect/plan).",
      "Use APP_CONTEXT_JSON dataInventory and appGuide to understand the app's editable areas before proposing prompts.",
      "Only suggest prompts tied to concepts clearly represented in APP_CONTEXT_JSON (e.g., Fulfillment Areas, Outcomes/Objectives, Action Blocks, Little Wins, Capture, Purpose, Vacation Mode, Recently Deleted).",
      "Do NOT suggest prompts about unsupported/ambiguous concepts unless explicitly represented (e.g., 'skills' if no skills dataset is present).",
      "Do NOT suggest external domain-specific advice prompts (e.g., meal prep plans, supplement stacks, recipes) unless the app context explicitly tracks that concept as structured data.",
      "Target 1-3 prompts, each under 80 characters (hard max 120).",
      "Return JSON ONLY in this exact shape:",
      '{"showSuggestions":true,"prompts":["string"],"confidence":"high"}',
      "or",
      '{"showSuggestions":false,"prompts":[],"confidence":"low"}'
    ].join("\n") : isReflectReadableInsightsMode ? [
      "You generate a readable insights summary for a completed Loom Action Blocks session.",
      "Use APP_CONTEXT_JSON and the provided session details to write grounded insights about what happened and what it suggests.",
      "This is analysis-only mode. Do NOT return CTAs or suggested actions.",
      "Do NOT end with a question.",
      "If APP_CONTEXT_JSON exists, use concrete details from it and from the provided session details.",
      "Treat low-signal placeholders (e.g., Test, TBD, N/A, Placeholder) as placeholders; call them out instead of treating them as meaningful.",
      "Focus on patterns supported by evidence: completed vs carried actions, leverage, fulfillment areas, outcomes, places/people/tools, action characteristics.",
      "Write plain-language readable insights, concise and specific.",
      "Return exactly ONE sentence under 200 characters.",
      "The sentence must be a real insight (pattern/implication/mismatch), not a recap of obvious totals already shown in the UI.",
      "Avoid filler phrases like 'During this session' or 'a total of'.",
      "Prefer naming the most important fulfillment area/outcome/pattern if supported by evidence.",
      "Do not invent values that are not present.",
      "Return JSON ONLY in this exact shape:",
      '{"message":"string","actions":[],"debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}'
    ].join("\n") : isFulfillmentReadableInsightMode ? [
      "You generate one readable insight sentence for a Loom Fulfillment Area.",
      "Use APP_CONTEXT_JSON and the provided fulfillment insight payload.",
      "This is readable-insight mode. Do NOT return action buttons or suggested actions array items.",
      "Do NOT end with a question.",
      "Return exactly TWO short lines under 220 characters total.",
      "Line 1 must be a real insight sentence (pattern, implication, imbalance, trend, or mismatch), not a recap of obvious displayed stats.",
      "Line 2 must be a very short practical call to action the user can do in Loom to improve.",
      "Separate the lines with a newline.",
      "Line 2 should NOT start with 'In Loom,'.",
      "Use practical action verbs in line 2 (prefer: Complete, Revise, Connect, Clarify, Add, Replace, Shorten, Split).",
      "If both Little Wins and Action Blocks are weak, line 2 should address both together (for example: 'Complete more Little Wins and Action Blocks.').",
      "If carryover is high, line 2 should give practical load-management advice (for example: 'Balance only adding essential actions and completing more actions.').",
      "Avoid filler phrases like 'During this week' or 'a total of'.",
      "Use plain language and be specific.",
      "If referencing an insight metric, use the exact label and include the displayed value in parentheses.",
      "Use (X%) for percentage-based metrics and score components.",
      "If referencing Momentum or Consistency, use the displayed descriptor in parentheses (e.g., Momentum (Improving), Consistency (Mixed)).",
      "If referencing area rank, format it as area rank (X of Y), not just area rank (X).",
      "Use these labels verbatim when referenced: Momentum, Consistency, Structure, Outcomes, Action Blocks, Little Wins, Engagement, Strategic Behavior, Carryover penalty.",
      "Do not append duplicate raw score values after a metric reference (for example, avoid 'Action Blocks (50%) score (0.5)').",
      "If Outcomes is high, do not describe an 'execution gap in achieving Outcomes'; frame it as a sustainability/support mismatch instead.",
      "Make the insight and CTA logically consistent with each other (the CTA should address the actual weakness named in line 1).",
      "Use 'Action Blocks' (plural) and 'Engagement' (correct spelling).",
      "If placeholders/low-signal values appear, treat them as placeholders and say so only if relevant.",
      "Prefer the strongest supported interpretation from the payload: trend, carryover drag, execution/outcome mismatch, structure gap, little wins imbalance, strategic behavior, peer-relative position.",
      "Do not mention the fulfillment area name directly (the UI already shows it).",
      "Do not invent values.",
      "Return JSON ONLY in this exact shape:",
      '{"message":"string","actions":[],"debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}'
    ].join("\n") : isPurposeReadableInsightMode ? [
      "You generate one readable insight sentence for a Loom Purpose passion.",
      "Use APP_CONTEXT_JSON and the provided purpose passion insight payload.",
      "This is readable-insight mode. Do NOT return action buttons or suggested actions array items.",
      "Do NOT end with a question.",
      "Return exactly TWO short lines under 220 characters total.",
      "Line 1 must be a real insight sentence (pattern, implication, imbalance, trend, or mismatch), not a recap of obvious displayed stats.",
      "Line 2 must be a very short practical call to action the user can do in Loom to improve.",
      "Separate the lines with a newline.",
      "Line 2 should NOT start with 'In Loom,'.",
      "Use practical action verbs in line 2 (prefer: Complete, Revise, Connect, Clarify, Add, Replace, Shorten, Split).",
      "If both Little Wins and Action Blocks are weak, line 2 should address both together (for example: 'Complete more Little Wins and Action Blocks.').",
      "If carryover is high, line 2 should give practical load-management advice (for example: 'Balance only adding essential actions and completing more actions.').",
      "Avoid filler phrases like 'During this month' or 'a total of'.",
      "Use plain language and be specific.",
      "Do not mention the passion name directly (the UI already shows it).",
      "If referencing an insight metric, use the exact label and include the displayed value in parentheses.",
      "Use (X%) for percentage-based metrics and score components.",
      "If referencing Momentum or Consistency, use the displayed descriptor in parentheses (e.g., Momentum (Improving), Consistency (Stable)).",
      "Use these labels verbatim when referenced: Momentum, Consistency, Structure, Outcomes, Action Blocks, Little Wins, Evidence, Carryover penalty.",
      "Make the insight and CTA logically consistent with each other (the CTA should address the actual weakness named in line 1).",
      "Use 'Action Blocks' (plural).",
      "Use awareness of all relevant passion insight data in the payload (scores, momentum, consistency, support signals, evidence, carryover, peers, movers, recent trend).",
      "Choose the strongest supported interpretation across different situations (trend shift, volatility, support mismatch, carryover drag, strong stable support, peer-relative context).",
      "Do not invent values.",
      "Return JSON ONLY in this exact shape:",
      '{"message":"string","actions":[],"debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}'
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
      "- You may also suggest high-confidence improvements to Fulfillment Missions, Fulfillment Identities, Purpose Vision, and Passions when the context strongly supports a better version.",
      "- Only suggest adding a new Fulfillment Area when many actions/outcomes clearly do not fit current active areas and confidence is high.",
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
      "5) replaceFulfillmentMission",
      '   payload: { "categoryID": "uuid-string?", "categoryName": "string", "mission": "string" }',
      "6) addFulfillmentIdentity / replaceFulfillmentIdentity",
      '   payload: { "categoryID": "uuid-string?", "categoryName": "string", "identity": "string", "replaceIdentity": "string?" }',
      "7) replacePurposeVision",
      '   payload: { "vision": "string" }',
      "8) addPassion",
      '   payload: { "emotion": "love|thrill|vows|hate", "passion": "string", "categoryID": "uuid-string?", "categoryName": "string?" }',
      "9) launchAddFulfillmentAreaPrefill",
      '   payload: { "categoryName": "string", "mission": "string?", "identities": "A|B", "littleWins": "A|B", "connectedPassions": "Love: ...|Thrill: ..." }',
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
          max_tokens: isAutoGroupMode ? 700 : (isFollowUpPromptMode ? 350 : (isReflectReadableInsightsMode ? 650 : (isFulfillmentReadableInsightMode ? 450 : (isPurposeReadableInsightMode ? 450 : 900)))),
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

    if (isAutoGroupMode) {
      const autoGroup = normalizeAutoGroupPayload(parsedModelJSON, upstreamText);
      const out = {
        message: JSON.stringify(autoGroup),
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
          confidence: autoGroup.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
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

    if (isReflectReadableInsightsMode) {
      const normalized = normalizeReadableInsightsPayload(parsedModelJSON, upstreamText);
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

      const out = {
        message: normalized.message,
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
          usedContext: finalUsedContext,
          claimedUsedContext,
          evidence: modelEvidence,
          confidence,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isFulfillmentReadableInsightMode) {
      const normalized = normalizeReadableInsightsPayload(parsedModelJSON, upstreamText);
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

      const out = {
        message: normalizeFulfillmentReadableInsightMessage(normalized.message),
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
          usedContext: finalUsedContext,
          claimedUsedContext,
          evidence: modelEvidence,
          confidence,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isPurposeReadableInsightMode) {
      const normalized = normalizeReadableInsightsPayload(parsedModelJSON, upstreamText);
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

      const out = {
        message: normalizeFulfillmentReadableInsightMessage(normalized.message),
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
          usedContext: finalUsedContext,
          claimedUsedContext,
          evidence: modelEvidence,
          confidence,
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

function detectAutoGroupMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Plan Step 3 (Group).");
}

function detectReflectReadableInsightsMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Create a readable insights summary for a completed Loom Action Blocks session.");
}

function detectFulfillmentReadableInsightMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Create a readable insight for one Fulfillment Area in Loom Fulfillment Insights.");
}

function detectPurposeReadableInsightMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Create a readable insight for one Purpose passion in Loom Purpose Insights.");
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

function normalizeAutoGroupPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw) ? confidenceRaw : "low";
  const reason = typeof raw?.reason === "string" ? truncateAtWordBoundary(raw.reason.trim(), 240) : "";

  const groups = Array.isArray(raw?.groups) ? raw.groups : [];
  const normalizedGroups = groups
    .filter((g) => g && typeof g === "object")
    .map((g) => {
      const nameValue =
        (typeof g.name === "string" && g.name.trim() ? g.name : null) ||
        (typeof g.groupName === "string" && g.groupName.trim() ? g.groupName : null) ||
        (typeof g.title === "string" && g.title.trim() ? g.title : null);
      const name = nameValue ? truncateAtWordBoundary(nameValue.trim(), 80) : "Related Actions";
      const fulfillmentAreaRaw =
        (typeof g.fulfillmentArea === "string" ? g.fulfillmentArea : "") ||
        (typeof g.category === "string" ? g.category : "");
      const fulfillmentArea = truncateAtWordBoundary(String(fulfillmentAreaRaw || "").trim(), 80);
      const ids =
        Array.isArray(g.actionIDs) ? g.actionIDs :
        (Array.isArray(g.actionIds) ? g.actionIds :
        (Array.isArray(g.ids) ? g.ids :
        (Array.isArray(g.actions) ? g.actions : [])));
      const actionIDs = ids
        .map((x) => {
          if (typeof x === "string") return x.trim();
          if (x && typeof x === "object") {
            if (typeof x.id === "string") return x.id.trim();
            if (typeof x.actionID === "string") return x.actionID.trim();
            if (typeof x.actionId === "string") return x.actionId.trim();
          }
          return "";
        })
        .filter(Boolean)
        .filter((x) => /^[0-9a-fA-F-]{36}$/.test(x));
      return { name, fulfillmentArea, actionIDs };
    })
    .filter((g) => g.actionIDs.length >= 3)
    .slice(0, 8);

  const seen = new Set();
  const dedupedGroups = [];
  for (const group of normalizedGroups) {
    let hasDup = false;
    for (const id of group.actionIDs) {
      if (seen.has(id)) {
        hasDup = true;
        break;
      }
    }
    if (hasDup) continue;
    group.actionIDs.forEach((id) => seen.add(id));
    dedupedGroups.push(group);
  }

  const groupedCount = dedupedGroups.reduce((sum, g) => sum + g.actionIDs.length, 0);

  if (dedupedGroups.length < 2 || groupedCount < 6) {
    return { confidence: "low", reason: reason || "Not enough strong groups.", groups: [] };
  }

  // Be resilient: if the model returns a structurally valid grouping but marks confidence "medium",
  // promote it so the app can use the result instead of failing closed.
  const promotedConfidence = (confidence === "high" || confidence === "medium") ? "high" : "low";

  if (promotedConfidence !== "high") {
    return { confidence: "low", reason: reason || "Low confidence grouping.", groups: [] };
  }

  return {
    confidence: promotedConfidence,
    reason,
    groups: dedupedGroups,
  };
}

function normalizeReadableInsightsPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  let message = "";
  if (typeof raw?.message === "string") {
    message = raw.message;
  } else if (typeof raw?.reply === "string") {
    message = raw.reply;
  } else if (typeof raw?.insights === "string") {
    message = raw.insights;
  } else if (typeof fallbackText === "string") {
    message = fallbackText;
  }

  message = String(message || "").replace(/\s+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
  message = truncateAtWordBoundary(message, 1400);

  const debug = raw?.debug && typeof raw.debug === "object" ? raw.debug : null;

  return {
    message: message || "Loom could not generate readable insights for this session.",
    debug,
  };
}

function normalizeFulfillmentReadableInsightMessage(message) {
  let text = String(message || "").replace(/\s+/g, " ").trim();
  if (!text) return "This Fulfillment Area shows a mixed pattern that needs closer review.";

  // Prefer a complete sentence within ~150 chars.
  if (text.length > 150) {
    let prefix = text.slice(0, 150).trim();
    const sentenceIdx = Math.max(prefix.lastIndexOf("."), prefix.lastIndexOf("!"), prefix.lastIndexOf("?"));
    if (sentenceIdx > 20) {
      prefix = prefix.slice(0, sentenceIdx + 1).trim();
    } else {
      const punctIdx = Math.max(prefix.lastIndexOf(","), prefix.lastIndexOf(";"), prefix.lastIndexOf(":"));
      if (punctIdx > 20) {
        prefix = prefix.slice(0, punctIdx).trim() + ".";
      } else {
        const spaceIdx = prefix.lastIndexOf(" ");
        prefix = (spaceIdx > 20 ? prefix.slice(0, spaceIdx) : prefix).trim() + ".";
      }
    }
    text = prefix;
  }

  // Reduce obvious recap/filler if model slips.
  text = text
    .replace(/^during (this|the) (loom )?fulfillment (area )?(week|insights?)[:,]?\s*/i, "")
    .replace(/^during this week[:,]?\s*/i, "")
    .replace(/^a total of\s+/i, "");

  if (!/[.!?]$/.test(text)) text += ".";
  return text.trim();
}

function isSupportedFollowUpPrompt(prompt) {
  const p = String(prompt || "").trim().toLowerCase();
  if (!p) return false;

  const unsupportedConcepts = [
    " skill ",
    "skills",
    "certification",
    "resume",
    "interview prep",
    "meal prep",
    "recipes",
    "supplement",
    "macros",
    "calories",
    "protein target"
  ];
  if (unsupportedConcepts.some((term) => p.includes(term))) return false;

  const trackedConceptHints = [
    "purpose",
    "vision",
    "passion",
    "fulfillment",
    "mission",
    "identity",
    "little win",
    "outcome",
    "objective",
    "action block",
    "action",
    "capture",
    "vacation",
    "recently deleted",
    "weekly plan",
    "carryover"
  ];

  const actionOrDecisionHints = [
    "improve",
    "replace",
    "revise",
    "add",
    "connect",
    "focus",
    "review",
    "fix",
    "unstuck",
    "next",
    "prioritize",
    "plan",
    "clarify",
    "align"
  ];

  const mentionsTrackedConcept = trackedConceptHints.some((term) => p.includes(term));
  const hasActionOrDecisionIntent = actionOrDecisionHints.some((term) => p.includes(term));

  // Allow common outcome phrasing even if it doesn't explicitly say "outcome".
  const startsWithHighValueQuestion =
    p.startsWith("what should i do next for ") ||
    p.startsWith("what is the highest-leverage move for ") ||
    p.startsWith("how can i improve ") ||
    p.startsWith("why is ");

  if (!(mentionsTrackedConcept || startsWithHighValueQuestion)) return false;
  if (!(hasActionOrDecisionIntent || startsWithHighValueQuestion)) return false;

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

      if (
        normalizedType === "replaceFulfillmentMission" ||
        normalizedType === "addFulfillmentIdentity" ||
        normalizedType === "replaceFulfillmentIdentity" ||
        normalizedType === "replacePurposeVision" ||
        normalizedType === "addPassion" ||
        normalizedType === "launchAddFulfillmentAreaPrefill"
      ) {
        const cleanedPayload = {};
        for (const [k, v] of Object.entries(payload || {})) {
          if (typeof v === "string") {
            const trimmed = v.trim();
            if (trimmed) cleanedPayload[k] = truncateAtWordBoundary(trimmed, 400);
          }
        }
        return {
          id,
          title: title || normalizedType,
          type: normalizedType,
          payload: cleanedPayload,
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
