const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_CHAT_MODEL = "gpt-5.2";
const DIAGNOSTIC_CACHE_TTL_SECONDS = 60 * 60 * 24 * 14; // 14 days
const CHAT_CACHE_TTL_SECONDS = 60 * 10; // 10 minutes
const PURPOSE_PROFILE_CATALOG = [
  {
    profile: "Strategic Integrator",
    strength: "Translates ambitious direction into shared structure others can execute.",
    weakness: "Over-integration risk; excessive synthesis and stakeholder harmony can slow decisive tradeoffs.",
    stressTrigger: "Competing stakeholder priorities",
    breakingPoint: "Decision velocity (alignment continues past usefulness)"
  },
  {
    profile: "Structured Clarity Driver",
    strength: "Forces clarity early and turns fuzzy ideas into sharp priorities and standards.",
    weakness: "May prematurely close exploration and create resistance if others feel bulldozed.",
    stressTrigger: "Ambiguity and slow consensus",
    breakingPoint: "Interpersonal smoothness (communication becomes blunt)"
  },
  {
    profile: "Adaptive Catalyst",
    strength: "Generates momentum through experimentation and social energy.",
    weakness: "Follow-through can weaken when novelty fades without external structure.",
    stressTrigger: "Rigid plans and gatekeeping",
    breakingPoint: "Execution consistency (many starts, uneven finishes)"
  },
  {
    profile: "Rapid Experimenter",
    strength: "Challenges assumptions quickly and converts uncertainty into data through action.",
    weakness: "Can create churn if direction changes too frequently.",
    stressTrigger: "Slow decision cycles",
    breakingPoint: "Context continuity (frequent pivots disrupt shared direction)"
  },
  {
    profile: "Momentum Builder",
    strength: "Builds sustainable cadence through clear plans and human buy-in.",
    weakness: "May prioritize feasibility over bold upside.",
    stressTrigger: "Resource constraints and morale dips",
    breakingPoint: "Ambition (scope narrows to maintain stability)"
  },
  {
    profile: "Operational Commander",
    strength: "Executes effectively under constraints; prioritizes, assigns, and enforces standards.",
    weakness: "Relationship debt accumulates if pressure becomes constant critique.",
    stressTrigger: "Missed commitments",
    breakingPoint: "Patience (tolerance for variance collapses)"
  },
  {
    profile: "Adaptive Stabilizer",
    strength: "Maintains progress when conditions shift through flexible coordination.",
    weakness: "Absorbs too much responsibility and becomes an informal buffer.",
    stressTrigger: "Last-minute changes and interpersonal conflict",
    breakingPoint: "Boundary clarity (over-commitment reduces consistency)"
  },
  {
    profile: "Crisis Navigator",
    strength: "Cuts through noise during chaos with strong triage and improvisation.",
    weakness: "Long-term systems may be neglected; urgency becomes the default mode.",
    stressTrigger: "Bureaucracy and slow escalation paths",
    breakingPoint: "Long-horizon planning (defaults to firefighting)"
  },
  {
    profile: "Purpose-Led Planner",
    strength: "Maintains long-term direction through disciplined planning tied to values.",
    weakness: "Initiation friction; preparation can delay execution.",
    stressTrigger: "Noisy inputs and constant context switching",
    breakingPoint: "Start energy (stalling at launch)"
  },
  {
    profile: "Analytical Architect",
    strength: "Builds rigorous systems and frameworks that withstand scrutiny.",
    weakness: "Under-communication can create misunderstanding.",
    stressTrigger: "Sloppy reasoning or vague definitions",
    breakingPoint: "Collaboration flow (withdraws rather than translating ideas)"
  },
  {
    profile: "Reflective Synthesizer",
    strength: "Connects disparate ideas into coherent insight without seeking attention.",
    weakness: "Structure avoidance may prevent insights from becoming goals.",
    stressTrigger: "Tight deadlines and forced specificity",
    breakingPoint: "Deliverable packaging (refining replaces shipping)"
  },
  {
    profile: "Independent Pathfinder",
    strength: "Explores difficult problems autonomously with high learning velocity.",
    weakness: "Independence may create coordination costs for teams.",
    stressTrigger: "Micromanagement",
    breakingPoint: "Team predictability (disappears into solo iteration)"
  },
  {
    profile: "Steady Alignment Builder",
    strength: "Builds trust through reliability, consistency, and steady relationships.",
    weakness: "Avoids hard conversations too long to preserve harmony.",
    stressTrigger: "Interpersonal tension",
    breakingPoint: "Truth-telling (issues get smoothed over until they erupt)"
  },
  {
    profile: "Quality Sentinel",
    strength: "Protects standards and identifies risks before failure occurs.",
    weakness: "Excess scrutiny can slow progress.",
    stressTrigger: "Unclear ownership and sloppy execution",
    breakingPoint: "Speed (momentum sacrificed for certainty)"
  },
  {
    profile: "Supportive Adapter",
    strength: "Maintains stability through calm responsiveness and quiet problem solving.",
    weakness: "Becomes invisible if priorities are not self-defined.",
    stressTrigger: "Unclear expectations",
    breakingPoint: "Self-prioritization (work fragments across others' needs)"
  },
  {
    profile: "Pragmatic Realist",
    strength: "Identifies what will work now and communicates it plainly.",
    weakness: "May neglect inspiration and relationship repair.",
    stressTrigger: "Emotionally driven decisions",
    breakingPoint: "Influence (truth delivered without adoption)"
  }
];
const PURPOSE_PROFILE_NAMES = PURPOSE_PROFILE_CATALOG.map((item) => item.profile);

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);

      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders(request) });
      }

      if (url.pathname === "/purpose/vision/autowrite") {
        return await handlePurposeVisionAutowrite(request, env);
      }

      if (url.pathname === "/purpose/insights/profile") {
        return await handlePurposeInsightsProfile(request, env);
      }

      if (url.pathname === "/chat") {
        return await handleChat(request, env);
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
        required: ["rootCause", "nextDirection"]
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
      maxOutputTokens: 320,
      timeoutMs: 26000
    });
    const diagnosticUsage = normalizeResponsesUsage(result.usage, "gpt-5.1");

    let responseBody;
    if (result.error) {
      responseBody = buildDeterministicDiagnosticInsights(normalizedDiagnostic);
    } else {
      const parsed = result.json;
      const signaledInsufficient = parsed && typeof parsed.error === "string" && parsed.error.trim() !== "";
      const rootCause = normalizeInsightText(parsed?.rootCause);
      const nextDirection = normalizeInsightText(parsed?.nextDirection);
      if (signaledInsufficient || !isValidInsightText(rootCause) || !isValidInsightText(nextDirection)) {
        responseBody = buildDeterministicDiagnosticInsights(normalizedDiagnostic);
      } else {
        responseBody = { rootCause, nextDirection };
      }
    }
    if (diagnosticUsage) {
      responseBody.usage = diagnosticUsage;
    }

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
    } catch (error) {
      return json(
        {
          error: "Internal worker exception",
          details: {
            message: truncate(String(error?.message || error || "unknown_error"), 240),
            path: (() => {
              try {
                return new URL(request.url).pathname;
              } catch {
                return "";
              }
            })()
          }
        },
        500,
        corsHeaders(request)
      );
    }
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

async function handlePurposeInsightsProfile(request, env) {
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

  if (!payload || typeof payload !== "object") {
    return json({ error: "Invalid payload" }, 400, corsHeaders(request));
  }

  const validationError = validateDiagnosticPayload({ diagnostic: payload.diagnostic });
  if (validationError) {
    return json({ error: "Invalid diagnostic payload", details: validationError }, 400, corsHeaders(request));
  }

  const normalizedDiagnostic = canonicalizeDiagnostic(payload.diagnostic || {});
  const rootCause = nonEmptyString(payload.rootCause) || "";
  const nextDirection = nonEmptyString(payload.nextDirection) || "";
  const vision = nonEmptyString(payload.vision) || "";
  const passions = uniqueOrdered(
    (Array.isArray(payload.passions) ? payload.passions : [])
      .map((item) => String(item ?? "").trim())
      .filter(Boolean)
  ).slice(0, 16);
  const heuristicSeed = buildPurposeProfileHeuristicSeed({
    diagnostic: normalizedDiagnostic,
    rootCause,
    nextDirection,
    vision,
    passions
  });
  const heuristicRanking = rankPurposeProfilesHeuristically({
    diagnostic: normalizedDiagnostic,
    rootCause,
    nextDirection,
    vision,
    passions
  });
  const heuristicBest = pickPurposeProfileFromTopBand(heuristicRanking, heuristicSeed);
  const heuristicTop = heuristicRanking.slice(0, 4).map((item) => ({
    profile: item.profile,
    score: Number(item.score.toFixed(3))
  }));

  const profileCatalogPrompt = PURPOSE_PROFILE_CATALOG.map((item, index) => {
    return `${index + 1}. ${item.profile} | strength=${item.strength} | weakness=${item.weakness} | stressTrigger=${item.stressTrigger} | breakingPoint=${item.breakingPoint}`;
  }).join("\n");

  const systemPrompt = [
    "You select one Loom behavioral profile that best fits the user.",
    "Treat profile names as labels only. Do not infer fit from profile names.",
    "Start with equal prior probability for every profile.",
    "Use only these inputs: diagnostic answers, rootCause, nextDirection, vision, and passions.",
    "Compare evidence against each profile's strength, weakness, stressTrigger, and breakingPoint.",
    "Pick the closest overall fit, not a blend.",
    "Return JSON only with profile, confidence, and reason.",
    "confidence must be high, medium, or low.",
    "reason must be one short sentence under 22 words."
  ].join("\n");

  const schema = {
    name: "loom_purpose_profile_match",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        profile: { type: "string", enum: PURPOSE_PROFILE_NAMES },
        confidence: { type: "string", enum: ["high", "medium", "low"] },
        reason: { type: "string" }
      },
      required: ["profile", "confidence", "reason"]
    }
  };

  const result = await callOpenAIResponsesJSON({
    apiKey,
    model: "gpt-5-mini",
    systemPrompt,
    userPayload: {
      diagnostic: normalizedDiagnostic,
      rootCause,
      nextDirection,
      vision,
      passions,
      profileCatalog: profileCatalogPrompt,
      heuristicTopProfiles: heuristicTop
    },
    responseSchema: schema,
    maxOutputTokens: 80,
    timeoutMs: 9000,
    reasoningEffort: "low",
    allowRetry: true
  });
  const profileUsage = normalizeResponsesUsage(result.usage, "gpt-5-mini");

  if (result.error) {
    if (!heuristicBest) {
      const response = { error: result.error, details: result.details };
      if (profileUsage) {
        response.usage = profileUsage;
      }
      return json(response, result.status, corsHeaders(request));
    }
    const fallback = PURPOSE_PROFILE_CATALOG.find((item) => item.profile === heuristicBest.profile) || heuristicBest;
    const response = {
      profile: fallback.profile,
      strength: fallback.strength,
      weakness: fallback.weakness,
      stressTrigger: fallback.stressTrigger,
      breakingPoint: fallback.breakingPoint,
      debug: {
        model: "heuristic-fallback",
        confidence: "low",
        evidence: [
          "Fallback selected from ranked profile-descriptor matching.",
          `Top heuristic candidates: ${heuristicTop.map((item) => `${item.profile}(${item.score})`).join(", ")}`
        ]
      }
    };
    if (profileUsage) {
      response.usage = profileUsage;
    }
    return json(response, 200, corsHeaders(request));
  }

  const profileName = nonEmptyString(result.json?.profile);
  const modelMatched = PURPOSE_PROFILE_CATALOG.find(
    (item) => item.profile.toLowerCase() === profileName.toLowerCase()
  );
  const matched = modelMatched || (heuristicBest
    ? PURPOSE_PROFILE_CATALOG.find((item) => item.profile === heuristicBest.profile) || heuristicBest
    : null);
  if (!matched) {
    const response = { error: "Could not map profile" };
    if (profileUsage) {
      response.usage = profileUsage;
    }
    return json(response, 502, corsHeaders(request));
  }
  const modelConfidence = (nonEmptyString(result.json?.confidence) || "medium").toLowerCase();
  const modelScore = heuristicRanking.find((item) => item.profile === matched.profile)?.score ?? 0;
  const bestScore = heuristicBest?.score ?? modelScore;
  const scoreGap = bestScore - modelScore;
  const topBandProfiles = new Set(purposeProfileTopBand(heuristicRanking).map((item) => item.profile));
  const modelInTopBand = topBandProfiles.has(matched.profile);
  const shouldOverrideWithHeuristic = Boolean(
    heuristicBest &&
      heuristicBest.profile !== matched.profile &&
      (!modelInTopBand || scoreGap >= 0.85 || (modelConfidence === "low" && scoreGap >= 0.35))
  );
  const selected = shouldOverrideWithHeuristic
    ? PURPOSE_PROFILE_CATALOG.find((item) => item.profile === heuristicBest.profile) || heuristicBest
    : matched;
  const reason = truncate(String(result.json?.reason || ""), 180);
  const alignmentMessage = shouldOverrideWithHeuristic
    ? "Heuristic override applied because model selection was outside top heuristic evidence or materially lower-scoring."
    : (heuristicBest && heuristicBest.profile !== matched.profile
      ? "Model selection kept because it remained inside the top heuristic evidence band."
      : "Model selection aligned with heuristic ranking.");

  const response = {
    profile: selected.profile,
    strength: selected.strength,
    weakness: selected.weakness,
    stressTrigger: selected.stressTrigger,
    breakingPoint: selected.breakingPoint,
    debug: {
      model: shouldOverrideWithHeuristic ? "gpt-5-mini+heuristic" : "gpt-5-mini",
      confidence: shouldOverrideWithHeuristic ? "medium" : modelConfidence,
      evidence: [
        reason || "Model selected profile from catalog evidence.",
        `Top heuristic candidates: ${heuristicTop.map((item) => `${item.profile}(${item.score})`).join(", ")}`,
        alignmentMessage
      ]
    }
  };
  if (profileUsage) {
    response.usage = profileUsage;
  }
  return json(response, 200, corsHeaders(request));
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

  const intent = String(payload?.client?.intent || "").trim().toLowerCase();
  if (intent === "autogroup_plan") {
    return handleAutoGroupPlan({ request, env, apiKey, payload });
  }

  if (isPurposeVisionChatRequest(payload)) {
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

  // All non-autowrite intents use the Loom chat pipeline.
  return handleLoomAIChat({ request, env, apiKey, payload });
}

