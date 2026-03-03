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
    const clientRequestHash = sanitizeClientDebugValue(client?.requestHash);
    const clientRequestId = sanitizeClientDebugValue(client?.requestId);

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
    const requestedIntent = normalizeIntent(client?.intent);
    const isFollowUpPromptMode = detectFollowUpPromptMode(nonSystemMessages);
    const isAutoGroupMode = detectAutoGroupMode(nonSystemMessages);
    const detectedAutoWriteVisionMode = detectAutoWriteVisionMode(nonSystemMessages);
    const detectedAutoWritePassionsMode = detectAutoWritePassionsMode(nonSystemMessages);
    const detectedAutoWriteMissionMode = detectAutoWriteMissionMode(nonSystemMessages);
    const detectedAutoWriteIdentityMode = detectAutoWriteIdentityMode(nonSystemMessages);
    const detectedAutoWriteLittleWinMode = detectAutoWriteLittleWinMode(nonSystemMessages);
    const isPlanResultStrictIntent = requestedIntent === "plan_result_autowrite";
    const isAutoWritePlanResultMode =
      isPlanResultStrictIntent || detectAutoWritePlanResultMode(nonSystemMessages);
    const isReflectReadableInsightsMode = detectReflectReadableInsightsMode(nonSystemMessages);
    const isFulfillmentReadableInsightMode = detectFulfillmentReadableInsightMode(nonSystemMessages);
    const isPurposeReadableInsightMode = detectPurposeReadableInsightMode(nonSystemMessages);
    const isOnboardingPurposeInsightsMode =
      requestedIntent === "onboarding_insights_purpose" ||
      detectOnboardingPurposeInsightsMode(nonSystemMessages);
    const isOnboardingFulfillmentInsightsMode =
      requestedIntent === "onboarding_insights_fulfillment" ||
      detectOnboardingFulfillmentInsightsMode(nonSystemMessages);
    const isOnboardingDiagnosticsInsightsMode =
      requestedIntent === "onboarding_insights_diagnostics" ||
      detectOnboardingDiagnosticsInsightsMode(nonSystemMessages);

    const purposeAutoWriteMode = requestedIntent === "autowrite_purpose"
      ? (detectedAutoWritePassionsMode ? "passions" : "vision")
      : (detectedAutoWriteVisionMode ? "vision" : (detectedAutoWritePassionsMode ? "passions" : null));
    const fulfillmentAutoWriteMode = requestedIntent === "autowrite_fulfillment"
      ? (detectedAutoWriteIdentityMode ? "identity" : (detectedAutoWriteLittleWinMode ? "littlewin" : "mission"))
      : (detectedAutoWriteMissionMode
        ? "mission"
        : (detectedAutoWriteIdentityMode ? "identity" : (detectedAutoWriteLittleWinMode ? "littlewin" : null)));

    const isAutoWriteVisionMode = purposeAutoWriteMode === "vision";
    const isAutoWritePassionsMode = purposeAutoWriteMode === "passions";
    const isAutoWriteMissionMode = fulfillmentAutoWriteMode === "mission";
    const isAutoWriteIdentityMode = fulfillmentAutoWriteMode === "identity";
    const isAutoWriteLittleWinMode = fulfillmentAutoWriteMode === "littlewin";
    const latestUserMessage = [...nonSystemMessages].reverse().find((m) => m?.role === "user");
    const latestUserContent = String(latestUserMessage?.content || "");
    const isAutoWriteVisionRewordMode =
      isAutoWriteVisionMode && /Vision mode:\s*Reword Vision/i.test(latestUserContent);
    const fulfillmentInsightPayload = isFulfillmentReadableInsightMode
      ? extractReadableInsightPayload(nonSystemMessages, "fulfillment")
      : null;
    const purposeInsightPayload = isPurposeReadableInsightMode
      ? extractReadableInsightPayload(nonSystemMessages, "purpose")
      : null;

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
    const personalizationInfo = buildPersonalizationContext(context);

    const workerPromptVersion = (() => {
      if (isAutoGroupMode) return "autogroup-v1";
      if (isAutoWriteVisionMode) {
        return isAutoWriteVisionRewordMode
          ? "autowrite-vision-v2-reword"
          : "autowrite-vision-v2";
      }
      if (isAutoWritePassionsMode) return "autowrite-passions-v1";
      if (isAutoWriteLittleWinMode) return "autowrite-littlewin-v2";
      if (isAutoWriteIdentityMode) return "autowrite-identity-v1";
      if (isAutoWriteMissionMode) return "autowrite-mission-v1";
      if (isPlanResultStrictIntent) return "plan-result-autowrite-v1";
      if (isAutoWritePlanResultMode) return "autowrite-plan-result-v1";
      if (isOnboardingPurposeInsightsMode) return "onboarding-insights-purpose-v1";
      if (isOnboardingFulfillmentInsightsMode) return "onboarding-insights-fulfillment-v2";
      if (isOnboardingDiagnosticsInsightsMode) return "onboarding-insights-diagnostics-v2";
      if (isFollowUpPromptMode) return "followup-prompts-v1";
      if (isReflectReadableInsightsMode) return "reflect-readable-insights-v1";
      if (isFulfillmentReadableInsightMode) return "fulfillment-readable-insights-v1";
      if (isPurposeReadableInsightMode) return "purpose-readable-insights-v1";
      return "grounding-cta-v3";
    })();

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
    ].join("\n") : isAutoWriteVisionMode ? [
      "Intent: autowrite_purpose.",
      "You generate AutoWrite vision suggestions for Loom Purpose Vision.",
      "Use APP_CONTEXT_JSON and the provided current vision.",
      "Respect the requested vision mode from the user message.",
      'If it says "Vision mode: Reword Vision", improve/reword the current vision while preserving its intent and direction.',
      'If it says "Vision mode: New Vision", generate fresh options from context.',
      "If Reword Vision is requested but current vision is empty, fall back to New Vision behavior.",
      "Vision guidance to follow:",
      "- If there were no limits, what life would you create?",
      "- This is not a goal; it's long-term direction.",
      "- Keep wording clear, practical, and specific.",
      'Example of a strong vision: "I live a life of purpose, growth, and freedom. I build meaningful work that creates value for others while giving me time, financial independence, and the ability to choose how I live. I am healthy, energized, and surrounded by strong relationships, and I continue to learn, lead, and make a positive impact."',
      "Return JSON ONLY in this exact shape:",
      '{"suggestions":["string"],"confidence":"high|medium|low"}',
      "Rules:",
      "- Return 1-2 suggestions.",
      "- Each suggestion must be <=150 characters.",
      "- No numbering, no bullets, no markdown.",
      "- Suggestions must be relevant to Purpose Vision context.",
      "- Do not output anything outside the JSON object."
    ].join("\n") : isAutoWritePassionsMode ? [
      "Intent: autowrite_purpose.",
      "You generate AutoWrite passion suggestions for Loom Purpose Passions.",
      "Use APP_CONTEXT_JSON, current passion buckets, and prior suggestions.",
      "Use guidance from Loom's Purpose instructions and Need ideas content.",
      "Bucket guidance:",
      "- Love: what the user loves and wants more of.",
      "- Vows: commitments and non-negotiable principles.",
      "- Thrill: what energizes and excites the user.",
      "- Hate: what the user rejects and stands against.",
      "Return JSON ONLY in this exact shape:",
      '{"suggestions":[{"emotion":"love|vows|thrill|just","passion":"string"}],"confidence":"high|medium|low"}',
      "Rules:",
      "- Return 2-4 suggestions.",
      "- Keep each passion 1-5 words. Fewer words is preferred.",
      "- Keep wording concrete, strong, and value-driven.",
      "- Map Hate to emotion='just'.",
      "- Avoid repeating items already present in the user's bucket lists.",
      "- Do not paraphrase or lightly reword existing bucket items; suggestions must be clearly distinct concepts.",
      "- Avoid semantic overlap with current items.",
      "- Prefer direct noun phrases; avoid verb-led phrasing like 'Rejecting ...', 'Challenging ...', 'Avoiding ...'.",
      "- Each suggestion must make sense as a standalone passion item.",
      "- Prefer variety across buckets when possible.",
      "- No numbering, no bullets, no markdown.",
      "- Do not output anything outside the JSON object."
    ].join("\n") : isAutoWriteLittleWinMode ? [
      "Intent: autowrite_fulfillment.",
      "You generate AutoWrite little win suggestions for Loom Fulfillment Little Wins.",
      "Use APP_CONTEXT_JSON and the provided Fulfillment Area name.",
      "If mission and identities are provided, align suggestions to them.",
      "Little Win guidance to follow:",
      "- Small actions create momentum.",
      "- Suggest easy, repeatable, practical little wins for this area.",
      '- Keep suggestions concise and specific, like: "10,000 steps", "60 min workout", "Follow diet".',
      "Return JSON ONLY in this exact shape:",
      '{"suggestions":[{"activity":"string","replaceActivity":"string optional"}],"confidence":"high|medium|low"}',
      "Rules:",
      "- Return 1-2 suggestions.",
      "- activity must be 1-7 words and <=80 characters.",
      "- Include replaceActivity only when there are exactly 3 current little wins; otherwise omit replaceActivity.",
      "- replaceActivity must name the weakest current little win to replace.",
      "- Do not repeat or lightly reword existing little wins.",
      "- Avoid semantic overlap with Current Little Wins; suggestions should be clearly distinct.",
      "- No numbering, no bullets, no markdown.",
      "- Suggestions must be relevant to the provided Fulfillment Area.",
      "- Do not output anything outside the JSON object."
    ].join("\n") : isAutoWriteIdentityMode ? [
      "Intent: autowrite_fulfillment.",
      "You generate AutoWrite identity suggestions for Loom Fulfillment Set Identity.",
      "Use APP_CONTEXT_JSON and the provided Fulfillment Area name.",
      "Identity guidance to follow:",
      "- Roles define identity and guide how decisions/actions happen before results.",
      "- Keep identities clear, empowering, and specific to the area.",
      "Return JSON ONLY in this exact shape:",
      '{"suggestions":[{"identity":"string","replaceIdentity":"string optional"}],"confidence":"high|medium|low"}',
      "Rules:",
      "- Return 1-2 suggestions.",
      "- identity must be 1-3 words.",
      "- identity must be <=40 characters.",
      "- If 3 current identities already exist, include replaceIdentity for each suggestion.",
      "- replaceIdentity must name the weakest current identity to replace.",
      "- Do not repeat or lightly reword existing identities.",
      "- Avoid semantic overlap with Current Identities; suggestions should be clearly distinct.",
      "- No numbering, no bullets, no markdown.",
      "- Suggestions must be relevant to the provided Fulfillment Area.",
      "- Do not output anything outside the JSON object."
    ].join("\n") : isAutoWriteMissionMode ? [
      "Intent: autowrite_fulfillment.",
      "You generate AutoWrite mission suggestions for Loom Fulfillment Define Mission.",
      "Use APP_CONTEXT_JSON and the provided Fulfillment Area name.",
      "Mission guidance to follow:",
      "- Mission is your deeper reason; it helps consistency when motivation fades.",
      "- Focus on why the area matters and how life improves when this area gets stronger.",
      "- Keep wording clear, practical, and specific.",
      "Return JSON ONLY in this exact shape:",
      '{"suggestions":["string"],"confidence":"high|medium|low"}',
      "Rules:",
      "- Return 1-2 suggestions.",
      "- Each suggestion must be <=120 characters.",
      "- No numbering, no bullets, no markdown.",
      "- Suggestions must be relevant to the provided Fulfillment Area.",
      "- Do not output anything outside the JSON object."
    ].join("\n") : isAutoWritePlanResultMode ? (
      isPlanResultStrictIntent ? [
        "Intent: plan_result_autowrite.",
        "You generate one Result suggestion for Loom Plan Result AutoWrite.",
        "Use ONLY the user payload JSON (areaName + actions[]).",
        "Do not use APP_CONTEXT_JSON, diagnostics, or personalization.",
        "Result must summarize the provided actions directly, not values language.",
        "If confidence is low or actions are too vague, return an error object.",
        "Return JSON in exactly one of these shapes:",
        '{"message":"string","actions":[],"debug":{"usedContext":false,"confidence":"high|medium|low","evidence":["actions[]"]}}',
        '{"error":"low_confidence","message":"Not enough clarity in actions to infer a Result."}',
        "Rules:",
        "- message must be 6-12 words.",
        "- Keep wording specific and action-grounded.",
        "- Avoid generic wording.",
        "- No markdown, no bullets, no extra keys."
      ].join("\n") : [
        "You generate AutoWrite Result suggestions for Loom Plan Result page.",
        "Use APP_CONTEXT_JSON and the provided fulfillment-area action context.",
        "Each suggestion should represent the shared outcome that all listed actions in that area are moving toward.",
        "Return JSON ONLY in this exact shape:",
        '{"suggestions":[{"fulfillmentArea":"string","result":"string"}],"confidence":"high|medium|low"}',
        "Rules:",
        "- Return one suggestion per requested fulfillment area.",
        "- Use only fulfillmentArea names provided in the prompt.",
        "- Each result must be <=8 words (fewer is preferred).",
        "- Keep wording concise, practical, and outcome-focused.",
        "- Do not repeat existing results or prior suggestions when provided.",
        "- No numbering, no bullets, no markdown.",
        "- Do not output anything outside the JSON object."
      ].join("\n")
    ) : isOnboardingPurposeInsightsMode ? [
      "Intent: onboarding_insights_purpose.",
      "Generate Purpose onboarding insights for Loom.",
      "Use APP_CONTEXT_JSON and the Purpose onboarding payload from the user message.",
      "Focus on diagnostics A/B/D/E plus Purpose text (Vision/Purpose/Passions).",
      "Output 3 cards in order: Your drivers, Your tension, First direction.",
      "Each card must be concrete, concise, and actionable (1-2 short sentences).",
      "When APP_CONTEXT_JSON exists, cite at least 2 concrete details from diagnostics + purpose content.",
      "Do not give generic advice. Ground every card in user data.",
      "If diagnostic personalization is missing, keep the cards useful but general and include a gentle nudge to complete Account -> Personalization.",
      "Return JSON ONLY in this exact shape:",
      '{"cards":[{"title":"Your drivers","body":"string"},{"title":"Your tension","body":"string"},{"title":"First direction","body":"string"}],"confidence":"high|medium|low","nudge":"string optional","debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}'
    ].join("\n") : isOnboardingFulfillmentInsightsMode ? [
      "Intent: onboarding_insights_fulfillment.",
      "Generate Fulfillment onboarding insights for Loom.",
      "Use APP_CONTEXT_JSON and the Fulfillment onboarding payload from the user message.",
      "Focus on diagnostics + purpose + fulfillment setup evidence.",
      "Output exactly 2 cards in order: Fulfillment areas, Next direction.",
      "Each card must be grounded, concise, and practical (1-3 short sentences).",
      "Do NOT restate selected category names or list categories.",
      "Do NOT use the phrase 'You selected'.",
      "Do NOT rename selected fulfillment categories.",
      "Do NOT invent gaps, neglect patterns, or category priorities without evidence.",
      "Fulfillment areas card: explain how a well-rounded setup creates coverage and tradeoff clarity for this user.",
      "Fulfillment areas card must reference at least one concrete diagnostic or purpose detail when available.",
      "If diagnostics or purpose context are missing, explicitly say that limitation briefly and still provide a useful balanced fallback.",
      "Next direction card: broad execution approach tied to evidence, without one-off habit advice.",
      "Next direction card must end with a final sentence that starts with 'Loom will help you'.",
      "Avoid random habit tips unless directly supported by evidence.",
      "Avoid generic motivational fluff and avoid category listing.",
      "When APP_CONTEXT_JSON has diagnostics/purpose context, debug.evidence must include at least 1 concrete purpose/diagnostic path.",
      "Return JSON ONLY in this exact shape:",
      '{"cards":[{"title":"FULFILLMENT AREAS","body":"string"},{"title":"NEXT DIRECTION","body":"string"}],"debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}'
    ].join("\n") : isOnboardingDiagnosticsInsightsMode ? [
      "Intent: onboarding_insights_diagnostics.",
      "Generate Quick Diagnostic insights for Loom onboarding.",
      "Use APP_CONTEXT_JSON plus the diagnostic payload from the user message.",
      "Output exactly 3 cards in this order and title casing: Root cause, Fulfillment areas, Next direction.",
      "Root cause must be 1-2 short sentences and reference diagnostics A (stress source) and B (what breaks first).",
      "Root cause must interpret behavior and tension, not copy labels.",
      "Root cause must avoid quote-style phrasing and must not use 'You said' or 'You selected'.",
      'Fulfillment areas must include selected areas and use this exact sentence when diagnostics exist: "Every task, goal, and little win will land in one of these areas, so your life stays organized."',
      "Next direction must be 1-2 short sentences and <=40 words total.",
      "Next direction must be forward-looking, confidence-building, and momentum-focused.",
      "Next direction must emphasize focus, consistency, simpler priorities, and reduced overwhelm.",
      "Next direction must avoid restating user answers or diagnostic labels.",
      "Next direction must avoid phrases like 'Your current planning pattern', 'You selected', and 'This means'.",
      "Next direction must avoid task instructions and immediate execution language.",
      "Next direction must not repeat the Root cause card.",
      "Hard rules:",
      "- If APP_CONTEXT_JSON exists, use diagnostics to shape tone and emphasis implicitly without restating answers.",
      "- Do not use 'this week' unless the user explicitly asked for a week-based plan.",
      "- Do not use generic productivity advice.",
      "- Do not include 'Goal:' labels or corporate phrasing.",
      "Fallback rule for missing diagnostics:",
      "- Keep the same 3 headers, explicitly state Loom does not have personalization yet, and tell the user to use Edit answers.",
      "Return JSON ONLY in this exact shape:",
      '{"cards":[{"title":"Root cause","body":"string"},{"title":"Fulfillment areas","body":"string"},{"title":"Next direction","body":"string"}],"confidence":"high|medium|low","nudge":"string optional","debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}'
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
      "Only suggest prompts tied to concepts clearly represented in APP_CONTEXT_JSON (e.g., Fulfillment Areas, Outcomes/Goals, Action Blocks, Little Wins, Capture, Purpose, Vacation Mode, Recently Deleted).",
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
      "If recentCategoryScores has only one value, treat it as baseline-only data: line 1 must explain trends/movers are not established yet and line 2 must give a starter action to build score foundations.",
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
      "If recentScores has only one value, treat it as baseline-only data: line 1 must explain trends/movers are not established yet and line 2 must give a starter action to build score foundations.",
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

    const personalizationInstruction = [
      "Personalization grounding rules:",
      "- Personalization diagnostic context is provided in APP_CONTEXT_JSON.personalization and USER_PERSONALIZATION_CONTEXT.",
      "- When giving planning, focus, or next-action guidance and personalization exists, ground recommendations in at least two concrete fields (stressSource, breakPoint, planningReality, desiredChange, lifeAreasSelected).",
      "- Avoid generic guidance; tie suggestions and CTA ideas directly to those personalization fields when available.",
      "- If personalization context is missing for planning/focus guidance, briefly state that diagnostic context is unavailable and suggest running Quick diagnostic once, then proceed with the best available context.",
      "- Use only explicit diagnostic selections and do not infer sensitive traits."
    ].join("\n");

    const groundedMessages = isPlanResultStrictIntent
      ? [
        { role: "system", content: coreInstructions },
        ...nonSystemMessages,
      ]
      : [
        { role: "system", content: [coreInstructions, personalizationInstruction].join("\n\n") },
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
                hasPersonalizationContext: personalizationInfo.hasCurrent,
                workerPromptVersion,
                requestedIntent: requestedIntent || null,
                client: {
                  ...(client && typeof client === "object" ? client : {}),
                  requestHash: clientRequestHash,
                  requestId: clientRequestId,
                },
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
        {
          role: "system",
          content: `USER_PERSONALIZATION_CONTEXT:\n${personalizationInfo.text}`,
        },
        ...nonSystemMessages,
      ];

    const model = env.OPENAI_MODEL || "gpt-4o-mini";
    const temperature = 0.2;
    const maxTokens = isAutoGroupMode ? 700
      : isAutoWriteVisionMode ? 220
      : isAutoWritePassionsMode ? 260
      : isAutoWriteLittleWinMode ? 260
      : isAutoWriteIdentityMode ? 260
      : isAutoWriteMissionMode ? 220
      : isPlanResultStrictIntent ? 160
      : isAutoWritePlanResultMode ? 260
      : isOnboardingPurposeInsightsMode ? 600
      : isOnboardingFulfillmentInsightsMode ? 600
      : isFollowUpPromptMode ? 350
      : isReflectReadableInsightsMode ? 650
      : isFulfillmentReadableInsightMode ? 450
      : isPurposeReadableInsightMode ? 450
      : 900;

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
          max_tokens: maxTokens,
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
	                parseMode: "upstream_error",
	              }),
	              requestHash: clientRequestHash,
	              requestId: clientRequestId,
	            },
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
	              parseMode: "upstream_fetch_failed",
	            }),
	            requestHash: clientRequestHash,
	            requestId: clientRequestId,
	          },
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

    if (isAutoWriteMissionMode) {
      const autoWrite = normalizeAutoWriteMissionPayload(parsedModelJSON, upstreamText);
      if (!personalizationInfo.hasCurrent) {
        autoWrite.nudge = "For more personalized suggestions, complete Account -> Personalization.";
      }
      const out = {
        message: JSON.stringify(autoWrite),
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
          confidence: autoWrite.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isAutoWriteIdentityMode) {
      const autoWrite = normalizeAutoWriteIdentityPayload(parsedModelJSON, upstreamText);
      if (!personalizationInfo.hasCurrent) {
        autoWrite.nudge = "For more personalized suggestions, complete Account -> Personalization.";
      }
      const out = {
        message: JSON.stringify(autoWrite),
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
          confidence: autoWrite.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isAutoWriteVisionMode) {
      const autoWrite = normalizeAutoWriteVisionPayload(parsedModelJSON, upstreamText);
      if (!personalizationInfo.hasCurrent) {
        autoWrite.nudge = "For more personalized suggestions, complete Account -> Personalization.";
      }
      const out = {
        message: JSON.stringify(autoWrite),
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
          confidence: autoWrite.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isAutoWritePassionsMode) {
      const autoWrite = normalizeAutoWritePassionsPayload(parsedModelJSON, upstreamText);
      if (!personalizationInfo.hasCurrent) {
        autoWrite.nudge = "For more personalized suggestions, complete Account -> Personalization.";
      }
      const out = {
        message: JSON.stringify(autoWrite),
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
          confidence: autoWrite.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isAutoWriteLittleWinMode) {
      const autoWrite = normalizeAutoWriteLittleWinPayload(parsedModelJSON, upstreamText);
      if (!personalizationInfo.hasCurrent) {
        autoWrite.nudge = "For more personalized suggestions, complete Account -> Personalization.";
      }
      const out = {
        message: JSON.stringify(autoWrite),
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
          confidence: autoWrite.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isAutoWritePlanResultMode) {
      if (isPlanResultStrictIntent) {
        const normalized = normalizePlanResultSinglePayload(parsedModelJSON, upstreamText);
        if (normalized.error === "low_confidence") {
          return json(
            {
              error: "low_confidence",
              message: "Not enough clarity in actions to infer a Result.",
            },
            200,
            corsHeaders(request)
          );
        }

        const out = {
          message: normalized.message,
          actions: [],
          debug: {
            usedContext: false,
            evidence: ["actions[]"],
            confidence: normalized.confidence || "high",
          },
        };
        return json(out, 200, corsHeaders(request));
      }

      const autoWrite = normalizeAutoWritePlanResultPayload(parsedModelJSON, upstreamText);
      const out = {
        message: JSON.stringify(autoWrite),
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
          confidence: autoWrite.confidence || null,
        },
      };
      return json(out, 200, corsHeaders(request));
    }

    if (isOnboardingPurposeInsightsMode || isOnboardingFulfillmentInsightsMode || isOnboardingDiagnosticsInsightsMode) {
      const mode = isOnboardingPurposeInsightsMode
        ? "purpose"
        : (isOnboardingFulfillmentInsightsMode ? "fulfillment" : "diagnostics");
      const normalized = normalizeOnboardingInsightsPayload(
        parsedModelJSON,
        upstreamText,
        mode,
        !personalizationInfo.hasCurrent,
        context
      );
      const modelDebug =
        normalized.debug && typeof normalized.debug === "object" ? normalized.debug : {};
      const modelEvidence = Array.isArray(modelDebug.evidence)
        ? modelDebug.evidence.filter((x) => typeof x === "string").slice(0, 20)
        : [];
      const fallbackEvidenceBase = modelEvidence.length > 0
        ? modelEvidence
        : buildOnboardingInsightsEvidence(mode, context, personalizationInfo.hasCurrent);
      const fallbackEvidence = mode === "diagnostics"
        ? ensureDiagnosticsInsightsEvidencePaths(
          fallbackEvidenceBase,
          context,
          personalizationInfo.hasCurrent
        )
        : (mode === "fulfillment"
          ? ensureFulfillmentInsightsEvidencePaths(
            fallbackEvidenceBase,
            context,
            personalizationInfo.hasCurrent
          )
          : fallbackEvidenceBase);
      const claimedUsedContext =
        typeof modelDebug.usedContext === "boolean" ? modelDebug.usedContext : null;
      const confidence = typeof modelDebug.confidence === "string"
        ? modelDebug.confidence
        : (typeof normalized.confidence === "string" ? normalized.confidence : null);
      const finalUsedContext =
        typeof claimedUsedContext === "boolean"
          ? claimedUsedContext
          : contextBytes > 0 && fallbackEvidence.length > 0;
      const responseMessagePayload = {
        cards: normalized.cards,
        confidence: normalized.confidence || "medium",
        ...(normalized.nudge ? { nudge: normalized.nudge } : {}),
        ...(mode === "fulfillment"
          ? {
            debug: {
              usedContext: finalUsedContext,
              evidence: fallbackEvidence,
              confidence: confidence || normalized.confidence || "low",
            },
          }
          : {}),
      };

      const out = {
        message: JSON.stringify(responseMessagePayload),
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
          requestHash: clientRequestHash,
          requestId: clientRequestId,
          usedContext: finalUsedContext,
          claimedUsedContext,
          evidence: fallbackEvidence,
          confidence,
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
        message: normalizeReadableInsightMessage(normalized.message, {
          mode: "fulfillment",
          payload: fulfillmentInsightPayload
        }),
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
        message: normalizeReadableInsightMessage(normalized.message, {
          mode: "purpose",
          payload: purposeInsightPayload
        }),
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

function normalizeIntent(value) {
  const intent = String(value || "").trim().toLowerCase();
  const supported = new Set([
    "autowrite_purpose",
    "autowrite_fulfillment",
    "plan_result_autowrite",
    "onboarding_insights_purpose",
    "onboarding_insights_fulfillment",
    "onboarding_insights_diagnostics",
  ]);
  return supported.has(intent) ? intent : "";
}

function normalizeAssistantJSON(parsed, fallbackText) {
  if (parsed && typeof parsed === "object" && Array.isArray(parsed.cards)) {
    return {
      message: JSON.stringify({
        cards: parsed.cards,
        ...(typeof parsed.nudge === "string" ? { nudge: parsed.nudge } : {}),
        ...(parsed.debug && typeof parsed.debug === "object" ? { debug: parsed.debug } : {}),
      }),
      actions: Array.isArray(parsed.actions) ? parsed.actions : [],
      debug: parsed.debug && typeof parsed.debug === "object" ? parsed.debug : null,
    };
  }

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

function detectAutoWriteMissionMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Fulfillment Define Mission (AutoWrite).");
}

function detectAutoWriteIdentityMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Fulfillment Set Identity (AutoWrite).");
}

function detectAutoWriteVisionMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Purpose Vision (AutoWrite).");
}

function detectAutoWritePassionsMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Purpose Passions (AutoWrite).");
}

function detectAutoWriteLittleWinMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Fulfillment Little Wins (AutoWrite).");
}

function detectAutoWritePlanResultMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("You are helping with Loom Plan Result (AutoWrite).");
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

function detectOnboardingPurposeInsightsMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Generate Purpose onboarding insights for Loom.");
}

function detectOnboardingFulfillmentInsightsMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Generate Fulfillment onboarding insights for Loom.");
}