async function handleAutoGroupPlan({ request, env, apiKey, payload }) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const client = payload?.client && typeof payload.client === "object" ? payload.client : {};
  const context = compactAutoGroupContext(
    payload?.context && typeof payload.context === "object" ? payload.context : {}
  );
  const instruction = extractLatestUserMessage(payload).trim();

  const fallback = (reason) => ({
    confidence: "low",
    reason: nonEmptyString(reason) || "Could not confidently group actions.",
    groups: []
  });

  if (!instruction) {
    return json(fallback("Missing grouping instruction."), 200, corsHeaders(request));
  }

  const schema = {
    name: "autogroup_plan_response",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        confidence: { type: "string", enum: ["high", "low"] },
        reason: { type: "string" },
        groups: {
          type: "array",
          minItems: 0,
          maxItems: 8,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              name: { type: "string" },
              fulfillmentArea: { type: "string" },
              actionIDs: {
                type: "array",
                minItems: 0,
                maxItems: 25,
                items: { type: "string" }
              }
            },
            required: ["name", "fulfillmentArea", "actionIDs"]
          }
        }
      },
      required: ["confidence", "reason", "groups"]
    }
  };

  const systemPrompt = [
    "You are helping with Loom Plan Step 3 (Group).",
    "Return ONLY valid JSON matching the schema.",
    "Group actions by topical/domain similarity.",
    "Use only the provided action IDs.",
    "Never duplicate an action ID across groups.",
    "If confidence is not high, return confidence='low' and groups=[]."
  ].join("\n");

  const userPayload = {
    messages: messages.slice(-20).map((msg) => ({
      role: String(msg?.role || ""),
      content: String(msg?.content || "")
    })),
    instruction,
    capture: context.capture,
    captureItems: context.captureItems,
    client: {
      intent: nonEmptyString(client.intent) || "autogroup_plan",
      appVersion: nonEmptyString(client.appVersion) || null,
      userLocalDate: nonEmptyString(client.userLocalDate) || null,
      timezone: nonEmptyString(client.timezone) || null
    }
  };

  const preferredModel = "gpt-5-mini";
  const modelCandidates = uniqueOrdered(
    [preferredModel, nonEmptyString(env.OPENAI_MODEL), "gpt-5.1"]
      .map((value) => nonEmptyString(value))
      .filter(Boolean)
  );

  let result = null;
  let usedModel = preferredModel;
  for (const candidate of modelCandidates) {
    usedModel = candidate;
    const attempt = await callOpenAIResponsesJSON({
      apiKey,
      model: candidate,
      systemPrompt,
      userPayload,
      responseSchema: schema,
      maxOutputTokens: 800,
      timeoutMs: 26000,
      reasoningEffort: "low",
      allowRetry: true
    });
    result = attempt;
    if (!attempt?.error) break;
    const normalizedError = String(attempt.error || "").toLowerCase();
    const retryableByModel =
      normalizedError.includes("upstream model error") ||
      normalizedError.includes("invalid upstream json") ||
      normalizedError.includes("missing model output");
    if (!retryableByModel) break;
  }

  if (result?.error) {
    const response = fallback("Could not confidently group actions.");
    const usage = normalizeResponsesUsage(result.usage, usedModel || preferredModel);
    if (usage) response.usage = usage;
    return json(response, 200, corsHeaders(request));
  }

  const raw = result?.json && typeof result.json === "object" ? result.json : {};
  const confidence = String(raw.confidence || "").trim().toLowerCase() === "high" ? "high" : "low";
  const reason = truncate(
    String(raw.reason || (confidence === "high" ? "Grouped by topic." : "Could not confidently group actions.")),
    220
  );
  const groupsInput = Array.isArray(raw.groups) ? raw.groups : [];
  const seenIDs = new Set();
  const groups = [];

  for (const group of groupsInput) {
    const name = truncate(String(group?.name || "").trim(), 64);
    const fulfillmentArea = truncate(String(group?.fulfillmentArea || "").trim(), 64);
    const actionIDs = Array.isArray(group?.actionIDs)
      ? group.actionIDs
          .map((id) => String(id || "").trim())
          .filter(Boolean)
          .filter((id) => {
            if (seenIDs.has(id)) return false;
            seenIDs.add(id);
            return true;
          })
      : [];
    if (!name || actionIDs.length === 0) continue;
    groups.push({
      name,
      fulfillmentArea: fulfillmentArea || "",
      actionIDs
    });
    if (groups.length >= 8) break;
  }

  const response = {
    confidence,
    reason,
    groups: confidence === "high" ? groups : []
  };
  const usage = normalizeResponsesUsage(result.usage, usedModel);
  if (usage) response.usage = usage;
  return json(response, 200, corsHeaders(request));
}

async function handleLoomAIChat({ request, env, apiKey, payload }) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const client = payload?.client && typeof payload.client === "object" ? payload.client : {};
  const normalizedIntent = String(client.intent || "").trim().toLowerCase();
  const isAutoGroupIntent = normalizedIntent === "autogroup_plan";
  const rawContext = payload?.context && typeof payload.context === "object" ? payload.context : {};
  const context = normalizedIntent === "autogroup_plan"
    ? compactAutoGroupContext(rawContext)
    : rawContext;
  const shouldForceMiniModel = normalizedIntent === "autogroup_plan";
  const latestUserMessage = extractLatestUserMessage(payload).trim();
  const hasContext = hasMeaningfulLoomContext(context);
  const unrelatedPrompt = isLikelyUnrelatedPrompt(latestUserMessage);
  const chipIntentRoute = resolveChipIntentRoute(latestUserMessage);

  if (!latestUserMessage) {
    return json(
      safeChatFallback({
        hasContext,
        context,
        intent: normalizedIntent,
        message:
          "I’m ready to help with Loom. Ask me about Purpose, Fulfillment, Goals, Capture, or Action Blocks."
      }),
      200,
      corsHeaders(request)
    );
  }

  if (unrelatedPrompt) {
    if (isAutoGroupIntent) {
      return json(
        safeChatFallback({
          hasContext,
          context,
          intent: normalizedIntent
        }),
        200,
        corsHeaders(request)
      );
    }
    return json(
      {
        message:
          "I can’t help with that, but I can help you with Loom planning and execution right now.",
        grounding: collectGrounding([], context, { maxItems: 2 }),
        suggestionCards: [],
        nextAction: null,
        chips: buildUnrelatedRedirectChips(context),
        actions: [],
        debug: {
          usedContext: false,
          confidence: "low",
          evidence: []
        }
      },
      200,
      corsHeaders(request)
    );
  }

  const preferredModel = shouldForceMiniModel
    ? "gpt-5-mini"
    : (nonEmptyString(env.OPENAI_MODEL) || DEFAULT_CHAT_MODEL);
  const modelCandidates = shouldForceMiniModel
    ? ["gpt-5-mini"]
    : uniqueOrdered(
      [preferredModel, "gpt-5.1", "gpt-5-mini"]
        .map((value) => nonEmptyString(value))
        .filter(Boolean)
    );
  const schema = {
    name: "loom_chat_response",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        message: { type: "string" },
        grounding: {
          type: "array",
          minItems: 0,
          maxItems: 8,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              section: { type: "string" },
              field: { type: "string" },
              timestamp: { type: "string" }
            },
            required: ["section", "field", "timestamp"]
          }
        },
        suggestionCards: {
          type: "array",
          minItems: 0,
          maxItems: 6,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: "string" },
              title: { type: "string" },
              description: { type: "string" },
              options: {
                type: "array",
                minItems: 0,
                maxItems: 3,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    id: { type: "string" },
                    label: { type: "string" },
                    title: { type: "string" },
                    type: { type: "string" },
                    payload: { type: "object", additionalProperties: true }
                  },
                  required: ["id", "label", "title", "type", "payload"]
                }
              }
            },
            required: ["id", "title", "description", "options"]
          }
        },
        nextAction: {
          anyOf: [
            { type: "null" },
            {
              type: "object",
              additionalProperties: false,
              properties: {
                id: { type: "string" },
                title: { type: "string" },
                type: { type: "string" },
                payload: { type: "object", additionalProperties: true }
              },
              required: ["id", "title", "type", "payload"]
            }
          ]
        },
        chips: {
          type: "array",
          minItems: 0,
          maxItems: 6,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: "string" },
              title: { type: "string" },
              prompt: { type: "string" }
            },
            required: ["id", "title", "prompt"]
          }
        },
        actions: {
          type: "array",
          minItems: 0,
          maxItems: 8,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              id: { type: "string" },
              title: { type: "string" },
              type: { type: "string" },
              payload: { type: "object", additionalProperties: true }
            },
            required: ["id", "title", "type", "payload"]
          }
        },
        debug: {
          type: "object",
          additionalProperties: false,
          properties: {
            usedContext: { type: "boolean" },
            confidence: { type: "string", enum: ["high", "medium", "low"] },
            evidence: {
              type: "array",
              items: { type: "string" },
              minItems: 0,
              maxItems: 8
            }
          },
          required: ["usedContext", "confidence", "evidence"]
        }
      },
      required: ["message", "chips", "actions", "debug"]
    }
  };
  schema.schema.required = [
    "message",
    "grounding",
    "suggestionCards",
    "nextAction",
    "chips",
    "actions",
    "debug"
  ];

  const systemPrompt = [
    "You are LoomAI for the iOS app Loom.",
    "Mission: End stress. Live fulfilled.",
    "",
    "Loom architecture:",
    "- Purpose (vision + passions): why the user is moving in this direction.",
    "- Fulfillment Areas (mission + identities + little wins): life domains to strengthen continuously.",
    "- Goals: concrete targets tied to fulfillment.",
    "- Capture: incoming actions and ideas.",
    "- Action Blocks: weekly execution plan.",
    "- Reflect: completed work and learning signals.",
    "",
    "Rules:",
    "- Ground your answer in APP_CONTEXT when available.",
    "- APP_CONTEXT uses an intent-based context pack with layers: identity, currentReality, targetObject.",
    "- When APP_CONTEXT exists and the user asks a Loom-related question, reference at least 2 concrete context details.",
    "- Never invent stats, values, goals, dates, or progress.",
    "- Never invent user history or user behavior not present in APP_CONTEXT.",
    "- If data is missing, say that briefly and continue with the best next step.",
    "- Do NOT parrot diagnostic option text verbatim; interpret patterns in your own words.",
    "- Message must feel like 'Loom knows me': concise, specific, and personalized.",
    "- Message can be 2-6 short paragraphs maximum. No filler. No hardcoded preambles.",
    "- Never include a sources block, A/B/C option comparisons, or 'which should I add/edit/replace' in message.",
    "- Avoid generic productivity filler.",
    "- Put recommendations in suggestionCards only (never inline in message).",
    "- suggestionCards may include A/B/C options when relevant.",
    "- Produce executable options only when confidence is high or medium and payload is executable.",
    "- NEVER put add/edit/improve/update/replace/create suggestions in `message`.",
    "- If confidence is low, suggestionCards must be [] and actions must be [].",
    "",
    "Formatting tokens in `message`:",
    "- [[P:...]] for purpose/passion emphasis",
    "- [[F:...]] for fulfillment category references",
    "- [[O:...]] for goals",
    "- [[A:...]] for actions",
    "- Use newlines intentionally. Use bullets with `•` when helpful.",
    "",
    "Output JSON only in this exact shape:",
    '{"message":"string","grounding":[{"section":"string","field":"string","timestamp":"ISO_OR_EMPTY"}],"suggestionCards":[{"id":"string","title":"string","description":"string","options":[{"id":"string","label":"A|B|C","title":"string","type":"string","payload":{}}]}],"nextAction":{"id":"string","title":"string","type":"string","payload":{}},"chips":[{"id":"string","title":"string","prompt":"string"}],"actions":[{"id":"string","title":"string","type":"string","payload":{}}],"debug":{"usedContext":true,"confidence":"high","evidence":["path.like.context.purpose.vision"]}}',
    "",
    "Action whitelist:",
    '- updatePurposeVision {"text":"..."}',
    '- addPassionItem {"passionType":"love|vows|thrill|hate","text":"..."}',
    '- updateFulfillmentMission {"categoryId":"uuid","text":"..."}',
    '- addLittleWin {"categoryId":"uuid","activity":"...","appleHealthEligible":true|false}',
    '- createOutcome {"categoryId":"uuid","title":"...","measurable":true|false,"unit":"steps|minutes|..."}',
    '- createCaptureAction {"text":"..."}',
    '- addPlanSuggestion {"text":"..."}',
    "",
    "Chip intent routing (if APP_CONTEXT.intent.routeID exists):",
    "- 1 Daily Little Wins for {category}: return little-win suggestion cards.",
    "- 2 New Mission for {category}: return mission rewrite cards.",
    "- 3 New Identity for {category}: return identity suggestion cards.",
    "- 4 Next step for {goal}: return immediate next-step cards.",
    "- 5 Plan for {goal}: return short plan cards.",
    "- 6 New passions for {emotion}: return passion cards.",
    "- 7 Improve my Purpose Vision: return purpose-vision cards.",
    "- 8 How can I best use Loom?: return a single high-leverage recommendation grounded in current context.",
    "",
    "Little Wins rule:",
    "- Default to daily-doable 5-20 minute actions unless user explicitly asks for weekly cadence.",
    "- For health/energy, prefer measurable Apple Health-aligned options when appropriate (steps, workouts, active minutes, sleep, mindfulness minutes).",
    "",
    "If user prompt is unrelated to Loom, respond gently:",
    '- "I can’t help with that, but I can help you with..." and provide 2-3 Loom-relevant chips.',
    "- For unrelated prompts, return actions as []."
  ].join("\n");

  const { modelContext, payloadContextMeta } = await compactChatContextForModel(context, {
    route: chipIntentRoute,
    latestUserMessage,
    client
  });
  const userPayload = {
    messages: messages.slice(-20).map((msg) => ({
      role: String(msg?.role || ""),
      content: String(msg?.content || "")
    })),
    APP_CONTEXT: modelContext,
    client: {
      intent: nonEmptyString(client.intent) || "loomai_chat",
      appVersion: nonEmptyString(client.appVersion) || null,
      userLocalDate: nonEmptyString(client.userLocalDate) || null,
      timezone: nonEmptyString(client.timezone) || null,
      remainingDailyResponses:
        Number.isFinite(Number(client.remainingDailyResponses))
          ? Number(client.remainingDailyResponses)
          : null
      }
  };
  const payloadSizing = estimatePayloadSize(userPayload);
  logLoomAIPayloadStats({
    intent: normalizedIntent || "loomai_chat",
    routeKey: nonEmptyString(chipIntentRoute?.key) || "none",
    routeID: Number.isFinite(Number(chipIntentRoute?.id)) ? Number(chipIntentRoute.id) : null,
    messageCount: userPayload.messages.length,
    includedSections: payloadContextMeta.includedSections,
    payloadBytes: payloadSizing.bytes,
    payloadApproxTokens: payloadSizing.approxTokens,
    stableHash: payloadContextMeta.stableContextHash,
    stableBlocksSent: payloadContextMeta.stableContextSent,
    stableBlocksChanged: payloadContextMeta.stableContextChanged
  });
  const chatCacheEnabled = env.DISABLE_CHAT_CACHE !== "1";
  const cacheIdentity = {
    version: "loom_chat_v5",
    model: preferredModel,
    messages: userPayload.messages,
    APP_CONTEXT: userPayload.APP_CONTEXT,
    client: {
      intent: userPayload.client.intent,
      userLocalDate: userPayload.client.userLocalDate,
      timezone: userPayload.client.timezone
    }
  };
  const chatCacheHash = await sha256Hex(JSON.stringify(cacheIdentity));
  const chatCacheKey = new Request(`https://loom-cache.internal/chat/${chatCacheHash}`);

  if (chatCacheEnabled) {
    const cached = await caches.default.match(chatCacheKey);
    if (cached) {
      try {
        const cachedJSON = await cached.json();
        if (cachedJSON && typeof cachedJSON === "object") {
          return json(cachedJSON, 200, corsHeaders(request));
        }
      } catch {
        // Ignore cache decode errors and continue to live generation.
      }
    }
  }

  let result = null;
  let usedModel = preferredModel;
  for (const candidate of modelCandidates) {
    usedModel = candidate;
    const attempt = await callOpenAIResponsesJSON({
      apiKey,
      model: candidate,
      systemPrompt,
      userPayload,
      responseSchema: schema,
      maxOutputTokens: 1100,
      timeoutMs: 26000,
      reasoningEffort: "low",
      allowRetry: true
    });
    result = attempt;
    if (!attempt?.error) break;
    const normalizedError = String(attempt.error || "").toLowerCase();
    const retryableByModel =
      normalizedError.includes("upstream model error") ||
      normalizedError.includes("invalid upstream json") ||
      normalizedError.includes("missing model output");
    if (!retryableByModel) break;
  }

  if (result.error) {
    const response = safeChatFallback({
      hasContext,
      context,
      intent: normalizedIntent
    });
    const usage = normalizeResponsesUsage(result.usage, usedModel || preferredModel);
    if (usage) {
      response.usage = usage;
    }
    return json(response, 200, corsHeaders(request));
  }

  const response = sanitizeLoomChatResponse(result.json, {
    context,
    hasContext,
    latestUserMessage,
    intent: normalizedIntent,
    chipIntentRoute
  });
  const usage = normalizeResponsesUsage(result.usage, usedModel);
  if (usage) {
    response.usage = usage;
  }
  if (chatCacheEnabled && shouldCacheLoomAIResponse(response)) {
    const cacheResponse = new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": `public, max-age=0, s-maxage=${CHAT_CACHE_TTL_SECONDS}`
      }
    });
    await caches.default.put(chatCacheKey, cacheResponse);
  }
  return json(response, 200, corsHeaders(request));
}