function detectOnboardingDiagnosticsInsightsMode(nonSystemMessages) {
  const latestUser = [...(nonSystemMessages || [])].reverse().find((m) => m?.role === "user");
  const content = String(latestUser?.content || "");
  return content.includes("Generate Quick Diagnostic insights for Loom");
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

function normalizeAutoWriteMissionPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const suggestionsSource = Array.isArray(raw?.suggestions)
    ? raw.suggestions
    : (Array.isArray(raw?.missions) ? raw.missions : []);

  const suggestions = suggestionsSource
    .filter((x) => typeof x === "string")
    .map((x) => x.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .map((x) => truncateAtWordBoundary(x, 120))
    .slice(0, 2);

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (suggestions.length > 0 ? "medium" : "low");

  if (suggestions.length === 0) {
    return {
      suggestions: [],
      confidence: "low",
    };
  }

  return {
    suggestions,
    confidence,
  };
}

function normalizeAutoWriteVisionPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const suggestionsSource = Array.isArray(raw?.suggestions)
    ? raw.suggestions
    : (Array.isArray(raw?.visions) ? raw.visions : []);

  const suggestions = suggestionsSource
    .filter((x) => typeof x === "string")
    .map((x) => x.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .map((x) => truncateAtWordBoundary(x, 150))
    .slice(0, 2);

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (suggestions.length > 0 ? "medium" : "low");

  if (suggestions.length === 0) {
    return {
      suggestions: [],
      confidence: "low",
    };
  }

  return {
    suggestions,
    confidence,
  };
}

function normalizePassionEmotionKey(value) {
  const key = String(value || "").trim().toLowerCase();
  if (!key) return null;
  if (key.includes("love")) return "love";
  if (key.includes("vow") || key.includes("commit")) return "vows";
  if (key.includes("thrill") || key.includes("excite")) return "thrill";
  if (key.includes("hate") || key.includes("just")) return "just";
  return null;
}

function normalizeAutoWritePassionsPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const source = Array.isArray(raw?.suggestions)
    ? raw.suggestions
    : (Array.isArray(raw?.passions) ? raw.passions : []);

  const suggestions = source
    .map((item) => {
      if (typeof item === "string") {
        const split = item.split(":");
        if (split.length < 2) return null;
        const emotion = normalizePassionEmotionKey(split[0]);
        const passion = truncateAtWordBoundary(
          String(split.slice(1).join(":")).replace(/\s+/g, " ").trim(),
          60
        );
        if (!emotion || !passion) return null;
        const words = passion.split(/\s+/).filter(Boolean).slice(0, 5).join(" ");
        return { emotion, passion: words };
      }
      if (!item || typeof item !== "object") return null;
      const emotionRaw = item.emotion || item.bucket || item.category || "";
      const emotion = normalizePassionEmotionKey(emotionRaw);
      const passionRaw = item.passion || item.text || item.value || "";
      const cleaned = String(passionRaw).replace(/\s+/g, " ").trim();
      if (!emotion || !cleaned) return null;
      const words = cleaned.split(/\s+/).filter(Boolean).slice(0, 5).join(" ");
      const passion = truncateAtWordBoundary(words, 60);
      if (!passion) return null;
      return { emotion, passion };
    })
    .filter(Boolean)
    .slice(0, 4);

  const deduped = [];
  const seen = new Set();
  for (const item of suggestions) {
    const key = `${item.emotion}|${String(item.passion).toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(item);
  }

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (deduped.length > 0 ? "medium" : "low");

  if (deduped.length === 0) {
    return {
      suggestions: [],
      confidence: "low",
    };
  }

  return {
    suggestions: deduped,
    confidence,
  };
}

function normalizeAutoWriteIdentityPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const source = Array.isArray(raw?.suggestions)
    ? raw.suggestions
    : (Array.isArray(raw?.identities) ? raw.identities : []);

  const suggestions = source
    .map((item) => {
      if (typeof item === "string") {
        const identity = normalizeIdentityAutoWriteText(item);
        return identity ? { identity, replaceIdentity: null } : null;
      }
      if (!item || typeof item !== "object") return null;
      const identityRaw = (item.identity || item.role || item.text || "");
      const replaceRaw = (item.replaceIdentity || item.replace || item.weakestIdentity || "");
      const identity = normalizeIdentityAutoWriteText(identityRaw);
      const replaceIdentity = truncateAtWordBoundary(String(replaceRaw).replace(/\s+/g, " ").trim(), 120);
      if (!identity) return null;
      return {
        identity,
        replaceIdentity: replaceIdentity || null,
      };
    })
    .filter(Boolean)
    .slice(0, 2);

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (suggestions.length > 0 ? "medium" : "low");

  if (suggestions.length === 0) {
    return {
      suggestions: [],
      confidence: "low",
    };
  }

  return {
    suggestions,
    confidence,
  };
}

function normalizeAutoWriteLittleWinPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const source = Array.isArray(raw?.suggestions)
    ? raw.suggestions
    : (Array.isArray(raw?.littleWins) ? raw.littleWins : []);

  const suggestions = source
    .map((item) => {
      if (typeof item === "string") {
        const activity = normalizeLittleWinAutoWriteText(item);
        return activity ? { activity, replaceActivity: null } : null;
      }
      if (!item || typeof item !== "object") return null;
      const activityRaw = (item.activity || item.littleWin || item.text || "");
      const replaceRaw = (item.replaceActivity || item.replace || item.weakestLittleWin || "");
      const activity = normalizeLittleWinAutoWriteText(activityRaw);
      const replaceActivity = truncateAtWordBoundary(String(replaceRaw).replace(/\s+/g, " ").trim(), 120);
      if (!activity) return null;
      return {
        activity,
        replaceActivity: replaceActivity || null,
      };
    })
    .filter(Boolean)
    .slice(0, 2);

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (suggestions.length > 0 ? "medium" : "low");

  if (suggestions.length === 0) {
    return {
      suggestions: [],
      confidence: "low",
    };
  }

  return {
    suggestions,
    confidence,
  };
}

function normalizePlanResultArea(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function normalizePlanResultText(value, maxWords = 12) {
  const cleaned = String(value || "").replace(/\s+/g, " ").trim();
  if (!cleaned) return "";
  const words = cleaned.split(" ").filter(Boolean).slice(0, maxWords).join(" ");
  return truncateAtWordBoundary(words, 140);
}

function normalizeAutoWritePlanResultPayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const source = Array.isArray(raw?.suggestions)
    ? raw.suggestions
    : (Array.isArray(raw?.results) ? raw.results : []);

  const suggestions = source
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const fulfillmentArea = normalizePlanResultArea(
        item.fulfillmentArea || item.area || item.label || item.category || ""
      );
      const result = normalizePlanResultText(
        item.result || item.suggestion || item.text || item.value || ""
        , 8
      );
      if (!fulfillmentArea || !result) return null;
      return { fulfillmentArea, result };
    })
    .filter(Boolean)
    .slice(0, 8);

  const deduped = [];
  const seen = new Set();
  for (const item of suggestions) {
    const key = `${String(item.fulfillmentArea).toLowerCase()}|${String(item.result).toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(item);
  }

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (deduped.length > 0 ? "medium" : "low");

  if (deduped.length === 0) {
    return {
      suggestions: [],
      confidence: "low",
    };
  }

  return {
    suggestions: deduped,
    confidence,
  };
}

function normalizePlanResultSinglePayload(parsed, fallbackText) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
    } catch {
      raw = null;
    }
  }

  const errorRaw = typeof raw?.error === "string" ? raw.error.toLowerCase().trim() : "";
  if (errorRaw === "low_confidence") {
    return {
      error: "low_confidence",
      message: "Not enough clarity in actions to infer a Result.",
    };
  }

  const message = normalizePlanResultText(
    raw?.message || raw?.result || raw?.text || "",
    12
  );
  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw) ? confidenceRaw : "medium";

  if (!message || countWords(message) < 6 || countWords(message) > 12 || confidence === "low") {
    return {
      error: "low_confidence",
      message: "Not enough clarity in actions to infer a Result.",
    };
  }

  return {
    message,
    confidence,
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

function normalizeOnboardingInsightsPayload(parsed, fallbackText, mode, needsPersonalizationNudge, context) {
  let raw = parsed && typeof parsed === "object" ? parsed : null;
  let parsedFromJSON = true;
  if (!raw) {
    try {
      raw = JSON.parse(String(fallbackText || ""));
      parsedFromJSON = true;
    } catch {
      raw = null;
      parsedFromJSON = false;
    }
  }

  const defaultTitles = mode === "purpose"
    ? ["Your drivers", "Your tension", "First direction"]
    : (mode === "fulfillment"
      ? ["Fulfillment areas", "Next direction"]
      : ["Root cause", "Fulfillment areas", "Next direction"]);
  const targetCardCount = defaultTitles.length;
  const hasPersonalization = !!(context?.personalization?.current) && !needsPersonalizationNudge;
  const defaultBodies = mode === "purpose"
    ? [
      "Your purpose direction points to progress and steadier control under pressure.",
      "Ambition and bandwidth are currently in tension, so narrowing focus matters.",
      "Choose one high-leverage next move that lowers stress and keeps momentum."
    ]
    : (mode === "fulfillment"
      ? defaultFulfillmentOnboardingInsightBodies(context, hasPersonalization)
      : defaultDiagnosticsInsightBodies(context, hasPersonalization));

  const sourceCards = Array.isArray(raw?.cards)
    ? raw.cards
    : (Array.isArray(raw?.insights) ? raw.insights : []);
  const bodyCandidates = sourceCards
    .map((item) => extractOnboardingInsightBody(item))
    .filter(Boolean)
    .slice(0, targetCardCount);

  while (bodyCandidates.length < targetCardCount) bodyCandidates.push(defaultBodies[bodyCandidates.length]);
  const normalizedBodies = mode === "diagnostics"
    ? normalizeDiagnosticsInsightBodies(bodyCandidates, context, hasPersonalization, defaultBodies)
    : (mode === "fulfillment"
      ? normalizeFulfillmentOnboardingInsightBodies(bodyCandidates, context, hasPersonalization, defaultBodies)
      : bodyCandidates);

  const cards = defaultTitles.map((title, idx) => ({
    title,
    body: truncateAtWordBoundary(
      String(normalizedBodies[idx] || defaultBodies[idx]).replace(/\s+/g, " ").trim(),
      mode === "diagnostics" ? 420 : 280
    ),
  }));
  const finalCards = mode === "fulfillment"
    ? sanitizeFulfillmentOnboardingCards(cards, context, defaultBodies)
    : cards;

  const confidenceRaw = typeof raw?.confidence === "string" ? raw.confidence.toLowerCase().trim() : "";
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : (parsedFromJSON ? "medium" : "low");
  let nudge = typeof raw?.nudge === "string"
    ? truncateAtWordBoundary(String(raw.nudge).replace(/\s+/g, " ").trim(), 180)
    : "";
  if (needsPersonalizationNudge && !nudge) {
    nudge = mode === "diagnostics"
      ? "Loom doesn’t have personalization yet. Use Edit answers to complete Quick diagnostic."
      : (mode === "fulfillment"
        ? "Add diagnostic in Personalization for stronger Loom guidance."
        : "Complete Account -> Personalization for sharper Loom-specific insights.");
  }

  const debug = raw?.debug && typeof raw.debug === "object" ? raw.debug : null;
  return {
    cards: finalCards,
    confidence,
    nudge: nudge || null,
    debug,
  };
}

function defaultDiagnosticsInsightBodies(context, hasPersonalization) {
  const current = context?.personalization?.current;
  if (!hasPersonalization || !current || typeof current !== "object") {
    return [
      "Loom doesn’t have your personalization yet. Use Edit answers to set your stress source and break point.",
      "Loom doesn’t have your selected life areas yet. Use Edit answers so Loom can organize your tasks, goals, and little wins.",
      "Loom can’t personalize your Next direction yet. Use Edit answers so Loom can tune your guidance."
    ];
  }

  return [
    buildImplicitRootCauseBody(current),
    "Every task, goal, and little win will land in one of these areas, so your life stays organized.",
    buildImplicitNextDirectionBody(current)
  ];
}

function defaultFulfillmentOnboardingInsightBodies(context, hasPersonalization) {
  const categoryCount = fulfillmentCategoryCountFromContext(context);
  const hasCountSignal = Number.isFinite(categoryCount) && categoryCount > 0;
  let categoryHint = "";
  if (hasCountSignal && categoryCount < 3) {
    categoryHint = "You may need a few more areas to get full life coverage; aim for 3-7.";
  } else if (hasCountSignal && categoryCount > 7) {
    categoryHint = "You may have too many areas to stay clear; aim for 3-7.";
  }

  const current = context?.personalization?.current || {};
  const stress = sanitizePersonalizationField(current?.stressSource, 120);
  const planning = sanitizePersonalizationField(current?.planningReality, 120);
  const desired = sanitizePersonalizationField(current?.desiredChange, 120);
  const purposeSignal =
    sanitizePersonalizationField(context?.drivingForce?.purpose, 140) ||
    sanitizePersonalizationField(context?.drivingForce?.vision, 140) ||
    sanitizePersonalizationField(context?.purposeDraft?.purpose, 140) ||
    sanitizePersonalizationField(context?.purposeDraft?.vision, 140) ||
    "";

  const hasDiagnosticSignal = !!(stress || planning || desired);
  const hasPurposeSignal = !!purposeSignal;

  const areasPrefix = hasDiagnosticSignal && hasPurposeSignal
    ? `Given your aim for ${lowerFirstToken(desired || "steadier progress", "steadier progress")} and the direction in your Purpose,`
    : (hasDiagnosticSignal
      ? `Given your current pressure around ${lowerFirstToken(stress || "competing priorities", "competing priorities")},`
      : (hasPurposeSignal
        ? "Given the direction in your Purpose,"
        : "I don't have full Purpose or diagnostic context yet, so this is a baseline:"));

  const areasBody = [
    `${areasPrefix} a well-rounded setup keeps coverage broad enough to reduce blind spots without creating overload.`,
    "Loom uses fulfillment areas as a stable operating map so daily actions stay connected to long-term direction.",
    categoryHint
  ]
    .filter(Boolean)
    .join(" ");

  let nextDirection = "";
  if (!hasDiagnosticSignal && !hasPurposeSignal) {
    nextDirection = [
      "We'll start with a conservative focus rhythm until more personalization signal is available.",
      "Loom will help you reduce overwhelm by narrowing priorities and keeping follow-through consistent."
    ].join(" ");
  } else if (/\breactive\b|\bdrift\b|\bbehind\b|\burgent\b|\bchaotic\b|\bfirefight\b|\boverwhelmed\b/.test((planning || "").toLowerCase())) {
    nextDirection = [
      "We'll shorten your planning horizon and tighten priority count so execution feels more predictable.",
      "Loom will help you maintain steadier momentum with simpler weekly decisions."
    ].join(" ");
  } else if (desired) {
    nextDirection = [
      `We'll align your execution rhythm toward ${lowerFirstToken(desired, "clearer progress")} with fewer competing priorities.`,
      "Loom will help you sustain momentum without overload as priorities shift."
    ].join(" ");
  } else {
    nextDirection = [
      "We'll keep planning directionally clear and reduce unnecessary priority switching.",
      "Loom will help you stay consistent with fewer decisions and steadier follow-through."
    ].join(" ");
  }

  return [
    clampInsightBody(areasBody, 3),
    ensureFulfillmentNextDirectionEnding(nextDirection)
  ];
}

function normalizeFulfillmentOnboardingInsightBodies(candidates, context, hasPersonalization, defaultBodies) {
  const knownCategoryNames = extractKnownFulfillmentCategoryNames(context);
  const safeAreasFallback = defaultBodies[0];
  const out = [0, 1].map((idx) => {
    const raw = String(candidates[idx] || defaultBodies[idx] || "")
      .replace(/\s+/g, " ")
      .trim();
    if (!raw) return defaultBodies[idx];
    if (/you selected/i.test(raw) || /you chose/i.test(raw)) {
      return idx === 0 ? safeAreasFallback : defaultBodies[idx];
    }
    const hasCategoryParroting = containsAnyCategoryName(raw, knownCategoryNames);
    if (hasCategoryParroting) {
      return idx === 0 ? safeAreasFallback : defaultBodies[idx];
    }
    if (idx === 1) {
      return ensureFulfillmentNextDirectionEnding(clampInsightBody(raw, 3));
    }
    return clampInsightBody(raw, 3);
  });

  if (!hasPersonalization && !hasAnyPurposeSignal(context)) {
    out[0] = defaultBodies[0];
    out[1] = ensureFulfillmentNextDirectionEnding(defaultBodies[1]);
  } else {
    out[1] = ensureFulfillmentNextDirectionEnding(out[1]);
  }

  return out;
}

function sanitizeFulfillmentOnboardingCards(cards, context, defaultBodies) {
  const input = Array.isArray(cards) ? cards.slice(0, 2) : [];
  if (input.length < 2) {
    return [
      { title: "Fulfillment areas", body: defaultBodies[0] },
      { title: "Next direction", body: ensureFulfillmentNextDirectionEnding(defaultBodies[1]) }
    ];
  }

  const names = extractKnownFulfillmentCategoryNames(context);
  const areaRaw = String(input[0]?.body || "").replace(/\s+/g, " ").trim();
  const nextRaw = String(input[1]?.body || "").replace(/\s+/g, " ").trim();
  const hasParroting =
    /you selected/i.test(areaRaw) ||
    /you selected/i.test(nextRaw) ||
    countCategoryNameMatches(areaRaw, names) >= 2 ||
    countCategoryNameMatches(nextRaw, names) >= 2;

  if (!hasParroting) {
    return [
      { title: "Fulfillment areas", body: clampInsightBody(areaRaw || defaultBodies[0], 3) },
      { title: "Next direction", body: ensureFulfillmentNextDirectionEnding(nextRaw || defaultBodies[1]) }
    ];
  }

  return [
    {
      title: "Fulfillment areas",
      body: "Your areas are set. Next we'll use them to organize tasks, goals, and little wins into one direction."
    },
    {
      title: "Next direction",
      body: ensureFulfillmentNextDirectionEnding(defaultBodies[1])
    }
  ];
}

function countCategoryNameMatches(text, names) {
  if (!Array.isArray(names) || names.length === 0) return 0;
  const lower = String(text || "").toLowerCase();
  let count = 0;
  for (const name of names) {
    if (typeof name !== "string" || !name) continue;
    if (lower.includes(name.toLowerCase())) count += 1;
  }
  return count;
}

function hasAnyPurposeSignal(context) {
  return !!(
    sanitizePersonalizationField(context?.drivingForce?.vision, 120) ||
    sanitizePersonalizationField(context?.drivingForce?.purpose, 120) ||
    sanitizePersonalizationField(context?.purposeDraft?.vision, 120) ||
    sanitizePersonalizationField(context?.purposeDraft?.purpose, 120)
  );
}

function ensureFulfillmentNextDirectionEnding(text) {
  const source = String(text || "").replace(/\s+/g, " ").trim();
  if (!source) {
    return "We'll keep your priorities focused and sequencing clear as inputs evolve. Loom will help you reduce overwhelm with steadier follow-through.";
  }

  const rawSentences = splitIntoSentences(source)
    .map((sentence) => sentence.replace(/[.!?]+$/g, "").trim())
    .filter(Boolean);
  let sentences = rawSentences.length > 0 ? rawSentences : [source.replace(/[.!?]+$/g, "").trim()];

  if (sentences.length > 3) {
    const last = sentences[sentences.length - 1];
    sentences = sentences.slice(0, 2);
    sentences.push(last);
  }

  const loomIdx = sentences.findIndex((sentence) => /^loom will help you\b/i.test(sentence));
  if (loomIdx >= 0) {
    const loomSentence = sentences.splice(loomIdx, 1)[0];
    sentences.push(loomSentence);
  } else {
    sentences.push("Loom will help you stay focused on fewer priorities with steadier follow-through");
  }

  if (sentences.length > 3) {
    const last = sentences[sentences.length - 1];
    sentences = sentences.slice(0, 2);
    sentences.push(last);
  }

  const normalized = sentences
    .map((sentence) => sentence.endsWith(".") ? sentence : `${sentence}.`)
    .join(" ");
  return truncateAtWordBoundary(normalized, 360);
}

function clampInsightBody(text, maxSentences = 3) {
  const source = String(text || "").trim();
  if (!source) return "";
  const chunks = source.match(/[^.!?]+[.!?]?/g) || [source];
  const kept = chunks
    .map((chunk) => chunk.trim())
    .filter(Boolean)
    .slice(0, maxSentences)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
  return truncateAtWordBoundary(kept, 340);
}

function fulfillmentCategoryCountFromContext(context) {
  const setup = context?.fulfillmentSetup;
  if (Number.isFinite(setup?.categoryCount)) return Number(setup.categoryCount);
  if (Array.isArray(setup?.selectedCategoryIDs)) return setup.selectedCategoryIDs.length;
  if (Array.isArray(setup?.selectedCategoryNames)) return setup.selectedCategoryNames.length;
  if (Array.isArray(context?.fulfillmentCategories)) return context.fulfillmentCategories.length;
  return 0;
}

function firstMissingFulfillmentDiagnosticQuestion(current) {
  const stress = sanitizePersonalizationField(current?.stressSource, 120);
  if (!stress) return "What creates the most stress right now?";
  const breakPoint = sanitizePersonalizationField(current?.breakPoint, 120);
  if (!breakPoint) return "What usually breaks first when stress spikes?";
  const planning = sanitizePersonalizationField(current?.planningReality, 120);
  if (!planning) return "How does your planning usually drift off track?";
  const desired = sanitizePersonalizationField(current?.desiredChange, 120);
  if (!desired) return "What change would help you feel more in control first?";
  return "What usually breaks first when stress spikes?";
}

function extractKnownFulfillmentCategoryNames(context) {
  const names = [];
  const setupNames = Array.isArray(context?.fulfillmentSetup?.selectedCategoryNames)
    ? context.fulfillmentSetup.selectedCategoryNames
    : [];
  const categoryNames = Array.isArray(context?.fulfillmentCategories)
    ? context.fulfillmentCategories.map((item) => item?.name)
    : [];
  for (const value of [...setupNames, ...categoryNames]) {
    if (typeof value !== "string") continue;
    const trimmed = value.trim();
    if (!trimmed) continue;
    names.push(trimmed.toLowerCase());
  }
  return Array.from(new Set(names)).slice(0, 20);
}

function containsAnyCategoryName(text, names) {
  if (!Array.isArray(names) || names.length < 1) return false;
  const lower = String(text || "").toLowerCase();
  return names.some((name) => typeof name === "string" && name && lower.includes(name));
}

function buildImplicitRootCauseBody(current) {
  const stress = lowerFirstToken(
    sanitizePersonalizationField(current?.stressSource, 120),
    "competing priorities stack up"
  );
  const breakPoint = lowerFirstToken(
    sanitizePersonalizationField(current?.breakPoint, 120),
    "follow-through starts to slip"
  );
  return `Pressure builds when ${stress}, and momentum tends to break at ${breakPoint}. Loom will steady progress by narrowing focus and simplifying decisions.`;
}

function buildImplicitNextDirectionBody(current) {
  const desired = sanitizePersonalizationField(current?.desiredChange, 120).toLowerCase();
  const planning = sanitizePersonalizationField(current?.planningReality, 120).toLowerCase();
  const stress = sanitizePersonalizationField(current?.stressSource, 120).toLowerCase();
  const signal = `${desired} ${planning} ${stress}`;

  if (/\bbalance\b|\baligned\b|\balignment\b|\bharmony\b/.test(signal)) {
    return "Loom will align your priorities into a steadier rhythm, so progress stays sustainable. You’ll move forward with clearer focus, less overwhelm, and stronger long-term momentum.";
  }
  if (/\bconsistent\b|\bconsistency\b|\broutine\b|\bfollow\b|\breliable\b/.test(signal)) {
    return "Loom will keep your priorities focused and repeatable, so follow-through stays steady. You’ll build reliable momentum with less friction and clearer direction.";
  }
  if (/\bcontrol\b|\bclarity\b|\borganized\b|\bstructure\b|\bfocus\b/.test(signal)) {
    return "Loom will simplify your planning into clearer priorities, so decisions feel lighter. You’ll move forward with steady focus, less overwhelm, and stronger control.";
  }
  return "Loom will narrow your priorities and keep execution consistent, so progress compounds. You’ll build reliable momentum with less overwhelm and clearer focus.";
}

function normalizeDiagnosticsInsightBodies(candidates, context, hasPersonalization, defaultBodies) {
  if (!hasPersonalization) return defaultBodies;

  const current = context?.personalization?.current || {};
  const stress = sanitizePersonalizationField(current?.stressSource, 120);
  const breakPoint = sanitizePersonalizationField(current?.breakPoint, 120);

  const rootCandidate = String(candidates[0] || "")
    .replace(/\s+/g, " ")
    .trim();
  const rootSentences = splitIntoSentences(rootCandidate);
  const rootText = rootSentences.slice(0, 2).join(" ");
  const rootBody =
    rootCandidate &&
    rootSentences.length >= 1 &&
    rootSentences.length <= 2 &&
    countWords(rootText) <= 55 &&
    includesPersonalizationReference(rootCandidate, stress) &&
    includesPersonalizationReference(rootCandidate, breakPoint) &&
    !hasQuoteStyleRootCauseLanguage(rootCandidate) &&
    !containsDiagnosticsRestatementLanguage(rootCandidate)
      ? rootText
      : defaultBodies[0];

  const nextDirectionCandidate = String(candidates[2] || "")
    .replace(/\bGoal:\s*/gi, "")
    .replace(/\s+/g, " ")
    .trim();
  const nextDirectionSentences = splitIntoSentences(nextDirectionCandidate);
  const hasWeekLanguage = /\bthis week\b/i.test(nextDirectionCandidate);
  const nextDirectionText = nextDirectionSentences.slice(0, 2).join(" ");
  const nextDirectionBody =
    nextDirectionCandidate &&
    !hasWeekLanguage &&
    nextDirectionSentences.length >= 1 &&
    nextDirectionSentences.length <= 2 &&
    countWords(nextDirectionText) <= 40 &&
    hasDirectionalLanguage(nextDirectionCandidate) &&
    !hasTaskInstructionLanguage(nextDirectionCandidate) &&
    !hasOnboardingActionLanguage(nextDirectionCandidate) &&
    !repeatsDiagnosticsRootCauseLanguage(nextDirectionCandidate) &&
    !containsDiagnosticsRestatementLanguage(nextDirectionCandidate) &&
    !hasGenericProductivityAdviceLanguage(nextDirectionCandidate)
      ? nextDirectionText
      : defaultBodies[2];

  return [
    rootBody,
    "Every task, goal, and little win will land in one of these areas, so your life stays organized.",
    nextDirectionBody
  ];
}

function splitIntoSentences(text) {
  return String(text || "")
    .split(/[.!?]+\s+/)
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => `${part}.`);
}

function includesPersonalizationReference(text, rawValue) {
  const value = String(rawValue || "").toLowerCase().trim();
  if (!value) return false;
  const haystack = String(text || "").toLowerCase();
  if (haystack.includes(value)) return true;
  const tokens = value
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .map((token) => token.trim())
    .filter(Boolean)
    .filter((token) => token.length > 4)
    .slice(0, 6);
  return tokens.some((token) => haystack.includes(token));
}

function countWords(text) {
  return String(text || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
}

function hasDirectionalLanguage(text) {
  const lower = String(text || "").toLowerCase();
  const tokens = [
    "we'll", "we will", "you'll", "you will",
    "focus", "consistent", "consistency", "momentum",
    "overwhelm", "clarity", "priority", "priorities",
    "steady", "direction", "simpler"
  ];
  return tokens.some((token) => lower.includes(token));
}

function containsDiagnosticsRestatementLanguage(text) {
  const lower = String(text || "").toLowerCase();
  const fragments = [
    "your current planning pattern",
    "you selected",
    "this means",
    "stress source",
    "break point",
    "planning style",
    "desired change",
    "life areas"
  ];
  return fragments.some((fragment) => lower.includes(fragment));
}

function hasQuoteStyleRootCauseLanguage(text) {
  const raw = String(text || "");
  const lower = raw.toLowerCase();
  if (/\byou said\b/.test(lower) || /\byou selected\b/.test(lower)) return true;
  return /["“”]/u.test(raw);
}

function hasGenericProductivityAdviceLanguage(text) {
  const lower = String(text || "").toLowerCase();
  const fragments = [
    "productivity",
    "optimize",
    "efficiency",
    "hack",
    "time management",
    "maximize output"
  ];
  return fragments.some((fragment) => lower.includes(fragment));
}

function hasTaskInstructionLanguage(text) {
  const lower = String(text || "").toLowerCase();
  const patterns = [
    /\bstart by\b/,
    /\bstart now\b/,
    /\bdo this today\b/,
    /\bdo this now\b/,
    /\btry\b/,
    /\bopen\s+\w+/,
    /\btap\s+\w+/,
    /\badd\s+(one|a)\b/,
    /\bcreate\s+(one|a)\b/,
    /\bset up\b/,
    /\bchoose\s+(one|a)\b/,
  ];
  return patterns.some((pattern) => pattern.test(lower));
}

function lowerFirstToken(value, fallback) {
  const trimmed = String(value || "").trim();
  if (!trimmed) return fallback;
  if (trimmed.length === 1) return trimmed.toLowerCase();
  return `${trimmed[0].toLowerCase()}${trimmed.slice(1)}`;
}

function sanitizeClientDebugValue(value, maxLen = 128) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return truncateAtWordBoundary(trimmed, Math.max(16, maxLen));
}

function hasOnboardingActionLanguage(text) {
  const lower = String(text || "").toLowerCase();
  const patterns = [
    /\bedit answers\b/,
    /\bsave your responses\b/,
    /\bcustomize\b/,
    /\bchange settings\b/,
    /\bupdate\b/,
  ];
  return patterns.some((pattern) => pattern.test(lower));
}

function repeatsDiagnosticsRootCauseLanguage(text) {
  const lower = String(text || "").toLowerCase();
  const fragments = [
    "stress is mainly",
    "you said stress",
    "progress breaks",
    "breaks at",
  ];
  return fragments.some((fragment) => lower.includes(fragment));
}

function extractOnboardingInsightBody(item) {
  if (typeof item === "string") {
    return String(item).replace(/\s+/g, " ").trim();
  }
  if (!item || typeof item !== "object") return "";
  const bodyRaw = item.body || item.message || item.text || item.value || "";
  return String(bodyRaw).replace(/\s+/g, " ").trim();
}

function buildOnboardingInsightsEvidence(mode, context, hasPersonalization) {
  const evidence = [];
  if (hasPersonalization && context?.personalization?.current) {
    if (typeof context.personalization.current.stressSource === "string") {
      evidence.push("personalization.current.stressSource");
    }
    if (typeof context.personalization.current.breakPoint === "string") {
      evidence.push("personalization.current.breakPoint");
    }
    if (typeof context.personalization.current.planningReality === "string") {
      evidence.push("personalization.current.planningReality");
    }
    if (Array.isArray(context.personalization.current.lifeAreasSelected)) {
      evidence.push("personalization.current.lifeAreasSelected");
    }
  }

  if (mode === "purpose") {
    if (typeof context?.drivingForce?.vision === "string") {
      evidence.push("drivingForce.vision");
    }
    if (typeof context?.drivingForce?.purpose === "string") {
      evidence.push("drivingForce.purpose");
    }
    if (Array.isArray(context?.drivingForce?.passions)) {
      evidence.push("drivingForce.passions");
    }
    if (typeof context?.purposeDraft?.vision === "string") {
      evidence.push("purposeDraft.vision");
    }
  } else {
    if (Array.isArray(context?.fulfillmentCategories)) {
      evidence.push("fulfillmentCategories");
    }
    if (Array.isArray(context?.fulfillmentSetup?.selectedCategoryNames)) {
      evidence.push("fulfillmentSetup.selectedCategoryNames");
    }
    if (Array.isArray(context?.fulfillmentSetup?.focusCategoryNames)) {
      evidence.push("fulfillmentSetup.focusCategoryNames");
    }
  }

  if (Array.isArray(context?.dataInventory) && context.dataInventory.length > 0) {
    evidence.push("dataInventory");
  }

  return evidence.slice(0, 8);
}

function ensureDiagnosticsInsightsEvidencePaths(evidence, context, hasPersonalization) {
  const out = Array.isArray(evidence)
    ? evidence.filter((item) => typeof item === "string" && item.trim().length > 0)
    : [];
  if (!hasPersonalization || !context?.personalization?.current) {
    return out.slice(0, 20);
  }

  const required = [];
  if (typeof context.personalization.current.stressSource === "string") {
    required.push("personalization.current.stressSource");
  }
  if (typeof context.personalization.current.breakPoint === "string") {
    required.push("personalization.current.breakPoint");
  }
  if (Array.isArray(context.personalization.current.lifeAreasSelected)) {
    required.push("personalization.current.lifeAreasSelected");
  }

  for (const path of required) {
    if (!out.includes(path)) out.push(path);
  }
  return out.slice(0, 20);
}

function ensureFulfillmentInsightsEvidencePaths(evidence, context, hasPersonalization) {
  const out = Array.isArray(evidence)
    ? evidence.filter((item) => typeof item === "string" && item.trim().length > 0)
    : [];
  const current = context?.personalization?.current;
  const required = [];
  if (hasPersonalization && current && typeof current === "object") {
    if (typeof current.stressSource === "string") {
      required.push("personalization.current.stressSource");
    }
    if (typeof current.breakPoint === "string") {
      required.push("personalization.current.breakPoint");
    }
    if (typeof current.planningReality === "string") {
      required.push("personalization.current.planningReality");
    }
    if (typeof current.desiredChange === "string") {
      required.push("personalization.current.desiredChange");
    }
  }

  if (typeof context?.drivingForce?.purpose === "string") {
    required.push("drivingForce.purpose");
  } else if (typeof context?.drivingForce?.vision === "string") {
    required.push("drivingForce.vision");
  } else if (typeof context?.purposeDraft?.purpose === "string") {
    required.push("purposeDraft.purpose");
  } else if (typeof context?.purposeDraft?.vision === "string") {
    required.push("purposeDraft.vision");
  }

  if (Array.isArray(context?.fulfillmentSetup?.selectedCategoryIDs)) {
    required.push("fulfillmentSetup.selectedCategoryIDs");
  }

  for (const path of required) {
    if (!out.includes(path)) out.push(path);
  }

  if (out.length === 0 && Array.isArray(context?.dataInventory) && context.dataInventory.length > 0) {
    out.push("dataInventory");
  }
  return out.slice(0, 20);
}

function extractReadableInsightPayload(nonSystemMessages, mode) {
  const marker = mode === "purpose"
    ? "Purpose passion insight payload JSON:"
    : "Fulfillment insight payload JSON:";
  const content = Array.isArray(nonSystemMessages)
    ? nonSystemMessages.map((m) => String(m?.content || "")).join("\n\n")
    : "";
  const markerIndex = content.lastIndexOf(marker);
  if (markerIndex < 0) return null;
  const tail = content.slice(markerIndex + marker.length);
  const objectText = extractFirstJSONObjectText(tail);
  if (!objectText) return null;
  try {
    const parsed = JSON.parse(objectText);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

function extractFirstJSONObjectText(value) {
  const s = String(value || "");
  const start = s.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < s.length; i += 1) {
    const ch = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{") {
      depth += 1;
      continue;
    }
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return s.slice(start, i + 1);
      }
    }
  }
  return null;
}