function compactAutoGroupContext(context) {
  const src = context && typeof context === "object" ? context : {};
  const rawTopItems = Array.isArray(src?.capture?.topItems) ? src.capture.topItems : [];
  const captureItems = Array.isArray(src?.captureItems)
    ? src.captureItems
        .map((item) => ({
          id: truncate(String(item?.id || ""), 64),
          text: truncate(String(item?.text || ""), 140)
        }))
        .filter((item) => item.id && item.text)
        .slice(0, 25)
    : [];
  const fallbackTopItems = captureItems.map((item) => item.text);
  const topItems = (rawTopItems.length > 0 ? rawTopItems : fallbackTopItems)
    .map((item) => truncate(String(item || ""), 140))
    .filter(Boolean)
    .slice(0, 12);
  const totalCountRaw = Number(src?.capture?.totalCount);
  const totalCount = Number.isFinite(totalCountRaw) ? Math.max(0, Math.floor(totalCountRaw)) : captureItems.length;
  return {
    capture: {
      totalCount,
      topItems
    },
    captureItems
  };
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
  const previousSuggestionSamples = uniqueOrdered(
    (Array.isArray(previousSuggestions) ? previousSuggestions : [])
      .map((item) => normalizeSuggestion(String(item || "")))
      .filter(Boolean)
  ).slice(0, 6);
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
    "In newVision mode, avoid reusing the same opening and wording from current vision.",
    "In newVision mode, keep lexical overlap low with current vision and prior suggestions.",
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
    mode === "rewordVision"
      ? (currentVisionSentence
        ? `Current vision sentence to preserve exactly: "${currentVisionSentence}"`
        : "No current vision sentence available to preserve.")
      : (currentVisionSentence
        ? `Current vision sentence to avoid echoing: "${currentVisionSentence}"`
        : "No current vision sentence available."),
    previousSuggestionSamples.length > 0
      ? `Prior suggestions to avoid repeating: ${previousSuggestionSamples.join(" || ")}`
      : "No prior suggestions provided.",
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
      previousSuggestions: previousSuggestionSamples,
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
  const autowriteUsage = combineResponsesUsage(insightResult.usage, visionResult.usage);
  const normalizedAutowriteUsage = normalizeResponsesUsage(autowriteUsage, "gpt-5.1");
  if (visionResult.error) {
    const response = {
      error: visionResult.error,
      details: buildVisionTroubleshootingDetails("vision_model_error", {
        ...requestMeta,
        model: "gpt-5.1",
        areasCount: normalizedDiagnostic.areas.length,
        upstream: visionResult.details ? truncate(String(visionResult.details), 1400) : null
      })
    };
    if (normalizedAutowriteUsage) {
      response.usage = normalizedAutowriteUsage;
    }
    return json(response, visionResult.status, corsHeaders(request));
  }

  if (typeof visionResult.json?.error === "string" && visionResult.json.error.trim() !== "") {
    const response = {
      error: "Couldn’t generate insights",
      details: buildVisionTroubleshootingDetails("insufficient_signal", {
        ...requestMeta,
        model: "gpt-5.1",
        areasCount: normalizedDiagnostic.areas.length,
        modelError: visionResult.json.error
      })
    };
    if (normalizedAutowriteUsage) {
      response.usage = normalizedAutowriteUsage;
    }
    return json(response, 422, corsHeaders(request));
  }

  const rawSuggestions = Array.isArray(visionResult.json?.visions)
    ? visionResult.json.visions
      .map((x) => normalizeSuggestion(String(x ?? "")))
      .filter(Boolean)
      .slice(0, 4)
    : [];
  const suggestions = (mode === "newVision"
    ? filterNewVisionSuggestions(rawSuggestions, currentVision, previousSuggestions)
    : uniqueOrdered(rawSuggestions)
  ).slice(0, 2);
  if (suggestions.length === 0) {
    const response = {
      error: "Couldn’t generate insights",
      details: buildVisionTroubleshootingDetails("no_usable_suggestions", {
        ...requestMeta,
        model: "gpt-5.1",
        areasCount: normalizedDiagnostic.areas.length,
        returnedVisionCount: Array.isArray(visionResult.json?.visions) ? visionResult.json.visions.length : 0
      })
    };
    if (normalizedAutowriteUsage) {
      response.usage = normalizedAutowriteUsage;
    }
    return json(response, 422, corsHeaders(request));
  }

  const response = {
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
  };
  if (normalizedAutowriteUsage) {
    response.usage = normalizedAutowriteUsage;
  }
  return json(response, 200, corsHeaders(request));
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
  const upstreamUsage = extractResponsesUsageFromText(upstreamText);

  if (!openAIResponse.ok) {
    if (openAIResponse.status === 400) {
      const unstructured = await performOpenAIResponsesAttemptWithoutSchema({
        apiKey,
        model,
        systemPrompt,
        userPayload,
        maxOutputTokens,
        timeoutMs,
        reasoningEffort
      });
      if (unstructured.ok) {
        return unstructured;
      }
    }
    const upstreamError = extractUpstreamErrorSignature(upstreamText);
    return {
      ok: false,
      retryable: false,
      result: {
        error: "Upstream model error",
        details: truncate(
          `status=${openAIResponse.status}${upstreamError ? ` ${upstreamError}` : ""}`,
          1000
        ),
        status: 502,
        usage: upstreamUsage
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
    return {
      ok: true,
      retryable: false,
      result: {
        json: obj,
        status: 200,
        usage: extractResponsesUsage(parsed)
      }
    };
  }

  const retryableMissingOutput = shouldRetryMissingOutput(parsed);
  return {
    ok: false,
    retryable: retryableMissingOutput,
    result: {
      error: "Missing model output",
      details: truncate(upstreamText, 1000),
      status: 502,
      usage: extractResponsesUsage(parsed)
    }
  };
}

async function performOpenAIResponsesAttemptWithoutSchema({
  apiKey,
  model,
  systemPrompt,
  userPayload,
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
              { type: "input_text", text: `${systemPrompt}\n\nReturn valid JSON only.` }
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
        max_output_tokens: maxOutputTokens
      })
    });
  } catch (e) {
    clearTimeout(t);
    return {
      ok: false,
      retryable: false,
      result: {
        error: "Upstream request failed",
        details: e && typeof e === "object" ? String(e.message || e.name || "request_failed") : "request_failed",
        status: 502
      }
    };
  } finally {
    clearTimeout(t);
  }

  const upstreamText = await openAIResponse.text();
  const upstreamUsage = extractResponsesUsageFromText(upstreamText);
  if (!openAIResponse.ok) {
    const upstreamError = extractUpstreamErrorSignature(upstreamText);
    return {
      ok: false,
      retryable: false,
      result: {
        error: "Upstream model error",
        details: truncate(`status=${openAIResponse.status}${upstreamError ? ` ${upstreamError}` : ""}`, 1000),
        status: 502,
        usage: upstreamUsage
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
    return {
      ok: true,
      retryable: false,
      result: {
        json: obj,
        status: 200,
        usage: extractResponsesUsage(parsed)
      }
    };
  }

  return {
    ok: false,
    retryable: false,
    result: {
      error: "Missing model output",
      details: truncate(upstreamText, 1000),
      status: 502,
      usage: extractResponsesUsage(parsed)
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

function filterNewVisionSuggestions(candidates, currentVision, previousSuggestions) {
  const blocked = new Set(
    [
      String(currentVision || ""),
      ...(Array.isArray(previousSuggestions) ? previousSuggestions : [])
    ]
      .map((item) => normalizedSuggestionKey(item))
      .filter(Boolean)
  );

  const kept = [];
  for (const candidate of (Array.isArray(candidates) ? candidates : [])) {
    const key = normalizedSuggestionKey(candidate);
    if (!key) continue;
    if (blocked.has(key)) continue;
    if (currentVision && isNearDuplicateSuggestion(candidate, currentVision)) continue;
    if (kept.some((existing) => isNearDuplicateSuggestion(existing, candidate))) continue;
    kept.push(candidate);
  }
  return kept;
}

function isNearDuplicateSuggestion(a, b) {
  const aNorm = normalizeSuggestion(String(a || ""));
  const bNorm = normalizeSuggestion(String(b || ""));
  if (!aNorm || !bNorm) return false;
  if (aNorm === bNorm) return true;

  const aSet = new Set(aNorm.split(/\s+/).filter((word) => word.length > 2));
  const bSet = new Set(bNorm.split(/\s+/).filter((word) => word.length > 2));
  if (aSet.size === 0 || bSet.size === 0) return false;

  let intersection = 0;
  for (const token of aSet) {
    if (bSet.has(token)) intersection += 1;
  }
  const union = aSet.size + bSet.size - intersection;
  const jaccard = union > 0 ? intersection / union : 0;
  if (jaccard >= 0.72) return true;

  const shorter = aNorm.length <= bNorm.length ? aNorm : bNorm;
  const longer = aNorm.length > bNorm.length ? aNorm : bNorm;
  if (shorter.length >= 42 && longer.includes(shorter)) return true;

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

function rankPurposeProfilesHeuristically({ diagnostic, rootCause, nextDirection, vision, passions }) {
  const d = diagnostic || {};
  const input = {
    stress: String(d.stress || ""),
    breaksFirst: String(d.breaksFirst || ""),
    planningStyle: String(d.planningStyle || ""),
    firstChange: String(d.firstChange || ""),
    rootCause: String(rootCause || ""),
    nextDirection: String(nextDirection || ""),
    vision: String(vision || ""),
    passions: Array.isArray(passions) ? passions : []
  };
  const evidenceTokens = buildPurposeProfileEvidenceTokens(input);
  const stressTokens = purposeProfileTokenSet(`${d.stress || ""} ${rootCause || ""}`);
  const executionTokens = purposeProfileTokenSet(
    `${d.breaksFirst || ""} ${d.planningStyle || ""} ${d.firstChange || ""} ${nextDirection || ""}`
  );
  const visionTokens = purposeProfileTokenSet(`${vision || ""} ${(Array.isArray(passions) ? passions : []).join(" ")} ${d.firstChange || ""}`);
  const seed = buildPurposeProfileHeuristicSeed(input);

  return PURPOSE_PROFILE_CATALOG
    .map((profile) => {
      const stressDescriptor = purposeProfileTokenSet(profile.stressTrigger);
      const breakDescriptor = purposeProfileTokenSet(profile.breakingPoint);
      const strengthDescriptor = purposeProfileTokenSet(profile.strength);
      const weaknessDescriptor = purposeProfileTokenSet(profile.weakness);
      const descriptorUnion = new Set([
        ...stressDescriptor,
        ...breakDescriptor,
        ...strengthDescriptor,
        ...weaknessDescriptor
      ]);

      let score = 0;
      score += purposeProfileOverlap(stressTokens, stressDescriptor) * 3.0;
      score += purposeProfileOverlap(executionTokens, breakDescriptor) * 3.0;
      score += purposeProfileOverlap(visionTokens, strengthDescriptor) * 1.4;
      score += purposeProfileOverlap(executionTokens, weaknessDescriptor) * 1.4;
      score += purposeProfileOverlap(evidenceTokens, descriptorUnion) * 2.2;

      return {
        profile: profile.profile,
        strength: profile.strength,
        weakness: profile.weakness,
        stressTrigger: profile.stressTrigger,
        breakingPoint: profile.breakingPoint,
        score
      };
    })
    .sort((a, b) => {
      const diff = b.score - a.score;
      if (Math.abs(diff) > 0.0001) return diff;
      return purposeProfileTieBreakRank(seed, a.profile) - purposeProfileTieBreakRank(seed, b.profile);
    });
}

function buildPurposeProfileHeuristicSeed(input) {
  return Array.from(buildPurposeProfileEvidenceTokens(input)).sort().join("|");
}

function pickPurposeProfileFromTopBand(ranked, seed) {
  const band = purposeProfileTopBand(ranked);
  if (band.length === 0) return null;
  if (band.length <= 1) return band[0];
  const index = purposeProfileTieBreakRank(`${seed}|band`, String(band.length)) % band.length;
  return band[index];
}

function purposeProfileTopBand(ranked) {
  if (!Array.isArray(ranked) || ranked.length === 0) return [];
  const top = ranked[0];
  const threshold = Math.max(top.score * 0.92, top.score - 0.28);
  return ranked.filter((item) => item.score >= threshold);
}

function buildPurposeProfileEvidenceTokens(input) {
  const combined = [
    input.stress || "",
    input.breaksFirst || "",
    input.planningStyle || "",
    input.firstChange || "",
    input.rootCause || "",
    input.nextDirection || "",
    input.vision || "",
    Array.isArray(input.passions) ? input.passions.join(" ") : ""
  ].join(" ");
  const tokens = new Set(purposeProfileTokenSet(combined));
  const signal = String(combined || "").toLowerCase();

  const expansions = [
    ["too many priorities", ["competing", "priorities", "tradeoffs", "coordination"]],
    ["feeling behind", ["chaos", "stability", "cadence", "consistency"]],
    ["disorganized", ["chaos", "stability", "structure"]],
    ["distractions", ["focus", "noise", "context", "switching"]],
    ["work pressure", ["pressure", "commitments", "deadlines"]],
    ["money pressure", ["resources", "constraints", "budget", "finance"]],
    ["low energy", ["energy", "capacity", "recovery"]],
    ["health", ["energy", "capacity", "recovery"]],
    ["relationship tension", ["interpersonal", "tension", "conflict"]],
    ["i don t start", ["start", "activation", "friction"]],
    ["lose momentum", ["consistency", "cadence", "follow", "through"]],
    ["distracted", ["focus", "context", "switching"]],
    ["overthink", ["analysis", "delay", "specificity"]],
    ["don t finish", ["finish", "follow", "through", "consistency"]],
    ["react to what s urgent", ["urgent", "reactive", "firefighting", "triage"]],
    ["off track", ["drift", "consistency", "boundary"]],
    ["follow through consistently", ["consistency", "cadence", "reliability"]],
    ["in control", ["clarity", "standards", "ownership"]],
    ["clear direction", ["clarity", "priorities", "alignment"]],
    ["faster progress", ["momentum", "velocity", "shipping"]],
    ["balanced across life", ["balance", "harmony", "alignment"]]
  ];

  for (const [needle, mapped] of expansions) {
    if (!signal.includes(needle)) continue;
    for (const token of mapped) {
      tokens.add(token);
    }
  }

  return tokens;
}

function purposeProfileTokenSet(raw) {
  const stopWords = new Set([
    "and", "are", "for", "from", "that", "this", "with", "your", "you", "the",
    "will", "into", "when", "then", "what", "have", "has", "but", "not", "yet",
    "too", "very", "more", "less", "across", "life", "loom", "through", "only"
  ]);
  return new Set(
    String(raw || "")
      .toLowerCase()
      .replace(/[^a-z0-9 ]/g, " ")
      .split(/\s+/)
      .map((token) => token.trim())
      .filter((token) => token.length > 2 && !stopWords.has(token))
  );
}

function purposeProfileOverlap(aSet, bSet) {
  if (!aSet?.size || !bSet?.size) return 0;
  let intersection = 0;
  for (const token of aSet) {
    if (bSet.has(token)) intersection += 1;
  }
  return intersection / Math.max(1, bSet.size);
}

function purposeProfileTieBreakRank(seed, profile) {
  return stableHash64(`${seed}|${String(profile || "").toLowerCase()}`);
}

function stableHash64(value) {
  let hash = 1469598103934665603n;
  const prime = 1099511628211n;
  const text = String(value || "");
  for (let i = 0; i < text.length; i += 1) {
    hash ^= BigInt(text.charCodeAt(i));
    hash = (hash * prime) & 0xffffffffffffffffn;
  }
  return Number(hash & 0x1fffffffffffffn);
}

function uniqueOrdered(items) {
  const seen = new Set();
  const result = [];
  for (const item of items) {
    const normalized = String(item ?? "");
    const key = normalized.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
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

  // Word cap aligned with the diagnostic prompt requirements.
  const words = value.split(/\s+/).filter(Boolean);
  if (words.length > 40) return false;

  const sentences = value
    .split(/[.!?]+/)
    .map((s) => s.trim())
    .filter(Boolean);

  return sentences.length >= 2 && sentences.length <= 3;
}

function buildDeterministicDiagnosticInsights(diagnostic) {
  const areaCount = Array.isArray(diagnostic?.areas) ? diagnostic.areas.length : 0;
  const scope = areaCount >= 5 ? "many parts of life" : "a few key parts of life";
  const rootCause = normalizeInsightText(
    `Your priorities compete across ${scope}. Urgent tasks keep taking over, so progress gets fragmented. You restart often, but completion falls behind.`
  );
  const nextDirection = normalizeInsightText(
    "Loom will create one clear lane each day. It narrows choices to a single finish target with short steps. This keeps progress steady before new tasks expand."
  );
  return { rootCause, nextDirection };
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

function hasMeaningfulLoomContext(context) {
  if (!context || typeof context !== "object") return false;
  const fulfillmentCount = Array.isArray(context.fulfillmentCategories)
    ? context.fulfillmentCategories.length
    : 0;
  const outcomesCount = Array.isArray(context.activeOutcomes) ? context.activeOutcomes.length : 0;
  const actionBlocksCount = Array.isArray(context.currentWeekActionBlocks)
    ? context.currentWeekActionBlocks.length
    : 0;
  const hasPurpose =
    nonEmptyString(context?.drivingForce?.vision) || nonEmptyString(context?.drivingForce?.purpose);
  const hasDiagnostic = nonEmptyString(context?.diagnostic?.stress) || nonEmptyString(context?.diagnostic?.rootCause);
  return Boolean(
    hasPurpose ||
      hasDiagnostic ||
      fulfillmentCount > 0 ||
      outcomesCount > 0 ||
      actionBlocksCount > 0
  );
}

function isLikelyUnrelatedPrompt(text) {
  const value = String(text || "").toLowerCase();
  if (!value) return false;
  const loomSignals = [
    "loom",
    "purpose",
    "passion",
    "fulfillment",
    "mission",
    "identity",
    "little win",
    "outcome",
    "capture",
    "action block",
    "reflect",
    "stress",
    "planning"
  ];
  if (loomSignals.some((term) => value.includes(term))) return false;

  const likelyUnrelatedSignals = [
    "stock price",
    "bitcoin",
    "weather",
    "sports score",
    "movie",
    "recipe",
    "lyrics",
    "translate",
    "code bug",
    "javascript",
    "swiftui"
  ];
  return likelyUnrelatedSignals.some((term) => value.includes(term));
}

function buildUnrelatedRedirectChips(context) {
  const fallback = buildDefaultLoomChips(context);
  return fallback.slice(0, 3);
}

function buildDefaultLoomChips(context) {
  const categories = Array.isArray(context?.fulfillmentCategories)
    ? context.fulfillmentCategories.map((x) => String(x?.name || "").trim()).filter(Boolean)
    : [];
  const topCategory = categories[0] || "my key fulfillment area";
  const outcomes = Array.isArray(context?.activeOutcomes)
    ? context.activeOutcomes.map((x) => String(x?.title || "").trim()).filter(Boolean)
    : [];
  const topOutcome = outcomes[0] || "my outcomes";

  const chips = [
    {
      id: "loom-focus-week",
      title: "Focus this week",
      prompt: "What should I focus on this week in Loom based on my current data?"
    },
    {
      id: "loom-improve-mission",
      title: `Improve ${truncate(topCategory, 32)}`,
      prompt: `How can I improve the mission and little wins for ${topCategory}?`
    },
    {
      id: "loom-outcome-next-step",
      title: "Next best outcome step",
      prompt: `What is the next best action for ${topOutcome}?`
    },
    {
      id: "loom-capture-prioritize",
      title: "Prioritize capture",
      prompt: "Turn my capture items into the highest-leverage next actions."
    }
  ];
  return chips;
}

function safeChatFallback({ hasContext, context, message, intent }) {
  const normalizedIntent = String(intent || "").trim().toLowerCase();
  if (normalizedIntent === "autogroup_plan") {
    return {
      message: '{"confidence":"low","reason":"Could not confidently group actions.","groups":[]}',
      grounding: [],
      suggestionCards: [],
      nextAction: null,
      chips: [],
      actions: [],
      debug: {
        usedContext: false,
        confidence: "low",
        evidence: []
      }
    };
  }

  const fallbackMessage =
    nonEmptyString(message) ||
    "Couldn't generate response. Check your connection.";
  const fallbackGrounding = hasContext ? collectGrounding([], context, { maxItems: 3 }) : [];
  return {
    message: fallbackMessage,
    grounding: fallbackGrounding,
    suggestionCards: [],
    nextAction: null,
    chips: [],
    actions: [],
    debug: {
      usedContext: Boolean(hasContext),
      confidence: "low",
      evidence: hasContext ? extractEvidencePathsFromContext(context, 2) : []
    }
  };
}

const CONTEXT_PACK_LIMITS = {
  identityPassions: 4,
  fulfillmentAreas: 4,
  goals: 4,
  actionBlocks: 4,
  actionBlockActions: 3,
  captureTopItems: 4,
  dataInventory: 8,
  dataInventorySignals: 2,
  appGuide: 6,
  appGuideSummaryMax: 180,
  missionMax: 220
};

async function compactChatContextForModel(context, { route = null, latestUserMessage = "", client = {} } = {}) {
  const src = context && typeof context === "object" ? context : {};
  const cleaned = normalizeContextForIntentPack(src);
  const identity = buildIdentityContextLayer(src, cleaned);
  const targetObject = buildTargetObjectContextLayer({ route, cleaned, latestUserMessage });
  const currentReality = buildCurrentRealityContextLayer({ route, cleaned, targetObject });
  const stableBlocks = {
    appGuide: cleaned.appGuide,
    dataInventory: cleaned.dataInventory
  };
  const stableEnvelope = await resolveStableContextEnvelope({
    context: src,
    client,
    stableBlocks,
    includeStableBlocksByIntent: shouldIncludeStableBlocksForIntent(route)
  });

  const modelContext = {
    generatedAt: normalizeCompactTimestamp(src.generatedAt),
    personalizationHash: nonEmptyString(src.personalizationHash) || null,
    intent: {
      routeID: Number.isFinite(Number(route?.id)) ? Number(route.id) : null,
      routeKey: nonEmptyString(route?.key) || null,
      target: nonEmptyString(route?.target) || null
    },
    layers: {
      identity,
      currentReality,
      targetObject
    },
    stableContext: stableEnvelope.payload
  };

  const payloadContextMeta = {
    includedSections: summarizeIncludedContextSections(modelContext),
    stableContextHash: stableEnvelope.hash,
    stableContextChanged: stableEnvelope.changed,
    stableContextSent: stableEnvelope.includeFull
  };
  return { modelContext, payloadContextMeta };
}

function normalizeContextForIntentPack(src) {
  return {
    diagnostic: cleanDiagnosticSummary(src?.diagnostic),
    drivingForce: cleanDrivingForceSummary(src?.drivingForce),
    fulfillmentCategories: cleanFulfillmentCategories(src?.fulfillmentCategories),
    activeGoals: cleanActiveGoals(src?.activeOutcomes),
    currentWeekActionBlocks: cleanActionBlocks(src?.currentWeekActionBlocks),
    capture: cleanCaptureSummary(src?.capture),
    dataInventory: cleanDataInventory(src?.dataInventory),
    appGuide: cleanAppGuide(src?.appGuide),
    sectionTimestamps: src?.sectionTimestamps && typeof src.sectionTimestamps === "object" ? src.sectionTimestamps : null
  };
}

function buildIdentityContextLayer(src, cleaned) {
  const profileLabel = cleanCompactTitle(
    src?.purposeProfile?.profile ||
      src?.personalityProfile?.profile ||
      src?.behaviorProfile?.profile ||
      src?.profile?.profile,
    72
  );
  const layer = {
    diagnostic: cleaned.diagnostic,
    purpose: cleaned.drivingForce,
    personalityProfile: profileLabel || null
  };
  return pruneEmptyObject(layer);
}

function buildTargetObjectContextLayer({ route, cleaned, latestUserMessage }) {
  const routeID = Number(route?.id);
  const targetText = nonEmptyString(route?.target);

  if ([1, 2, 3].includes(routeID)) {
    const category =
      findCategoryByName(cleaned.fulfillmentCategories, targetText) ||
      cleaned.fulfillmentCategories[0] ||
      null;
    if (!category) return null;
    return {
      type: "fulfillment_area",
      id: category.id || "",
      name: category.name,
      mission: category.mission || "",
      identity: category.identity || [],
      littleWins: category.littleWins || []
    };
  }

  if ([4, 5].includes(routeID)) {
    const goal =
      findGoalByTitle(cleaned.activeGoals, targetText) ||
      cleaned.activeGoals[0] ||
      null;
    if (!goal) return null;
    return {
      type: "goal",
      id: goal.id || "",
      title: goal.title,
      category: goal.category || "",
      measurable: Boolean(goal.measurable),
      progressSummary: goal.progressSummary || ""
    };
  }

  if (routeID === 6) {
    const emotion = normalizePassionType(targetText || "love");
    const related = cleaned.drivingForce?.passions || [];
    return {
      type: "passion_type",
      emotion,
      relatedPassions: related
        .filter((item) => String(item?.emotion || "").toLowerCase() === emotion)
        .slice(0, 3)
    };
  }

  if (routeID === 7) {
    return cleaned.drivingForce
      ? {
          type: "purpose_vision",
          vision: cleaned.drivingForce.vision || "",
          purpose: cleaned.drivingForce.purpose || ""
        }
      : null;
  }

  if (routeID === 8) {
    return {
      type: "loom_usage",
      prompt: truncate(nonEmptyString(latestUserMessage) || "How can I best use Loom?", 220)
    };
  }

  return null;
}

function buildCurrentRealityContextLayer({ route, cleaned, targetObject }) {
  const routeID = Number(route?.id);
  const targetCategoryName = nonEmptyString(targetObject?.name || targetObject?.category || route?.target);
  const targetGoalTitle = nonEmptyString(targetObject?.title || route?.target);

  let categories = cleaned.fulfillmentCategories;
  let goals = cleaned.activeGoals;
  let blocks = cleaned.currentWeekActionBlocks;

  if ([1, 2, 3].includes(routeID)) {
    categories = targetCategoryName
      ? categories.filter((item) => equalsFold(item.name, targetCategoryName)).slice(0, 2)
      : categories.slice(0, 1);
    goals = targetCategoryName
      ? goals.filter((item) => equalsFold(item.category, targetCategoryName)).slice(0, 2)
      : goals.slice(0, 1);
    blocks = targetCategoryName
      ? filterActionBlocksByTarget(blocks, targetCategoryName).slice(0, 2)
      : blocks.slice(0, 1);
  } else if ([4, 5].includes(routeID)) {
    goals = targetGoalTitle
      ? goals.filter((item) => equalsFold(item.title, targetGoalTitle)).slice(0, 2)
      : goals.slice(0, 2);
    const goalCategory = nonEmptyString(goals[0]?.category || targetCategoryName);
    categories = goalCategory
      ? categories.filter((item) => equalsFold(item.name, goalCategory)).slice(0, 1)
      : [];
    blocks = filterActionBlocksByTarget(blocks, targetGoalTitle || goalCategory).slice(0, 2);
  } else if (routeID === 8) {
    categories = categories.slice(0, 2);
    goals = goals.slice(0, 3);
    blocks = blocks.slice(0, 3);
  } else {
    categories = categories.slice(0, 1);
    goals = goals.slice(0, 2);
    blocks = blocks.slice(0, 2);
  }

  if (targetObject?.type === "fulfillment_area") {
    categories = categories.filter((item) => !equalsFold(item.name, targetObject.name));
  }
  if (targetObject?.type === "goal") {
    goals = goals.filter((item) => !equalsFold(item.title, targetObject.title));
  }

  const layer = {
    fulfillment: categories.length > 0 ? categories : null,
    goals: goals.length > 0 ? goals : null,
    week: blocks.length > 0 ? { currentWeekActionBlocks: blocks } : null,
    capture:
      cleaned.capture && (routeID === 8 || routeID === 4 || routeID === 5 || !Number.isFinite(routeID))
        ? cleaned.capture
        : null
  };
  return pruneEmptyObject(layer);
}

function cleanDiagnosticSummary(input) {
  const src = input && typeof input === "object" ? input : {};
  const areas = cleanStringList(src.areas, { maxItems: 5, maxChars: 48, minLength: 2, allowJunkTitles: false });
  const diagnostic = {
    stress: cleanCompactText(src.stress, 100),
    breaksFirst: cleanCompactText(src.breaksFirst, 100),
    planningStyle: cleanCompactText(src.planningStyle, 100),
    firstChange: cleanCompactText(src.firstChange, 120),
    rootCause: cleanCompactText(src.rootCause, 180),
    nextDirection: cleanCompactText(src.nextDirection, 180),
    areas
  };
  return pruneEmptyObject(diagnostic);
}

function cleanDrivingForceSummary(input) {
  const src = input && typeof input === "object" ? input : {};
  const passions = cleanPassions(src.passions);
  const drivingForce = {
    vision: cleanCompactText(src.vision, 240),
    purpose: cleanCompactText(src.purpose, 240),
    passions: passions.length > 0 ? passions : null
  };
  return pruneEmptyObject(drivingForce);
}

function cleanPassions(input) {
  const source = Array.isArray(input) ? input : [];
  const deduped = [];
  const seen = new Set();
  for (const item of source) {
    const emotion = normalizePassionType(nonEmptyString(item?.emotion || item?.passionType || "love"));
    const title = cleanCompactTitle(item?.title, 96);
    if (!title) continue;
    const key = `${emotion}|${title.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push({ emotion, title });
    if (deduped.length >= CONTEXT_PACK_LIMITS.identityPassions) break;
  }
  return deduped;
}

function cleanFulfillmentCategories(input) {
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();
  for (const item of source) {
    const id = cleanCompactText(item?.id, 40);
    const name = cleanCompactTitle(item?.name, 72);
    if (!name) continue;
    const mission = normalizeMissionText(item?.mission);
    const identity = cleanStringList(item?.identity, { maxItems: 3, maxChars: 64, minLength: 2, allowJunkTitles: false });
    const littleWins = cleanStringList(item?.littleWins, { maxItems: 3, maxChars: 72, minLength: 2, allowJunkTitles: false });
    const weeklyScoreRaw = Number(item?.weeklyScore);
    const weeklyScore = Number.isFinite(weeklyScoreRaw) ? Number(weeklyScoreRaw.toFixed(1)) : null;
    const key = `${id || ""}|${name.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cleaned.push({
      id,
      name,
      mission,
      identity,
      littleWins,
      weeklyScore
    });
    if (cleaned.length >= CONTEXT_PACK_LIMITS.fulfillmentAreas) break;
  }
  return cleaned;
}

function cleanActiveGoals(input) {
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();
  for (const item of source) {
    const id = cleanCompactText(item?.id, 40);
    const title = cleanCompactTitle(item?.title, 96);
    if (!title) continue;
    const category = cleanCompactTitle(item?.category, 72);
    const progressSummary = cleanCompactText(item?.progressSummary, 140);
    const measurable = Boolean(item?.measurable);
    const key = `${id || ""}|${title.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cleaned.push({
      id,
      title,
      category,
      measurable,
      progressSummary
    });
    if (cleaned.length >= CONTEXT_PACK_LIMITS.goals) break;
  }
  return cleaned;
}

function cleanActionBlocks(input) {
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();
  for (const item of source) {
    const category = cleanCompactTitle(item?.category, 72);
    let title = cleanCompactTitle(item?.title, 96);
    const actions = cleanStringList(item?.actions, {
      maxItems: CONTEXT_PACK_LIMITS.actionBlockActions,
      maxChars: 90,
      minLength: 2,
      allowJunkTitles: false
    });
    if (!title && actions.length > 0) {
      title = actions[0];
    }
    if (!title && actions.length === 0) continue;
    const ratioRaw = Number(item?.completionRatio);
    const completionRatio = Number.isFinite(ratioRaw)
      ? Math.max(0, Math.min(1, Number(ratioRaw.toFixed(3))))
      : 0;
    const key = `${category.toLowerCase()}|${title.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cleaned.push({
      category,
      title,
      completionRatio,
      actions
    });
    if (cleaned.length >= CONTEXT_PACK_LIMITS.actionBlocks) break;
  }
  return cleaned;
}

function cleanCaptureSummary(input) {
  const src = input && typeof input === "object" ? input : {};
  const totalCountRaw = Number(src.totalCount);
  const totalCount = Number.isFinite(totalCountRaw) ? Math.max(0, Math.floor(totalCountRaw)) : 0;
  const quickCompletionsRaw = Number(src.quickCompletionsLast7Days);
  const quickCompletionsLast7Days = Number.isFinite(quickCompletionsRaw)
    ? Math.max(0, Math.floor(quickCompletionsRaw))
    : 0;
  const topItems = cleanStringList(src.topItems, {
    maxItems: CONTEXT_PACK_LIMITS.captureTopItems,
    maxChars: 90,
    minLength: 2,
    allowJunkTitles: false
  });
  if (totalCount === 0 && quickCompletionsLast7Days === 0 && topItems.length === 0) return null;
  return {
    totalCount,
    quickCompletionsLast7Days,
    topItems
  };
}

function cleanDataInventory(input) {
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();
  for (const item of source) {
    const id = cleanCompactText(item?.id, 48);
    const title = cleanCompactTitle(item?.title, 96);
    if (!title) continue;
    const currentCountRaw = Number(item?.currentCount);
    const historicalCountRaw = Number(item?.historicalCount);
    const currentCount = Number.isFinite(currentCountRaw) ? Math.max(0, Math.floor(currentCountRaw)) : null;
    const historicalCount = Number.isFinite(historicalCountRaw) ? Math.max(0, Math.floor(historicalCountRaw)) : null;
    const keySignals = cleanStringList(item?.keySignals, {
      maxItems: CONTEXT_PACK_LIMITS.dataInventorySignals,
      maxChars: 96,
      minLength: 2,
      allowJunkTitles: false
    });
    const key = `${id || ""}|${title.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cleaned.push({
      id,
      title,
      currentCount,
      historicalCount,
      keySignals
    });
    if (cleaned.length >= CONTEXT_PACK_LIMITS.dataInventory) break;
  }
  return cleaned;
}

function cleanAppGuide(input) {
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();
  for (const item of source) {
    const id = cleanCompactText(item?.id, 48);
    const title = cleanCompactTitle(item?.title, 88);
    if (!title) continue;
    const summary = cleanCompactText(item?.summary, CONTEXT_PACK_LIMITS.appGuideSummaryMax);
    const key = `${id || ""}|${title.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cleaned.push({
      id,
      title,
      summary
    });
    if (cleaned.length >= CONTEXT_PACK_LIMITS.appGuide) break;
  }
  return cleaned;
}

function cleanStringList(input, { maxItems = 4, maxChars = 80, minLength = 1, allowJunkTitles = true } = {}) {
  const source = Array.isArray(input) ? input : [];
  const result = [];
  const seen = new Set();
  for (const raw of source) {
    const clean = cleanCompactText(raw, maxChars);
    if (!clean || clean.length < minLength) continue;
    if (!allowJunkTitles && isLikelyJunkTitle(clean)) continue;
    const key = clean.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(clean);
    if (result.length >= maxItems) break;
  }
  return result;
}

function cleanCompactText(value, maxChars = 120) {
  const text = String(value || "")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "";
  if (text.length <= maxChars) return text;
  return text.slice(0, maxChars).trim();
}

function cleanCompactTitle(value, maxChars = 90) {
  const text = cleanCompactText(value, maxChars);
  if (!text) return "";
  if (isLikelyJunkTitle(text)) return "";
  return text;
}

function isLikelyJunkTitle(value) {
  const text = String(value || "").trim();
  if (!text) return true;
  const lower = text.toLowerCase();
  if (text.length <= 1) return true;
  if (/^[^a-z0-9]+$/i.test(text)) return true;
  const junkSet = new Set(["t", "tt", "x", "n/a", "na", "none", "test", "todo", "tmp", "draft"]);
  return junkSet.has(lower);
}

function normalizeMissionText(value) {
  const text = cleanCompactText(value, 1000);
  if (!text) return "";
  if (isLikelyJunkTitle(text)) return "";
  if (/[…]$/.test(text) || /\.\.\.$/.test(text)) return "";
  if (text.length <= CONTEXT_PACK_LIMITS.missionMax) return text;
  const firstSentence = extractFirstSentence(text);
  if (firstSentence && firstSentence.length <= CONTEXT_PACK_LIMITS.missionMax) return firstSentence;
  return text.slice(0, CONTEXT_PACK_LIMITS.missionMax).trim();
}

function findCategoryByName(categories, target) {
  const source = Array.isArray(categories) ? categories : [];
  const normalizedTarget = nonEmptyString(target).toLowerCase();
  if (!normalizedTarget) return null;
  return source.find((item) => String(item?.name || "").trim().toLowerCase() === normalizedTarget) || null;
}

function findGoalByTitle(goals, target) {
  const source = Array.isArray(goals) ? goals : [];
  const normalizedTarget = nonEmptyString(target).toLowerCase();
  if (!normalizedTarget) return null;
  return source.find((item) => String(item?.title || "").trim().toLowerCase() === normalizedTarget) || null;
}

function filterActionBlocksByTarget(blocks, target) {
  const source = Array.isArray(blocks) ? blocks : [];
  const needle = nonEmptyString(target).toLowerCase();
  if (!needle) return source;
  const filtered = source.filter((item) => {
    const title = String(item?.title || "").toLowerCase();
    const category = String(item?.category || "").toLowerCase();
    const actions = Array.isArray(item?.actions) ? item.actions.join(" ").toLowerCase() : "";
    return title.includes(needle) || category.includes(needle) || actions.includes(needle);
  });
  return filtered.length > 0 ? filtered : source;
}

function equalsFold(a, b) {
  const left = String(a || "").trim().toLowerCase();
  const right = String(b || "").trim().toLowerCase();
  return Boolean(left) && Boolean(right) && left === right;
}

function shouldIncludeStableBlocksForIntent(route) {
  const routeID = Number(route?.id);
  return !Number.isFinite(routeID) || routeID === 8;
}

async function resolveStableContextEnvelope({
  context,
  client,
  stableBlocks,
  includeStableBlocksByIntent
}) {
  const payload = stableBlocks && typeof stableBlocks === "object"
    ? {
        appGuide: Array.isArray(stableBlocks.appGuide) ? stableBlocks.appGuide : [],
        dataInventory: Array.isArray(stableBlocks.dataInventory) ? stableBlocks.dataInventory : []
      }
    : { appGuide: [], dataInventory: [] };
  const hash = await sha256Hex(JSON.stringify(payload));
  const scopeHash = await resolveStableContextScopeHash(context, payload);
  const clientHintHash = nonEmptyString(
    client?.stableContextHash ||
      client?.contextStableHash ||
      client?.lastStableContextHash
  );
  const cachedHash = await readStableContextHash(scopeHash);
  const previousHash = clientHintHash || cachedHash;
  const changed = previousHash !== hash;
  const includeFull = Boolean(includeStableBlocksByIntent && changed);

  await writeStableContextHash(scopeHash, hash);
  if (includeFull) {
    await cacheStableContextBlocks(hash, payload);
  }

  return {
    hash,
    changed,
    includeFull,
    payload: {
      hash,
      changed,
      appGuide: includeFull ? payload.appGuide : [],
      dataInventory: includeFull ? payload.dataInventory : [],
      counts: {
        appGuide: payload.appGuide.length,
        dataInventory: payload.dataInventory.length
      }
    }
  };
}

async function resolveStableContextScopeHash(context, payload) {
  const src = context && typeof context === "object" ? context : {};
  const base =
    nonEmptyString(src.personalizationHash) ||
    nonEmptyString(src?.drivingForce?.vision) ||
    nonEmptyString(src?.drivingForce?.purpose) ||
    JSON.stringify({
      appGuideCount: Array.isArray(payload?.appGuide) ? payload.appGuide.length : 0,
      dataInventoryCount: Array.isArray(payload?.dataInventory) ? payload.dataInventory.length : 0
    });
  return sha256Hex(base);
}

async function readStableContextHash(scopeHash) {
  if (!scopeHash) return "";
  const key = new Request(`https://loom-cache.internal/stable-context/state/${scopeHash}`);
  try {
    const cached = await caches.default.match(key);
    if (!cached) return "";
    const json = await cached.json();
    return nonEmptyString(json?.hash);
  } catch {
    return "";
  }
}

async function writeStableContextHash(scopeHash, hash) {
  if (!scopeHash || !hash) return;
  const key = new Request(`https://loom-cache.internal/stable-context/state/${scopeHash}`);
  try {
    const response = new Response(JSON.stringify({ hash }), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=0, s-maxage=2592000"
      }
    });
    await caches.default.put(key, response);
  } catch {
    // Ignore cache write failures.
  }
}

async function cacheStableContextBlocks(hash, payload) {
  if (!hash) return;
  const key = new Request(`https://loom-cache.internal/stable-context/blocks/${hash}`);
  try {
    const response = new Response(JSON.stringify(payload), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=0, s-maxage=2592000"
      }
    });
    await caches.default.put(key, response);
  } catch {
    // Ignore cache write failures.
  }
}

function summarizeIncludedContextSections(modelContext) {
  const sections = [];
  const add = (name, condition) => {
    if (condition) sections.push(name);
  };
  add("identity.diagnostic", Boolean(modelContext?.layers?.identity?.diagnostic));
  add("identity.purpose", Boolean(modelContext?.layers?.identity?.purpose));
  add("identity.personalityProfile", Boolean(modelContext?.layers?.identity?.personalityProfile));
  add("currentReality.fulfillment", Array.isArray(modelContext?.layers?.currentReality?.fulfillment) && modelContext.layers.currentReality.fulfillment.length > 0);
  add("currentReality.goals", Array.isArray(modelContext?.layers?.currentReality?.goals) && modelContext.layers.currentReality.goals.length > 0);
  add("currentReality.week", Boolean(modelContext?.layers?.currentReality?.week));
  add("currentReality.capture", Boolean(modelContext?.layers?.currentReality?.capture));
  add("targetObject", Boolean(modelContext?.layers?.targetObject));
  add("stableContext.appGuide", Array.isArray(modelContext?.stableContext?.appGuide) && modelContext.stableContext.appGuide.length > 0);
  add("stableContext.dataInventory", Array.isArray(modelContext?.stableContext?.dataInventory) && modelContext.stableContext.dataInventory.length > 0);
  return sections;
}

function pruneEmptyObject(input) {
  const src = input && typeof input === "object" ? input : null;
  if (!src) return null;
  const cleaned = {};
  for (const [key, value] of Object.entries(src)) {
    if (value === null || value === undefined) continue;
    if (typeof value === "string" && !value.trim()) continue;
    if (Array.isArray(value) && value.length === 0) continue;
    if (typeof value === "object" && !Array.isArray(value)) {
      const nested = pruneEmptyObject(value);
      if (!nested) continue;
      cleaned[key] = nested;
      continue;
    }
    cleaned[key] = value;
  }
  return Object.keys(cleaned).length > 0 ? cleaned : null;
}

function normalizeCompactTimestamp(value) {
  if (!value) return null;
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) return null;
  return parsed.toISOString();
}

function estimatePayloadSize(payload) {
  const text = JSON.stringify(payload || {});
  const bytes = new TextEncoder().encode(text).length;
  return {
    bytes,
    approxTokens: Math.max(1, Math.ceil(text.length / 4))
  };
}

function logLoomAIPayloadStats(stats) {
  try {
    console.log(`[loom.chat.payload] ${JSON.stringify(stats || {})}`);
  } catch {
    // Ignore logging failures.
  }
}

function extractUpstreamErrorSignature(upstreamText) {
  const text = String(upstreamText || "").trim();
  if (!text) return "";
  try {
    const parsed = JSON.parse(text);
    const error = parsed?.error && typeof parsed.error === "object" ? parsed.error : null;
    if (!error) return truncate(text, 300);
    const code = nonEmptyString(error.code);
    const type = nonEmptyString(error.type);
    const message = nonEmptyString(error.message);
    const parts = [];
    if (code) parts.push(`code=${code}`);
    if (type) parts.push(`type=${type}`);
    if (message) parts.push(`message=${truncate(message, 180)}`);
    return parts.join(" ");
  } catch {
    return truncate(text, 300);
  }
}

function extractResponsesUsage(parsed) {
  const usage = parsed?.usage && typeof parsed.usage === "object" ? parsed.usage : null;
  if (!usage) return null;
  const inputTokens = Number(usage.input_tokens);
  const outputTokens = Number(usage.output_tokens);
  const totalTokens = Number(usage.total_tokens);
  const cachedInputTokens = Number(
    usage?.input_tokens_details?.cached_tokens ??
    usage?.input_tokens_details?.cached_input_tokens ??
    0
  );
  return {
    inputTokens: Number.isFinite(inputTokens) ? Math.max(0, Math.floor(inputTokens)) : 0,
    cachedInputTokens: Number.isFinite(cachedInputTokens) ? Math.max(0, Math.floor(cachedInputTokens)) : 0,
    outputTokens: Number.isFinite(outputTokens) ? Math.max(0, Math.floor(outputTokens)) : 0,
    totalTokens: Number.isFinite(totalTokens) ? Math.max(0, Math.floor(totalTokens)) : null
  };
}

function extractResponsesUsageFromText(text) {
  const raw = String(text || "").trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return extractResponsesUsage(parsed);
  } catch {
    return null;
  }
}

function combineResponsesUsage(a, b) {
  const first = a && typeof a === "object" ? a : null;
  const second = b && typeof b === "object" ? b : null;
  if (!first && !second) return null;
  if (!first) return second;
  if (!second) return first;
  const add = (x, y) => {
    const xn = Number(x);
    const yn = Number(y);
    const xv = Number.isFinite(xn) ? xn : 0;
    const yv = Number.isFinite(yn) ? yn : 0;
    return xv + yv;
  };
  return {
    inputTokens: add(first.inputTokens, second.inputTokens),
    cachedInputTokens: add(first.cachedInputTokens, second.cachedInputTokens),
    outputTokens: add(first.outputTokens, second.outputTokens),
    totalTokens: add(first.totalTokens, second.totalTokens)
  };
}

function normalizeResponsesUsage(usage, model) {
  if (!usage || typeof usage !== "object") return null;
  const inputTokens = Number(usage.inputTokens);
  const cachedInputTokens = Number(usage.cachedInputTokens);
  const outputTokens = Number(usage.outputTokens);
  const totalTokens = Number(usage.totalTokens);
  if (!Number.isFinite(inputTokens) && !Number.isFinite(outputTokens)) return null;
  return {
    model: nonEmptyString(model) || DEFAULT_CHAT_MODEL,
    inputTokens: Number.isFinite(inputTokens) ? Math.max(0, Math.floor(inputTokens)) : 0,
    cachedInputTokens: Number.isFinite(cachedInputTokens) ? Math.max(0, Math.floor(cachedInputTokens)) : 0,
    outputTokens: Number.isFinite(outputTokens) ? Math.max(0, Math.floor(outputTokens)) : 0,
    totalTokens: Number.isFinite(totalTokens)
      ? Math.max(0, Math.floor(totalTokens))
      : Math.max(
          0,
          (Number.isFinite(inputTokens) ? Math.floor(inputTokens) : 0) +
            (Number.isFinite(outputTokens) ? Math.floor(outputTokens) : 0)
        )
  };
}

function shouldCacheLoomAIResponse(response) {
  if (!response || typeof response !== "object") return false;
  const message = nonEmptyString(response.message);
  if (!message) return false;
  if (message === "Couldn't generate response. Check your connection.") return false;
  return true;
}

const CHIP_INTENT_ROUTES = [
  {
    id: 1,
    key: "daily_little_wins",
    pattern: /^daily little wins for\s+(.+)$/i
  },
  {
    id: 2,
    key: "new_mission",
    pattern: /^new mission for\s+(.+)$/i
  },
  {
    id: 3,
    key: "new_identity",
    pattern: /^new identity for\s+(.+)$/i
  },
  {
    id: 4,
    key: "goal_next_step",
    pattern: /^next step for\s+(.+)$/i
  },
  {
    id: 5,
    key: "goal_plan",
    pattern: /^plan for\s+(.+)$/i
  },
  {
    id: 6,
    key: "new_passions",
    pattern: /^new passions for\s+(.+)$/i
  },
  {
    id: 7,
    key: "improve_purpose_vision",
    pattern: /^improve my purpose vision$/i
  },
  {
    id: 8,
    key: "best_use_loom",
    pattern: /^(how can i best use loom\??|based on everything loom knows about me\b.*single most effective way for me to use loom right now to reduce stress and live fulfilled\.?)$/i
  }
];

function resolveChipIntentRoute(latestUserMessage) {
  const text = String(latestUserMessage || "").replace(/\s+/g, " ").trim();
  if (!text) return null;
  for (const route of CHIP_INTENT_ROUTES) {
    const match = text.match(route.pattern);
    if (!match) continue;
    const targetRaw = nonEmptyString(match[1] || "");
    const normalizedTarget =
      route.id === 6
        ? normalizePassionType(targetRaw || "love")
        : truncate(targetRaw, 120);
    return {
      id: route.id,
      key: route.key,
      label: truncate(text, 180),
      target: normalizedTarget
    };
  }
  return null;
}

function normalizePassionType(value) {
  const text = String(value || "").trim().toLowerCase();
  if (["love", "vows", "thrill", "hate"].includes(text)) return text;
  return "love";
}

function sanitizeLoomChatResponse(raw, { context, hasContext, latestUserMessage, intent, chipIntentRoute }) {
  const normalizedIntent = String(intent || "").trim().toLowerCase();
  const isAutoGroupIntent = normalizedIntent === "autogroup_plan";
  const base = raw && typeof raw === "object" ? raw : {};
  if (!nonEmptyString(base.message)) {
    return safeChatFallback({ hasContext, context, intent: normalizedIntent });
  }

  const route = chipIntentRoute || resolveChipIntentRoute(latestUserMessage);
  const debug = normalizeDebug(base.debug, context, hasContext);
  const chips = normalizeChips(base.chips, context);
  const normalizedActions = isAutoGroupIntent ? [] : normalizeActions(base.actions, {
    confidence: debug.confidence,
    context,
    latestUserMessage
  });

  const recommendationSignal = stripRecommendationContentFromMessage(String(base.message || ""));
  const fallbackExtractedActions = (!isAutoGroupIntent && recommendationSignal.hadRecommendations && normalizedActions.length === 0)
    ? inferFallbackActionsFromRecommendationLines(recommendationSignal.extractedLines, context)
    : [];
  const rawCards = Array.isArray(base.suggestionCards) ? base.suggestionCards : [];
  const suggestionCards = buildSuggestionCards(rawCards, [...normalizedActions, ...fallbackExtractedActions], {
    context,
    confidence: debug.confidence,
    route
  });
  const grounding = collectGrounding(base.grounding, context, {
    maxItems: 6,
    route
  });
  const nextAction = normalizeNextAction(base.nextAction, suggestionCards, {
    context,
    confidence: debug.confidence
  });
  const message = composeMessage(recommendationSignal.message, {
    context,
    route
  });

  return validateOutput({
    message,
    grounding,
    suggestionCards,
    nextAction,
    chips,
    actions: normalizedActions,
    debug
  }, {
    context,
    hasContext,
    route
  });
}

function composeMessage(message, { context, route }) {
  const source = String(message || "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .trim();
  if (!source) return composeFallbackMessage(context, route);

  const forbiddenInteraction = [
    /\bsources?\b/i,
    /\bwhich should i (add|edit|replace|pick)\b/i,
    /\boption [abc]\b/i,
    /\bchoose (a|b|c)\b/i
  ];

  const cleanedLines = source
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.replace(/^(?:[•\-*]|\d+[.)])\s+/, ""))
    .filter((line) => !forbiddenInteraction.some((pattern) => pattern.test(line)));

  const cleanedText = cleanedLines.join("\n")
    .replace(/\b(Here('|’)s|Based on your data|From your data)\b[:\s-]*/gi, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!cleanedText) return composeFallbackMessage(context, route);

  const paragraphCandidates = cleanedText
    .split(/(?:\n{2,}|(?<=[.!?])\s+(?=[A-Z\[]))/)
    .map((p) => p.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .map((p) => truncate(p, 220))
    .slice(0, 6);

  if (paragraphCandidates.length === 0) {
    return composeFallbackMessage(context, route);
  }

  return paragraphCandidates.join("\n\n");
}

function composeFallbackMessage(context, route) {
  const details = extractConcreteDetails(context);
  const routeText = nonEmptyString(route?.target);
  if (details.length >= 2) {
    return truncate(`I’m grounding this in ${details[0]} and ${details[1]}. I’ll keep this specific to your current Loom data.`, 220);
  }
  if (routeText) {
    return truncate(`I’m focusing this on ${routeText} using your current Loom context.`, 220);
  }
  return "I’m using your current Loom context for this response.";
}

function collectGrounding(input, context, { maxItems = 5, route = null } = {}) {
  const rawItems = Array.isArray(input) ? input : [];
  const normalized = [];
  const seen = new Set();

  for (const item of rawItems) {
    const section = truncate(nonEmptyString(item?.section), 64);
    const field = truncate(nonEmptyString(item?.field), 96);
    const timestamp = normalizeGroundingTimestamp(item?.timestamp);
    if (!section || !field) continue;
    const key = `${section.toLowerCase()}|${field.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    normalized.push({ section, field, timestamp });
    if (normalized.length >= maxItems) break;
  }

  const fallback = buildFallbackGrounding(context, route);
  for (const item of fallback) {
    if (normalized.length >= maxItems) break;
    const key = `${item.section.toLowerCase()}|${item.field.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    normalized.push(item);
  }
  return normalized.slice(0, maxItems);
}

function buildFallbackGrounding(context, route) {
  const items = [];
  const add = (section, field, timestamp) => {
    if (!section || !field) return;
    items.push({
      section: truncate(String(section), 64),
      field: truncate(String(field), 96),
      timestamp: normalizeGroundingTimestamp(timestamp)
    });
  };

  if (route?.id === 7 && nonEmptyString(context?.drivingForce?.vision)) {
    add("Purpose", "drivingForce.vision", context?.sectionTimestamps?.purpose);
  }
  if (route?.id === 8) {
    if (nonEmptyString(context?.drivingForce?.vision)) {
      add("Purpose", "drivingForce.vision", context?.sectionTimestamps?.purpose);
    }
    if (nonEmptyString(context?.drivingForce?.purpose)) {
      add("Purpose", "drivingForce.purpose", context?.sectionTimestamps?.purpose);
    }
    if (Array.isArray(context?.drivingForce?.passions) && context.drivingForce.passions.length > 0) {
      add("Purpose", "drivingForce.passions[0].title", context?.sectionTimestamps?.purpose);
    }
    if (Array.isArray(context?.fulfillmentCategories) && context.fulfillmentCategories.length > 0) {
      add("Fulfillment", "fulfillmentCategories[0].name", context?.sectionTimestamps?.fulfillment);
    }
    if (Array.isArray(context?.activeOutcomes) && context.activeOutcomes.length > 0) {
      add("Goals", "activeOutcomes[0].title", context?.sectionTimestamps?.outcomes);
    }
    if (Array.isArray(context?.currentWeekActionBlocks) && context.currentWeekActionBlocks.length > 0) {
      add("Action Blocks", "currentWeekActionBlocks[0].title", context?.sectionTimestamps?.actionBlocks);
    }
    if (context?.capture && Number.isFinite(Number(context.capture.totalCount))) {
      add("Capture", "capture.totalCount", context?.sectionTimestamps?.capture);
    }
    if (nonEmptyString(context?.diagnostic?.rootCause)) {
      add("Diagnostic", "diagnostic.rootCause", context?.sectionTimestamps?.diagnostic);
    }
  }
  if (route?.id === 6 && Array.isArray(context?.drivingForce?.passions) && context.drivingForce.passions.length > 0) {
    add("Purpose", "drivingForce.passions[0].title", context?.sectionTimestamps?.purpose);
  }
  if ([1, 2, 3].includes(route?.id) && Array.isArray(context?.fulfillmentCategories) && context.fulfillmentCategories.length > 0) {
    add("Fulfillment", "fulfillmentCategories[0].name", context?.sectionTimestamps?.fulfillment);
    add("Fulfillment", "fulfillmentCategories[0].mission", context?.sectionTimestamps?.fulfillment);
  }
  if ([4, 5].includes(route?.id) && Array.isArray(context?.activeOutcomes) && context.activeOutcomes.length > 0) {
    add("Goals", "activeOutcomes[0].title", context?.sectionTimestamps?.outcomes);
    add("Goals", "activeOutcomes[0].progressSummary", context?.sectionTimestamps?.outcomes);
  }

  if (nonEmptyString(context?.drivingForce?.purpose)) {
    add("Purpose", "drivingForce.purpose", context?.sectionTimestamps?.purpose);
  }
  if (Array.isArray(context?.currentWeekActionBlocks) && context.currentWeekActionBlocks.length > 0) {
    add("Action Blocks", "currentWeekActionBlocks[0].title", context?.sectionTimestamps?.actionBlocks);
  }
  if (context?.capture && Number.isFinite(Number(context.capture.totalCount))) {
    add("Capture", "capture.totalCount", context?.sectionTimestamps?.capture);
  }
  if (Array.isArray(context?.dataInventory) && context.dataInventory.length > 0) {
    add("Data Inventory", "dataInventory[0].title", context?.generatedAt);
  }
  if (Array.isArray(context?.appGuide) && context.appGuide.length > 0) {
    add("App Guide", "appGuide[0].title", context?.generatedAt);
  }

  return items;
}

function normalizeGroundingTimestamp(value) {
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return value.toISOString();
  }
  const text = String(value || "").trim();
  if (!text) return "";
  const parsed = new Date(text);
  if (!Number.isFinite(parsed.getTime())) return "";
  return parsed.toISOString();
}

function buildSuggestionCards(inputCards, inputActions, { context, confidence, route }) {
  const level = String(confidence || "").trim().toLowerCase();
  if (level === "low") return [];

  const normalizedCards = normalizeSuggestionCards(inputCards, context);
  if (normalizedCards.length > 0) return normalizedCards;

  const routeCards = buildRouteSuggestionCards(route, context);
  if (routeCards.length > 0) return routeCards;

  return actionsToSuggestionCards(inputActions, context);
}

function normalizeSuggestionCards(inputCards, context) {
  const source = Array.isArray(inputCards) ? inputCards : [];
  const cards = [];
  const seen = new Set();

  for (const card of source) {
    const title = truncate(nonEmptyString(card?.title), 120);
    if (!title) continue;
    const description = truncate(nonEmptyString(card?.description) || "Suggestion options", 180);
    const options = normalizeSuggestionOptions(card?.options, context);
    if (options.length === 0) continue;
    const id = truncate(nonEmptyString(card?.id) || slug(title), 72);
    const key = `${title.toLowerCase()}|${options.map((opt) => `${opt.type}:${JSON.stringify(opt.payload)}`).join("|")}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cards.push({ id, title, description, options: options.slice(0, 3) });
    if (cards.length >= 3) break;
  }
  return cards;
}

function normalizeSuggestionOptions(inputOptions, context) {
  const source = Array.isArray(inputOptions) ? inputOptions : [];
  const options = [];
  const seen = new Set();
  const labels = ["A", "B", "C"];

  for (let i = 0; i < source.length; i += 1) {
    const option = source[i];
    const type = nonEmptyString(option?.type);
    if (!ACTION_WHITELIST.has(type)) continue;
    const payload = normalizeActionPayload(type, option?.payload, context);
    if (!payload) continue;
    const title = truncate(nonEmptyString(option?.title), 120);
    if (!title) continue;
    const key = `${type}|${JSON.stringify(payload)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    options.push({
      id: truncate(nonEmptyString(option?.id) || `${type}-${options.length + 1}`, 72),
      label: labels[options.length] || "C",
      title,
      type,
      payload
    });
    if (options.length >= 3) break;
  }
  return options;
}

function actionsToSuggestionCards(actions, context) {
  const normalized = normalizeActions(actions, { confidence: "high", context });
  if (normalized.length === 0) return [];
  return normalized.slice(0, 3).map((action, index) => ({
    id: `card-${index + 1}`,
    title: truncate(action.title, 120),
    description: "Apply this Loom suggestion",
    options: [{
      id: action.id,
      label: "A",
      title: truncate(action.title, 120),
      type: action.type,
      payload: action.payload
    }]
  }));
}

function buildRouteSuggestionCards(route, context) {
  if (!route || typeof route !== "object") return [];
  const target = nonEmptyString(route.target);
  const categoryId = resolveCategoryIdFromRouteTarget(target, context);

  if (route.id === 1 && categoryId) {
    const options = [
      { title: "10-minute daily focus sprint", type: "addLittleWin", payload: { categoryId, activity: "10-minute focused sprint", appleHealthEligible: false } },
      { title: "15-minute cleanup and reset", type: "addLittleWin", payload: { categoryId, activity: "15-minute reset and cleanup", appleHealthEligible: false } },
      { title: "20-minute completion block", type: "addLittleWin", payload: { categoryId, activity: "20-minute completion block", appleHealthEligible: false } }
    ];
    return [buildCardFromOptions(`Little Wins for ${target || "this area"}`, "Pick one short daily action.", options, context)];
  }

  if (route.id === 2 && categoryId) {
    const options = [
      { title: "Mission option A", type: "updateFulfillmentMission", payload: { categoryId, text: `I strengthen ${target} with steady weekly execution and clear standards.` } },
      { title: "Mission option B", type: "updateFulfillmentMission", payload: { categoryId, text: `I use ${target} to build consistency, reduce stress, and increase follow-through.` } },
      { title: "Mission option C", type: "updateFulfillmentMission", payload: { categoryId, text: `I treat ${target} as a system I can improve through simple repeatable actions.` } }
    ];
    return [buildCardFromOptions(`Mission options for ${target || "this area"}`, "Choose one mission rewrite.", options, context)];
  }

  if (route.id === 3) {
    const options = [
      { title: "Identity option A", type: "addPlanSuggestion", payload: { text: `Identity: I am consistent in ${target || "this area"}.` } },
      { title: "Identity option B", type: "addPlanSuggestion", payload: { text: `Identity: I finish what I start in ${target || "this area"}.` } },
      { title: "Identity option C", type: "addPlanSuggestion", payload: { text: `Identity: I prioritize high-leverage actions in ${target || "this area"}.` } }
    ];
    return [buildCardFromOptions(`Identity options for ${target || "this area"}`, "Add one identity suggestion to Capture.", options, context)];
  }

  if (route.id === 4) {
    const goalName = target || "this goal";
    const options = [
      { title: "Next step A", type: "addPlanSuggestion", payload: { text: `Next step for ${goalName}: define one measurable checkpoint for this week.` } },
      { title: "Next step B", type: "addPlanSuggestion", payload: { text: `Next step for ${goalName}: schedule one focused 30-minute execution block.` } },
      { title: "Next step C", type: "addPlanSuggestion", payload: { text: `Next step for ${goalName}: identify and remove one blocker before execution.` } }
    ];
    return [buildCardFromOptions(`Next steps for ${goalName}`, "Choose one immediate step.", options, context)];
  }

  if (route.id === 5) {
    const goalName = target || "this goal";
    const options = [
      { title: "Plan option A", type: "addPlanSuggestion", payload: { text: `Plan for ${goalName}: define 3 checkpoints across this week.` } },
      { title: "Plan option B", type: "addPlanSuggestion", payload: { text: `Plan for ${goalName}: batch similar tasks into two focused sessions.` } },
      { title: "Plan option C", type: "addPlanSuggestion", payload: { text: `Plan for ${goalName}: set one daily minimum action and review each evening.` } }
    ];
    return [buildCardFromOptions(`Plan options for ${goalName}`, "Choose one short plan template.", options, context)];
  }

  if (route.id === 6) {
    const passionType = normalizePassionType(target || "love");
    const options = [
      { title: "Passion option A", type: "addPassionItem", payload: { passionType, text: `Building consistent progress in ${passionType} aligned work.` } },
      { title: "Passion option B", type: "addPassionItem", payload: { passionType, text: `Creating calm structure in daily planning and execution.` } },
      { title: "Passion option C", type: "addPassionItem", payload: { passionType, text: `Learning through weekly experiments with clear follow-through.` } }
    ];
    return [buildCardFromOptions(`New passions for ${passionType}`, "Choose one passion to add.", options, context)];
  }

  if (route.id === 7) {
    const options = [
      { title: "Vision option A", type: "updatePurposeVision", payload: { text: "I build a life where my daily actions match my long-term values and commitments." } },
      { title: "Vision option B", type: "updatePurposeVision", payload: { text: "I create steady progress across the areas that matter most by finishing the right work each week." } },
      { title: "Vision option C", type: "updatePurposeVision", payload: { text: "I live with clear direction, focused execution, and systems that support meaningful growth." } }
    ];
    return [buildCardFromOptions("Purpose Vision options", "Choose one vision rewrite.", options, context)];
  }

  return [];
}

function buildCardFromOptions(title, description, options, context) {
  const normalizedOptions = normalizeSuggestionOptions(options.map((option, index) => ({
    id: `${slug(title)}-${index + 1}`,
    label: String.fromCharCode(65 + index),
    title: option.title,
    type: option.type,
    payload: option.payload
  })), context);
  return {
    id: slug(title),
    title: truncate(title, 120),
    description: truncate(description, 180),
    options: normalizedOptions
  };
}

function resolveCategoryIdFromRouteTarget(target, context) {
  if (!target) return firstCategoryIdFromContext(context);
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const found = categories.find(
    (item) => String(item?.name || "").trim().toLowerCase() === target.toLowerCase()
  );
  const id = nonEmptyString(found?.id);
  return /^[0-9a-f-]{36}$/i.test(id) ? id : firstCategoryIdFromContext(context);
}

function normalizeNextAction(input, suggestionCards, { context, confidence }) {
  if (String(confidence || "").toLowerCase() === "low") return null;
  const option = input && typeof input === "object" ? input : null;
  if (option) {
    const type = nonEmptyString(option.type);
    if (ACTION_WHITELIST.has(type)) {
      const payload = normalizeActionPayload(type, option.payload, context);
      const title = truncate(nonEmptyString(option.title), 120);
      if (payload && title) {
        return {
          id: truncate(nonEmptyString(option.id) || `${type}-next`, 72),
          title,
          type,
          payload
        };
      }
    }
  }
  const firstOption = Array.isArray(suggestionCards) && suggestionCards.length > 0
    ? suggestionCards[0]?.options?.[0]
    : null;
  if (!firstOption) return null;
  return {
    id: truncate(nonEmptyString(firstOption.id) || "next-1", 72),
    title: truncate(nonEmptyString(firstOption.title), 120),
    type: nonEmptyString(firstOption.type),
    payload: firstOption.payload && typeof firstOption.payload === "object" ? firstOption.payload : {}
  };
}

function validateOutput(output, { context, hasContext, route }) {
  const message = composeMessage(output?.message, { context, route });
  const sanitizedMessage = removeInteractionText(message);
  const safeMessage = containsSuspiciousFactPattern(sanitizedMessage, context)
    ? composeFallbackMessage(context, route)
    : sanitizedMessage;

  let suggestionCards = Array.isArray(output?.suggestionCards) ? output.suggestionCards : [];
  if (suggestionCards.length === 0 && Array.isArray(output?.actions) && output.actions.length > 0) {
    suggestionCards = actionsToSuggestionCards(output.actions, context);
  }
  suggestionCards = suggestionCards.slice(0, 3);

  const flattenedActions = flattenSuggestionCardsToActions(suggestionCards, context);
  const mergedActions = mergeActions(flattenedActions, output?.actions, context);

  const grounding = collectGrounding(output?.grounding, context, {
    maxItems: hasContext ? 6 : 2,
    route
  });

  const nextAction = normalizeNextAction(output?.nextAction, suggestionCards, {
    context,
    confidence: output?.debug?.confidence || "medium"
  });

  return {
    message: truncate(safeMessage, 2400),
    grounding,
    suggestionCards,
    nextAction,
    chips: Array.isArray(output?.chips) ? output.chips.slice(0, 4) : [],
    actions: mergedActions,
    debug: output?.debug || {
      usedContext: Boolean(hasContext),
      confidence: hasContext ? "medium" : "low",
      evidence: hasContext ? extractEvidencePathsFromContext(context, 2) : []
    }
  };
}

function flattenSuggestionCardsToActions(cards, context) {
  const actions = [];
  const source = Array.isArray(cards) ? cards : [];
  for (const card of source) {
    const options = Array.isArray(card?.options) ? card.options : [];
    for (const option of options) {
      const type = nonEmptyString(option?.type);
      if (!ACTION_WHITELIST.has(type)) continue;
      const payload = normalizeActionPayload(type, option?.payload, context);
      const title = truncate(nonEmptyString(option?.title), 120);
      if (!payload || !title) continue;
      actions.push({
        id: truncate(nonEmptyString(option?.id) || `${type}-${actions.length + 1}`, 72),
        title,
        type,
        payload
      });
      if (actions.length >= 8) return actions;
    }
  }
  return actions;
}

function mergeActions(primary, secondary, context) {
  const first = normalizeActions(primary, { confidence: "high", context });
  const second = normalizeActions(secondary, { confidence: "high", context });
  const merged = [];
  const seen = new Set();
  for (const action of [...first, ...second]) {
    const key = `${action.type}|${JSON.stringify(action.payload)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(action);
    if (merged.length >= 8) break;
  }
  return merged;
}

function removeInteractionText(message) {
  const text = String(message || "").trim();
  if (!text) return "";
  const lines = text.split(/\n+/).map((line) => line.trim()).filter(Boolean);
  const blocked = [
    /\bsources?\b/i,
    /\bwhich should i (add|edit|replace|choose)\b/i,
    /\boption [abc]\b/i,
    /\bchoose (a|b|c)\b/i
  ];
  const kept = lines.filter((line) => !blocked.some((pattern) => pattern.test(line)));
  return kept.join("\n\n").trim();
}

function containsSuspiciousFactPattern(message, context) {
  const text = String(message || "");
  if (!text) return false;
  const hardClaims = [
    /\byou (completed|finished|hit|missed)\b/i,
    /\byour (completion|streak|score|progress) (is|was)\b/i
  ];
  if (!hardClaims.some((pattern) => pattern.test(text))) return false;
  const allowed = buildAllowedNumberTokenSet(context);
  const found = text.match(/\b\d+(?:\.\d+)?\b/g) || [];
  return found.some((token) => !allowed.has(token));
}

function buildAllowedNumberTokenSet(context) {
  const tokens = new Set();
  const collect = (value) => {
    const text = String(value || "");
    const matches = text.match(/\b\d+(?:\.\d+)?\b/g) || [];
    for (const token of matches) tokens.add(token);
  };
  collect(context?.capture?.totalCount);
  collect(context?.capture?.quickCompletionsLast7Days);
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  for (const item of categories) collect(item?.weeklyScore);
  const goals = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  for (const item of goals) collect(item?.progressSummary);
  const blocks = Array.isArray(context?.currentWeekActionBlocks) ? context.currentWeekActionBlocks : [];
  for (const item of blocks) collect(item?.completionRatio);
  return tokens;
}

function stripRecommendationContentFromMessage(message) {
  const source = String(message || "").trim();
  if (!source) {
    return { message: "", hadRecommendations: false, strippedCount: 0, extractedLines: [] };
  }

  const rawLines = source.split(/\n+/).map((line) => line.trim()).filter(Boolean);
  const kept = [];
  const removed = [];
  for (const line of rawLines) {
    if (isRecommendationLine(line)) {
      removed.push(line);
    } else {
      kept.push(line);
    }
  }

  let cleaned = kept.join("\n\n").trim();
  if (!cleaned && removed.length > 0) {
    cleaned = "I prepared suggestions below.";
  }
  return {
    message: cleaned,
    hadRecommendations: removed.length > 0,
    strippedCount: removed.length,
    extractedLines: removed
  };
}

function isRecommendationLine(line) {
  const value = String(line || "").trim().toLowerCase();
  if (!value) return false;
  if (/^[a-z]\s*[\)\.\:\-]\s+/.test(value)) return true;
  if (/^\d+\.\s+/.test(value)) return true;
  if (value.startsWith("try ") || value.startsWith("you should ") || value.startsWith("i suggest ")) return true;
  const recommendationPatterns = [
    /\b(add|edit|improve|update|replace|create|rewrite|refine|change|remove)\b/,
    /\b(new mission|new identity|little win|next step|plan for)\b/,
    /\b(i can|i could|i recommend)\b.*\b(add|edit|improve|update|replace|create)\b/
  ];
  return recommendationPatterns.some((pattern) => pattern.test(value));
}

function inferFallbackActionsFromRecommendationLines(lines, context) {
  const source = Array.isArray(lines) ? lines : [];
  const cleaned = source
    .map((line) => String(line || "").replace(/^[•\-]\s*/, "").trim())
    .filter(Boolean)
    .slice(0, 4);
  if (cleaned.length === 0) return [];

  const categoryId = firstCategoryIdFromContext(context);
  const generated = [];
  for (let i = 0; i < cleaned.length; i += 1) {
    const line = truncate(cleaned[i], 160);
    const lower = line.toLowerCase();
    if (/\bmission\b/.test(lower) && categoryId) {
      generated.push({
        id: `fallback-updateFulfillmentMission-${i + 1}`,
        title: "Update mission",
        type: "updateFulfillmentMission",
        payload: { categoryId, text: line }
      });
      continue;
    }
    if (/\bidentity\b/.test(lower) && categoryId) {
      generated.push({
        id: `fallback-addPlanSuggestion-${i + 1}`,
        title: "Identity suggestion",
        type: "addPlanSuggestion",
        payload: { text: line }
      });
      continue;
    }
    generated.push({
      id: `fallback-addPlanSuggestion-${i + 1}`,
      title: "Suggestion",
      type: "addPlanSuggestion",
      payload: { text: line }
    });
  }
  return normalizeActions(generated, {
    confidence: "medium",
    context
  });
}

function firstCategoryIdFromContext(context) {
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const first = categories.find((item) => nonEmptyString(item?.id));
  const id = nonEmptyString(first?.id);
  return /^[0-9a-f-]{36}$/i.test(id) ? id : "";
}

function normalizeChips(input, context) {
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();

  for (const item of source) {
    const title = String(item?.title || "").replace(/\s+/g, " ").trim();
    const prompt = String(item?.prompt || "").replace(/\s+/g, " ").trim();
    if (!title || !prompt) continue;
    const id = String(item?.id || slug(title));
    const key = `${title.toLowerCase()}|${prompt.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    cleaned.push({
      id: truncate(id, 64),
      title: truncate(title, 64),
      prompt: truncate(prompt, 180)
    });
    if (cleaned.length >= 4) break;
  }

  if (cleaned.length >= 2) return cleaned;
  return buildDefaultLoomChips(context).slice(0, 3);
}

function normalizeDebug(input, context, hasContext) {
  const confidenceRaw = String(input?.confidence || "").trim().toLowerCase();
  const confidence = ["high", "medium", "low"].includes(confidenceRaw)
    ? confidenceRaw
    : hasContext
      ? "medium"
      : "low";
  const evidenceInput = Array.isArray(input?.evidence) ? input.evidence : [];
  const evidence = uniqueOrdered(
    evidenceInput
      .map((item) => String(item || "").trim())
      .filter(Boolean)
  ).slice(0, 8);
  const usedContext = Boolean(input?.usedContext) && hasContext;
  const repairedEvidence =
    usedContext && evidence.length < 2
      ? uniqueOrdered([...evidence, ...extractEvidencePathsFromContext(context, 2)]).slice(0, 8)
      : evidence;
  return {
    usedContext,
    confidence,
    evidence: repairedEvidence
  };
}

function extractEvidencePathsFromContext(context, maxCount = 2) {
  const paths = [];
  if (nonEmptyString(context?.drivingForce?.vision)) paths.push("drivingForce.vision");
  if (nonEmptyString(context?.drivingForce?.purpose)) paths.push("drivingForce.purpose");
  if (Array.isArray(context?.fulfillmentCategories) && context.fulfillmentCategories.length > 0) {
    paths.push("fulfillmentCategories[0].name");
  }
  if (Array.isArray(context?.activeOutcomes) && context.activeOutcomes.length > 0) {
    paths.push("activeOutcomes[0].title");
  }
  if (Array.isArray(context?.currentWeekActionBlocks) && context.currentWeekActionBlocks.length > 0) {
    paths.push("currentWeekActionBlocks[0].title");
  }
  if (nonEmptyString(context?.diagnostic?.rootCause)) paths.push("diagnostic.rootCause");
  if (nonEmptyString(context?.diagnostic?.nextDirection)) paths.push("diagnostic.nextDirection");
  return paths.slice(0, maxCount);
}

function extractConcreteDetails(context) {
  const details = [];
  const purposeVision = nonEmptyString(context?.drivingForce?.vision);
  const purpose = nonEmptyString(context?.drivingForce?.purpose);
  if (purposeVision) details.push(`your purpose vision "${truncate(purposeVision, 46)}"`);
  if (purpose) details.push(`your purpose "${truncate(purpose, 46)}"`);
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  if (categories.length > 0) {
    details.push(`fulfillment area "${truncate(String(categories[0]?.name || ""), 34)}"`);
  }
  const outcomes = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  if (outcomes.length > 0) {
    details.push(`outcome "${truncate(String(outcomes[0]?.title || ""), 40)}"`);
  }
  return uniqueOrdered(details).slice(0, 4);
}

const ACTION_WHITELIST = new Set([
  "updatePurposeVision",
  "addPassionItem",
  "updateFulfillmentMission",
  "addLittleWin",
  "createOutcome",
  "createCaptureAction",
  "addPlanSuggestion"
]);

function normalizeActions(input, { confidence, context }) {
  if (String(confidence || "").toLowerCase() === "low") return [];
  const source = Array.isArray(input) ? input : [];
  const cleaned = [];
  const seen = new Set();

  for (const action of source) {
    const type = String(action?.type || "").trim();
    if (!ACTION_WHITELIST.has(type)) continue;

    const title = String(action?.title || "").replace(/\s+/g, " ").trim();
    const payload = normalizeActionPayload(type, action?.payload, context);
    if (!title || !payload) continue;
    const id = String(action?.id || `${type}-${cleaned.length + 1}`).trim();
    const dedupeKey = `${type}|${JSON.stringify(payload)}`;
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    cleaned.push({
      id: truncate(id, 72),
      title: truncate(title, 120),
      type,
      payload
    });
    if (cleaned.length >= 4) break;
  }

  return cleaned;
}

function normalizeActionPayload(type, payload, context) {
  const src = payload && typeof payload === "object" ? payload : {};
  const text = nonEmptyString(src.text);
  const categoryId = nonEmptyString(src.categoryId || src.categoryID);
  const categoryName = nonEmptyString(src.categoryName || src.category);

  switch (type) {
    case "updatePurposeVision":
      return text ? { text: truncate(text, 260) } : null;
    case "addPassionItem": {
      const passionType = String(src.passionType || src.emotion || "").trim().toLowerCase();
      if (!["love", "vows", "thrill", "hate"].includes(passionType) || !text) return null;
      return { passionType, text: truncate(text, 120) };
    }
    case "updateFulfillmentMission": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      if (!validCategoryId || !text) return null;
      return { categoryId: validCategoryId, text: truncate(text, 240) };
    }
    case "addLittleWin": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const activity = nonEmptyString(src.activity || src.text);
      if (!validCategoryId || !activity) return null;
      const eligibleRaw = src.appleHealthEligible;
      const appleHealthEligible =
        typeof eligibleRaw === "boolean"
          ? eligibleRaw
          : String(eligibleRaw || "").toLowerCase() === "true";
      return {
        categoryId: validCategoryId,
        activity: truncate(activity, 140),
        appleHealthEligible
      };
    }
    case "createOutcome": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const title = nonEmptyString(src.title || src.text);
      if (!validCategoryId || !title) return null;
      const measurable =
        typeof src.measurable === "boolean"
          ? src.measurable
          : String(src.measurable || "").toLowerCase() === "true";
      const unit = nonEmptyString(src.unit);
      return {
        categoryId: validCategoryId,
        title: truncate(title, 120),
        measurable,
        unit: unit ? truncate(unit, 24) : ""
      };
    }
    case "createCaptureAction":
    case "addPlanSuggestion":
      return text ? { text: truncate(text, 160) } : null;
    default:
      return null;
  }
}

function normalizeCategoryId(categoryId, categoryName, context) {
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(categoryId)) {
    return categoryId;
  }
  if (!categoryName) return "";
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const found = categories.find(
    (item) => String(item?.name || "").trim().toLowerCase() === categoryName.toLowerCase()
  );
  const mapped = String(found?.id || "").trim();
  return /^[0-9a-f-]{36}$/i.test(mapped) ? mapped : "";
}

function slug(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
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

export const __test = {
  resolveChipIntentRoute,
  composeMessage,
  collectGrounding,
  buildSuggestionCards,
  validateOutput,
  sanitizeLoomChatResponse
};