function isSingleRecordReadableInsightPayload(payload, mode) {
  if (!payload || typeof payload !== "object") return false;
  const series = mode === "purpose" ? payload?.recentScores : payload?.recentCategoryScores;
  return Array.isArray(series) && series.length <= 1;
}

function clamp01(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

function baselineReadableInsightLines(mode, payload) {
  if (mode === "purpose") {
    const scored = [
      ["Action Blocks", clamp01(payload?.actionBlocks)],
      ["Little Wins", clamp01(payload?.littleWins)],
      ["Evidence", clamp01(payload?.evidence)],
      ["Structure", clamp01(payload?.structure)],
      ["Outcomes", clamp01(payload?.outcomes)]
    ].sort((a, b) => a[1] - b[1]);
    const weakest = scored[0]?.[0] || "Action Blocks";
    const line1 = `Baseline month only: trend and mover signals are not established yet; score gains depend on strengthening ${weakest}.`;
    let line2 = "Add one Action Block and one Little Win tied to this passion.";
    if (weakest === "Action Blocks") line2 = "Add one small Action Block tied to this passion this week.";
    if (weakest === "Little Wins") line2 = "Add one repeatable Little Win tied to this passion and complete it daily.";
    if (weakest === "Evidence") line2 = "Tag one completed action to this passion to build evidence.";
    if (weakest === "Structure") line2 = "Refine this passion wording to make it clearer and more specific.";
    if (weakest === "Outcomes") line2 = "Connect one Outcome that directly supports this passion.";
    return { line1, line2 };
  }

  const scored = [
    ["Action Blocks", clamp01(payload?.actionBlocks)],
    ["Little Wins", clamp01(payload?.littleWins)],
    ["Engagement", clamp01(payload?.engagement)],
    ["Strategic Behavior", clamp01(payload?.strategicBehavior)],
    ["Structure", clamp01(payload?.structure)],
    ["Outcomes", clamp01(payload?.outcomes)]
  ].sort((a, b) => a[1] - b[1]);
  const weakest = scored[0]?.[0] || "Action Blocks";
  const line1 = `Baseline week only: trend and mover signals are not established yet; score gains depend on improving ${weakest} consistency.`;
  let line2 = "Complete one Action Block and one Little Win in this area this week.";
  if (weakest === "Action Blocks") line2 = "Complete one realistic Action Block in this area today.";
  if (weakest === "Little Wins") line2 = "Complete one Little Win in this area each day this week.";
  if (weakest === "Engagement") line2 = "Do one small task in this area every day this week.";
  if (weakest === "Strategic Behavior") line2 = "Revise Mission or Identity so this area guides daily choices.";
  if (weakest === "Structure") line2 = "Clarify Mission and Identity for this area before adding more tasks.";
  if (weakest === "Outcomes") line2 = "Connect one Outcome for this area and review it this week.";
  return { line1, line2 };
}

function ensureTerminalSentence(value) {
  const s = String(value || "").trim();
  if (!s) return "";
  return /[.!?]$/.test(s) ? s : `${s}.`;
}

function normalizeReadableInsightMessage(message, options = {}) {
  const mode = options?.mode === "purpose" ? "purpose" : "fulfillment";
  const payload = options?.payload && typeof options.payload === "object" ? options.payload : null;
  const baseline = baselineReadableInsightLines(mode, payload);
  const isSingleRecord = isSingleRecordReadableInsightPayload(payload, mode);

  const text = String(message || "")
    .replace(/\r\n/g, "\n")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  const lines = text
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);

  let line1 = lines[0] || baseline.line1;
  let line2 = lines[1] || baseline.line2;

  if (isSingleRecord) {
    line1 = baseline.line1;
    line2 = baseline.line2;
  }

  line1 = line1
    .replace(/^during (this|the) (loom )?(fulfillment area|purpose passion) (week|month|insights?)[:,]?\s*/i, "")
    .replace(/^during this (week|month)[:,]?\s*/i, "")
    .replace(/^a total of\s+/i, "")
    .trim();
  line1 = ensureTerminalSentence(truncateAtWordBoundary(line1 || baseline.line1, 170));

  line2 = line2
    .replace(/^in loom,\s*/i, "")
    .replace(/^in loom\s*/i, "")
    .replace(/^action block\b/i, "Action Blocks")
    .trim();
  line2 = ensureTerminalSentence(truncateAtWordBoundary(line2 || baseline.line2, 120));

  let combined = `${line1}\n\n${line2}`;
  if (combined.length <= 220) return combined;

  line1 = ensureTerminalSentence(truncateAtWordBoundary(line1, 130));
  line2 = ensureTerminalSentence(truncateAtWordBoundary(line2, 80));
  combined = `${line1}\n\n${line2}`;
  if (combined.length <= 220) return combined;

  const maxLine2 = Math.max(30, 220 - (line1.length + 2));
  line2 = ensureTerminalSentence(truncateAtWordBoundary(line2, maxLine2));
  combined = `${line1}\n\n${line2}`;
  if (combined.length <= 220) return combined;

  const maxLine1 = Math.max(60, 220 - (line2.length + 2));
  line1 = ensureTerminalSentence(truncateAtWordBoundary(line1, maxLine1));
  return `${line1}\n\n${line2}`;
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

function normalizeIdentityAutoWriteText(value) {
  const cleaned = String(value || "").replace(/\s+/g, " ").trim();
  if (!cleaned) return "";
  const words = cleaned.split(/\s+/).filter(Boolean).slice(0, 3).join(" ");
  return truncateAtWordBoundary(words, 40);
}

function normalizeLittleWinAutoWriteText(value) {
  const cleaned = String(value || "").replace(/\s+/g, " ").trim();
  if (!cleaned) return "";
  const words = cleaned.split(/\s+/).filter(Boolean).slice(0, 7).join(" ");
  return truncateAtWordBoundary(words, 80);
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

function buildPersonalizationContext(context) {
  const current = context?.personalization?.current;
  const recentChangesRaw = Array.isArray(context?.personalization?.recentChanges)
    ? context.personalization.recentChanges
    : [];
  const recentChanges = recentChangesRaw
    .filter((item) => typeof item === "string")
    .map((item) => truncate(item.trim(), 160))
    .filter(Boolean)
    .slice(0, 3);

  if (!current || typeof current !== "object") {
    return {
      hasCurrent: false,
      text: "Diagnostic personalization context unavailable.",
    };
  }

  const stress = sanitizePersonalizationField(current.stressSource, 140);
  const breakPoint = sanitizePersonalizationField(current.breakPoint, 140);
  const planning = sanitizePersonalizationField(current.planningReality, 140);
  const desiredChange = sanitizePersonalizationField(current.desiredChange, 140);
  const lifeAreas = Array.isArray(current.lifeAreasSelected)
    ? current.lifeAreasSelected
      .filter((item) => typeof item === "string")
      .map((item) => sanitizePersonalizationField(item, 60))
      .filter(Boolean)
      .slice(0, 7)
    : [];
  const changesText = recentChanges.length > 0
    ? recentChanges.join(" | ")
    : "No recent changes.";

  return {
    hasCurrent: true,
    text: `User personalization (current): Stress=${stress || "n/a"}, Breakpoint=${breakPoint || "n/a"}, Planning=${planning || "n/a"}, DesiredChange=${desiredChange || "n/a"}, LifeAreas=[${lifeAreas.join(", ")}]. Recent changes: ${changesText}`,
  };
}

function sanitizePersonalizationField(value, maxLen = 120) {
  return truncate(
    String(value || "")
      .replace(/\s+/g, " ")
      .trim(),
    maxLen
  );
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
