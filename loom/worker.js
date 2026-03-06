const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_CHAT_MODEL = "gpt-5.2";
const DIAGNOSTIC_CACHE_TTL_SECONDS = 60 * 60 * 24 * 14; // 14 days
const CHAT_CACHE_TTL_SECONDS = 60 * 10; // 10 minutes
const DIAGNOSTIC_LOOM_MECHANICS_CONTEXT = [
  "Loom reduces stress by narrowing attention. Instead of managing everything at once, the system helps the user focus on one clear result at a time.",
  "Loom organizes life into a simple flow: Purpose -> Fulfillment Areas -> Goals -> Action Blocks. Each level clarifies what matters and filters what comes next.",
  "Goals define the result that matters most right now. Action Blocks turn that result into a short, prioritized set of actions so the user knows where to start and when they are done.",
  "This structure reduces overthinking by removing competing choices in the moment and giving the user a clear order of focus across the week and day.",
  "A good nextDirection should briefly explain the shift Loom introduces, such as clearer priority, one main outcome, fewer decisions during the day, or a simpler execution flow.",
  "Write in plain language describing how the user's day will feel different with this structure.",
  "Do not reference app screens or features the user cannot see. Avoid product marketing language."
];
const DIAGNOSTIC_QUESTIONNAIRE = [
  {
    key: "stress",
    question: "What's causing the most stress right now?",
    selection: "single",
    options: [
      "Too many priorities competing",
      "Feeling behind or disorganized",
      "Distractions are stealing my focus",
      "Work pressure",
      "Money pressure",
      "Low energy / health",
      "Relationship tension",
      "Not sure yet"
    ]
  },
  {
    key: "breaksFirst",
    question: "When you try to make progress, what usually breaks first?",
    selection: "single",
    options: [
      "I don't start",
      "I start, then lose momentum",
      "I get distracted",
      "I overthink it",
      "I don't finish what I start",
      "I'm not sure"
    ]
  },
  {
    key: "areas",
    question: "Which life areas should Loom help you manage long-term?",
    selection: "multi",
    minSelections: 3,
    maxSelections: 7,
    allowsCustom: true,
    options: [
      "Career & Business",
      "Faith & Spirituality",
      "Wealth & Finance",
      "Learning & Education",
      "Love & Relationships",
      "Health & Energy",
      "Lifestyle & Experiences",
      "Mindset & Resilience",
      "Service & Impact",
      "Home & Life"
    ]
  },
  {
    key: "planningStyle",
    question: "Most days, you...",
    selection: "single",
    options: [
      "React to what's urgent",
      "Keep a simple to-do list",
      "Plan, but get off track",
      "Plan and follow through consistently",
      "It depends on the day"
    ]
  },
  {
    key: "firstChange",
    question: "If Loom works, what changes first?",
    selection: "single",
    options: [
      "I feel in control (less stress)",
      "I know what matters (clear direction)",
      "I follow through (consistency)",
      "I make faster progress on big goals",
      "I feel balanced across life"
    ]
  }
];
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

    const diagnosticPromptContext = buildDiagnosticPromptContext(normalizedDiagnostic);
    const systemPrompt = [
      "You generate first-signup diagnostic insights for Loom.",
      "Write it as if I was a 5th grader: simple words, short sentences, no jargon.",
      "",
      "Hard rules:",
      "- Use ONLY the provided diagnostic questionnaire, answer options, and chosen answers as grounding.",
      "- Analyze the meaning of the chosen answer in the context of the full option set for that question.",
      "- Do not use any external context or generic productivity advice.",
      "- Do not repeat or closely paraphrase the exact option text the user picked.",
      "- Do not praise, hype, reward, or motivate. No cheerleading.",
      "- Do not list, rename, or restate the selected 'areas'. You may refer to them only as 'different parts of life'.",
      "- For nextDirection, use the provided Loom mechanics context so the structural shift matches how Loom actually works.",
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
        anyOf: [
          {
            type: "object",
            additionalProperties: false,
            properties: {
              rootCause: { type: "string" },
              nextDirection: { type: "string" },
              error: { type: "string" }
            },
            required: ["rootCause", "nextDirection"]
          },
          {
            type: "object",
            additionalProperties: false,
            properties: {
              rootCause: { type: "string" },
              nextDirection: { type: "string" },
              error: { type: "string" }
            },
            required: ["error"]
          }
        ]
      }
    };

    const result = await callOpenAIResponsesJSON({
      apiKey,
      model: "gpt-5.1",
      systemPrompt,
      userPayload: {
        diagnostic: normalizedDiagnostic,
        diagnosticPromptContext,
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
    const diagnosticDebugEnabled =
      env.DEBUG_DIAGNOSTIC === "1" || nonEmptyString(client?.screen) === "diagnostic_insights_debug";

    let responseBody;
    let diagnosticDebug = null;
    if (result.error) {
      responseBody = buildDeterministicDiagnosticInsights(normalizedDiagnostic);
      diagnosticDebug = {
        fallbackReason: "upstream_error",
        upstreamError: result.error,
        upstreamDetails: result.details || null
      };
    } else {
      const parsed = result.json;
      const signaledInsufficient = parsed && typeof parsed.error === "string" && parsed.error.trim() !== "";
      const rootCause = coerceInsightText(parsed?.rootCause);
      const nextDirection = coerceInsightText(parsed?.nextDirection);
      if (signaledInsufficient || !isValidInsightText(rootCause) || !isValidInsightText(nextDirection)) {
        responseBody = buildDeterministicDiagnosticInsights(normalizedDiagnostic);
        diagnosticDebug = {
          fallbackReason: signaledInsufficient
            ? "insufficient_signal"
            : !rootCause
              ? "invalid_root_cause"
              : !nextDirection
                ? "invalid_next_direction"
                : "post_validation_failed",
          parsedResponse: parsed || null,
          normalizedCandidate: {
            rootCause,
            nextDirection
          }
        };
      } else {
        responseBody = { rootCause, nextDirection };
        diagnosticDebug = {
          fallbackReason: null,
          parsedResponse: parsed || null,
          normalizedCandidate: {
            rootCause,
            nextDirection
          }
        };
      }
    }
    if (diagnosticUsage) {
      responseBody.usage = diagnosticUsage;
    }

    if (!diagnosticDebugEnabled) {
      const cacheResponse = new Response(JSON.stringify(responseBody), {
        status: 200,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": `public, max-age=0, s-maxage=${DIAGNOSTIC_CACHE_TTL_SECONDS}`
        }
      });
      await caches.default.put(cacheKey, cacheResponse);
    }

    if (diagnosticDebugEnabled) {
      const evidence = [];
      if (diagnosticDebug?.fallbackReason) {
        evidence.push(`fallbackReason: ${diagnosticDebug.fallbackReason}`);
      } else {
        evidence.push("fallbackReason: none");
      }
      if (diagnosticDebug?.normalizedCandidate?.rootCause) {
        evidence.push(`normalized rootCause: ${truncate(diagnosticDebug.normalizedCandidate.rootCause, 160)}`);
      }
      if (diagnosticDebug?.normalizedCandidate?.nextDirection) {
        evidence.push(`normalized nextDirection: ${truncate(diagnosticDebug.normalizedCandidate.nextDirection, 160)}`);
      }
      if (diagnosticDebug?.upstreamError) {
        evidence.push(`upstreamError: ${truncate(String(diagnosticDebug.upstreamError), 160)}`);
      }
      responseBody.debug = {
        usedFields: ["stress", "breaksFirst", "areas", "planningStyle", "firstChange"],
        model: "gpt-5.1",
        latencyMs: Date.now() - startedAt,
        evidence,
        ...diagnosticDebug
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
  if (intent === "plan_result_autowrite") {
    return handlePlanResultAutoWrite({ request, env, apiKey, payload });
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

  // All remaining intents use the Loom chat pipeline.
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

async function handlePlanResultAutoWrite({ request, env, apiKey, payload }) {
  const latestUserMessage = extractLatestUserMessage(payload).trim();
  const parsedInput = parsePlanResultAutoWriteInput(latestUserMessage);
  const actions = normalizePlanResultActions(parsedInput.actions);
  if (actions.length === 0) {
    return json(
      buildPlanResultAutoWriteResponse({
        message: "",
        confidence: "low",
        evidence: ["No valid actions were provided for inference."]
      }),
      200,
      corsHeaders(request)
    );
  }

  const schema = {
    name: "plan_result_autowrite_response",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        message: { type: "string" }
      },
      required: ["message"]
    }
  };

  const systemPrompt = [
    "You generate Loom Plan Step 4 Result AutoWrite output.",
    "Return a short abstract result that all provided actions contribute to.",
    "Hard rules:",
    "- Use ONLY the provided actions as grounding.",
    "- Output a single phrase of 2-6 words.",
    "- Keep it abstract and outcome-focused, not a task list or instruction.",
    "- No quotes, bullets, colons, or trailing punctuation.",
    "Output JSON only:",
    '{"message":"2-6 word abstract shared outcome phrase"}'
  ].join("\n");

  const userPayload = {
    areaName: nonEmptyString(parsedInput.areaName) || "",
    actions
  };

  const preferredModel = "gpt-5-mini";
  const modelCandidates = [preferredModel];

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
      maxOutputTokens: 120,
      timeoutMs: 20000,
      reasoningEffort: "none",
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

  const modelMessage = normalizePlanResultPhrase(result?.json?.message || "");
  const heuristicMessage = heuristicPlanResultFromActions(actions, parsedInput.areaName);
  const suggestion = isAcceptablePlanResultPhrase(modelMessage)
    ? modelMessage
    : normalizePlanResultPhrase(heuristicMessage);
  const confidence = isAcceptablePlanResultPhrase(modelMessage)
    ? "high"
    : "medium";
  const evidence = isAcceptablePlanResultPhrase(modelMessage)
    ? ["Generated from provided action list."]
    : ["Used deterministic action-keyword fallback after model output normalization."];

  const response = buildPlanResultAutoWriteResponse({
    message: suggestion,
    confidence,
    evidence
  });
  const usage = normalizeResponsesUsage(result?.usage, usedModel);
  if (usage) response.usage = usage;
  return json(response, 200, corsHeaders(request));
}

async function handleLoomAIChat({ request, env, apiKey, payload }) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const client = payload?.client && typeof payload.client === "object" ? payload.client : {};
  const normalizedIntent = String(client.intent || "").trim().toLowerCase();
  const isAutoGroupIntent = normalizedIntent === "autogroup_plan";
  const rawContext = payload?.context && typeof payload.context === "object" ? payload.context : {};
  const contextIsPacked = isIntentContextPack(rawContext);
  const context = normalizedIntent === "autogroup_plan"
    ? compactAutoGroupContext(rawContext)
    : contextIsPacked
      ? legacyContextFromIntentPack(rawContext)
    : rawContext;
  const shouldForceMiniModel = normalizedIntent === "autogroup_plan";
  const latestUserMessage = extractLatestUserMessage(payload).trim();
  const hasContext = contextIsPacked
    ? hasMeaningfulPackedLoomContext(rawContext) || hasMeaningfulLoomContext(context)
    : hasMeaningfulLoomContext(context);
  const unrelatedPrompt = isLikelyUnrelatedPrompt(latestUserMessage);
  const chipIntentRoute = resolveChipIntentRoute(latestUserMessage);
  const heuristicPromptType = detectHeuristicPromptType(latestUserMessage);

  if (!latestUserMessage) {
    return json(
      safeChatFallback({
        hasContext,
        context,
        route: chipIntentRoute,
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
          route: chipIntentRoute,
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

  // Chip action routes are deterministic and should never block on upstream model latency.
  if (!isAutoGroupIntent && shouldUseDeterministicRouteResponse(chipIntentRoute)) {
    if (chipIntentRoute?.id === 8) {
      return json(
        buildBestUseLoomDeterministicResponse({
          hasContext,
          context,
          route: chipIntentRoute
        }),
        200,
        corsHeaders(request)
      );
    }
    return json(
      buildDeterministicRouteResponse({
        hasContext,
        context,
        route: chipIntentRoute,
        message: buildDeterministicRouteMessage(chipIntentRoute)
      }),
      200,
      corsHeaders(request)
    );
  }

  // Freeform prompts that map cleanly to known Loom workflows should not depend on upstream latency.
  if (!isAutoGroupIntent && !chipIntentRoute && heuristicPromptType) {
    return json(
      buildDeterministicHeuristicPromptResponse({
        hasContext,
        context,
        promptType: heuristicPromptType,
        latestUserMessage
      }),
      200,
      corsHeaders(request)
    );
  }

  const shouldPreferFastModel = !chipIntentRoute;
  const preferredModel = shouldForceMiniModel || shouldPreferFastModel
    ? "gpt-5-mini"
    : (nonEmptyString(env.OPENAI_MODEL) || DEFAULT_CHAT_MODEL);
  const modelCandidates = shouldForceMiniModel || shouldPreferFastModel
    ? ["gpt-5-mini"]
    : uniqueOrdered(
      [preferredModel, "gpt-5-mini"]
        .map((value) => nonEmptyString(value))
        .filter(Boolean)
    ).slice(0, 2);
  const actionPayloadSchema = {
    anyOf: [
      {
        type: "object",
        additionalProperties: false,
        properties: {
          text: { type: "string" }
        },
        required: ["text"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          passionType: { type: "string", enum: ["love", "vows", "thrill", "hate"] },
          text: { type: "string" }
        },
        required: ["passionType", "text"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          categoryId: { type: "string" },
          text: { type: "string" }
        },
        required: ["categoryId", "text"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          categoryId: { type: "string" },
          identity: { type: "string" }
        },
        required: ["categoryId", "identity"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          categoryId: { type: "string" },
          replaceIdentity: { type: "string" },
          identity: { type: "string" }
        },
        required: ["categoryId", "replaceIdentity", "identity"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          categoryId: { type: "string" },
          activity: { type: "string" },
          appleHealthEligible: { type: "boolean" }
        },
        required: ["categoryId", "activity", "appleHealthEligible"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          categoryId: { type: "string" },
          activity: { type: "string" },
          replaceActivity: { type: "string" }
        },
        required: ["categoryId", "activity", "replaceActivity"]
      },
      {
        type: "object",
        additionalProperties: false,
        properties: {
          categoryId: { type: "string" },
          title: { type: "string" },
          measurable: { type: "boolean" },
          unit: { type: "string" }
        },
        required: ["categoryId", "title", "measurable", "unit"]
      }
    ]
  };
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
                    payload: actionPayloadSchema
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
                payload: actionPayloadSchema
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
              payload: actionPayloadSchema
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
    "- Purpose (vision + passions): why the user is moving in this direction; usually refined yearly.",
    "- Fulfillment Areas (mission + identities + little wins): life domains to strengthen continuously; usually refined every 3 months.",
    "- Goals: concrete targets tied to fulfillment.",
    "- Capture: incoming actions and ideas.",
    "- Action Blocks: weekly commitments that should be completed by end of week.",
    "- Reflect: post-completion review after Action Blocks are executed (not pre-planning).",
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
    "- Treat Action Blocks as weekly finish targets; do not frame them as optional daily ideas.",
    "- Treat Reflect as a follow-up step after execution/completion, not a planning substitute.",
    "- Treat Purpose (vision + passions) as long-horizon direction, typically refined yearly unless major life change occurs.",
    "- Treat Fulfillment Areas as medium-horizon structure, typically refined quarterly (about every 3 months).",
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
    '- addFulfillmentIdentity {"categoryId":"uuid","categoryName":"...","identity":"..."}',
    '- replaceFulfillmentIdentity {"categoryId":"uuid","categoryName":"...","replaceIdentity":"...","identity":"..."}',
    '- addLittleWin {"categoryId":"uuid","activity":"...","appleHealthEligible":true|false}',
    '- replaceLittleWin {"categoryId":"uuid","activity":"...","replaceActivity":"..."}',
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

  let contextPackResult = contextIsPacked
    ? compactPackedContextForModel(rawContext, { route: chipIntentRoute })
    : await compactChatContextForModel(context, {
      route: chipIntentRoute,
      latestUserMessage,
      client
    });
  if (contextIsPacked) {
    contextPackResult = await hydratePackedStableContextForModel(contextPackResult, {
      route: chipIntentRoute
    });
  }
  const modelContext = contextPackResult.modelContext;
  const payloadContextMeta = contextPackResult.payloadContextMeta;
  const CHAT_HISTORY_LIMIT = chipIntentRoute ? 10 : 4;
  const userPayload = {
    messages: messages.slice(-CHAT_HISTORY_LIMIT).map((msg) => ({
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
  const cacheIdentity = buildChatCacheIdentity({
    model: preferredModel,
    userPayload
  });
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
  const CHAT_ATTEMPT_BUDGET_MS = 18000;
  const CHAT_MAX_ATTEMPT_TIMEOUT_MS = 10000;
  const CHAT_MIN_ATTEMPT_TIMEOUT_MS = 3000;
  const attemptsStartedAt = Date.now();
  for (const candidate of modelCandidates) {
    const elapsedMs = Date.now() - attemptsStartedAt;
    const remainingBudgetMs = CHAT_ATTEMPT_BUDGET_MS - elapsedMs;
    if (remainingBudgetMs < CHAT_MIN_ATTEMPT_TIMEOUT_MS) {
      break;
    }
    const attemptTimeoutMs = Math.max(
      CHAT_MIN_ATTEMPT_TIMEOUT_MS,
      Math.min(CHAT_MAX_ATTEMPT_TIMEOUT_MS, remainingBudgetMs - 250)
    );
    usedModel = candidate;
    const attempt = await callOpenAIResponsesJSON({
      apiKey,
      model: candidate,
      systemPrompt,
      userPayload,
      responseSchema: schema,
      maxOutputTokens: 700,
      timeoutMs: attemptTimeoutMs,
      reasoningEffort: "low",
      allowRetry: false
    });
    result = attempt;
    if (!attempt?.error) break;
    const normalizedError = String(attempt.error || "").toLowerCase();
    const retryableByModel =
      normalizedError.includes("upstream timeout") ||
      normalizedError.includes("upstream request failed") ||
      normalizedError.includes("upstream model error") ||
      normalizedError.includes("invalid upstream json") ||
      normalizedError.includes("missing model output");
    if (!retryableByModel) break;
  }
  if (!result) {
    result = {
      error: "Upstream timeout",
      details: "Chat model attempts exceeded response budget.",
      status: 502
    };
  }

  if (result.error) {
    console.error("[LoomAI] Chat upstream failure", {
      error: result.error,
      details: nonEmptyString(result.details) || null,
      model: usedModel || preferredModel,
      routeKey: nonEmptyString(chipIntentRoute?.key) || null,
      intent: normalizedIntent || "loomai_chat"
    });
    const response = (!chipIntentRoute && normalizedIntent !== "autogroup_plan")
      ? buildReliableNonRouteFallbackResponse({
        hasContext,
        context,
        latestUserMessage,
        intent: normalizedIntent
      })
      : safeChatFallback({
        hasContext,
        context,
        route: chipIntentRoute,
        allowRouteSuggestionCards: true,
        intent: normalizedIntent,
        message: buildUserFacingChatErrorMessage(result)
      });
    const debugScreen = nonEmptyString(client.screen).toLowerCase().includes("debug");
    if (debugScreen) {
      const detailSnippet = truncate(nonEmptyString(result.details), 220);
      response.debug = {
        ...response.debug,
        evidence: uniqueOrdered(
          [
            ...(Array.isArray(response?.debug?.evidence) ? response.debug.evidence : []),
            `upstream_error:${nonEmptyString(result.error) || "unknown"}`,
            detailSnippet ? `upstream_details:${detailSnippet}` : ""
          ].filter(Boolean)
        ).slice(0, 8)
      };
    }
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

function buildChatCacheIdentity({ model, userPayload }) {
  const payload = userPayload && typeof userPayload === "object" ? userPayload : {};
  const appContext = payload.APP_CONTEXT && typeof payload.APP_CONTEXT === "object"
    ? payload.APP_CONTEXT
    : {};
  const stable = appContext.stableContext && typeof appContext.stableContext === "object"
    ? appContext.stableContext
    : {};

  return {
    version: "loom_chat_v6",
    model: nonEmptyString(model) || DEFAULT_CHAT_MODEL,
    messages: Array.isArray(payload.messages) ? payload.messages : [],
    APP_CONTEXT: {
      personalizationHash: nonEmptyString(appContext.personalizationHash) || null,
      intent: appContext.intent && typeof appContext.intent === "object" ? appContext.intent : null,
      layers: appContext.layers && typeof appContext.layers === "object" ? appContext.layers : null,
      stableContext: {
        hash: nonEmptyString(stable.hash) || "",
        counts: stable.counts && typeof stable.counts === "object"
          ? {
              appGuide: Number.isFinite(Number(stable.counts.appGuide))
                ? Math.max(0, Math.floor(Number(stable.counts.appGuide)))
                : 0,
              dataInventory: Number.isFinite(Number(stable.counts.dataInventory))
                ? Math.max(0, Math.floor(Number(stable.counts.dataInventory)))
                : 0
            }
          : {
              appGuide: 0,
              dataInventory: 0
            }
      }
    },
    client: {
      intent: nonEmptyString(payload?.client?.intent) || "loomai_chat",
      userLocalDate: nonEmptyString(payload?.client?.userLocalDate) || null,
      timezone: nonEmptyString(payload?.client?.timezone) || null
    }
  };
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

  const diagnosticPromptContext = buildDiagnosticPromptContext(normalizedDiagnostic);
  const diagnosticPrompt = [
    "You generate first-signup diagnostic insights for Loom.",
    "Write it as if I was a 5th grader: simple words, short sentences, no jargon.",
    "",
    "Hard rules:",
    "- Use ONLY the provided diagnostic questionnaire, answer options, and chosen answers as grounding.",
    "- Analyze the meaning of the chosen answer in the context of the full option set for that question.",
    "- Do not use any external context or generic productivity advice.",
    "- Do not repeat or closely paraphrase the exact option text the user picked.",
    "- Do not praise, hype, reward, or motivate. No cheerleading.",
    "- Do not list, rename, or restate the selected 'areas'. You may refer to them only as 'different parts of life'.",
    "- For nextDirection, use the provided Loom mechanics context so the structural shift matches how Loom actually works.",
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
      anyOf: [
        {
          type: "object",
          additionalProperties: false,
          properties: {
            rootCause: { type: "string" },
            nextDirection: { type: "string" },
            error: { type: "string" }
          },
          required: ["rootCause", "nextDirection"]
        },
        {
          type: "object",
          additionalProperties: false,
          properties: {
            rootCause: { type: "string" },
            nextDirection: { type: "string" },
            error: { type: "string" }
          },
          required: ["error"]
        }
      ]
    }
  };

  let rootCause = "";
  let nextDirection = "";
  const insightResult = await callOpenAIResponsesJSON({
    apiKey,
    model: "gpt-5.1",
    systemPrompt: diagnosticPrompt,
    userPayload: { diagnostic: normalizedDiagnostic, diagnosticPromptContext },
    responseSchema: insightSchema,
    maxOutputTokens: 130,
    timeoutMs: 8000,
    reasoningEffort: "none",
    allowRetry: false
  });
  if (!insightResult.error) {
    const parsedInsight = insightResult.json || {};
    if (!(typeof parsedInsight.error === "string" && parsedInsight.error.trim() !== "")) {
      rootCause = coerceInsightText(parsedInsight.rootCause);
      nextDirection = coerceInsightText(parsedInsight.nextDirection);
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

function buildDiagnosticPromptContext(diagnostic) {
  return {
    loomMechanics: DIAGNOSTIC_LOOM_MECHANICS_CONTEXT,
    questionnaire: DIAGNOSTIC_QUESTIONNAIRE,
    chosenAnswers: {
      stress: diagnostic.stress,
      breaksFirst: diagnostic.breaksFirst,
      areas: diagnostic.areas,
      planningStyle: diagnostic.planningStyle,
      firstChange: diagnostic.firstChange
    }
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

function parsePlanResultAutoWriteInput(rawText) {
  const fallback = { areaName: "", actions: [] };
  const text = String(rawText || "").trim();
  if (!text) return fallback;
  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== "object") return fallback;
    return {
      areaName: nonEmptyString(parsed.areaName) || "",
      actions: Array.isArray(parsed.actions) ? parsed.actions : []
    };
  } catch {
    return fallback;
  }
}

function normalizePlanResultActions(actions) {
  return uniqueOrdered(
    (Array.isArray(actions) ? actions : [])
      .map((item) => String(item || "").replace(/\s+/g, " ").trim())
      .filter(Boolean)
  ).slice(0, 30);
}

function normalizePlanResultPhrase(value) {
  const compact = String(value || "")
    .replace(/\[\[[^\]]*]]/g, " ")
    .replace(/^[•\-–—\d\.\)\s]+/, "")
    .replace(/["“”]/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!compact) return "";

  const sanitized = compact.replace(/[^a-zA-Z0-9/&'+\-\s]/g, " ");
  const words = sanitized
    .split(/\s+/)
    .map((word) => word.trim())
    .filter(Boolean)
    .slice(0, 6);
  return words.join(" ").trim();
}

function isAcceptablePlanResultPhrase(value) {
  const phrase = normalizePlanResultPhrase(value);
  if (!phrase) return false;
  const wordCount = phrase.split(/\s+/).filter(Boolean).length;
  return wordCount >= 2 && wordCount <= 6;
}

function heuristicPlanResultFromActions(actions, areaName) {
  const keywords = planResultKeywordCandidates(actions);
  if (keywords.length >= 2) {
    return `${keywords[0]} and ${keywords[1]} follow-through`;
  }
  if (keywords.length === 1) {
    return `${keywords[0]} follow-through`;
  }
  const areaToken = String(areaName || "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .map((token) => token.trim())
    .find((token) => token.length >= 3 && !PLAN_RESULT_GENERIC_TOKENS.has(token));
  if (areaToken) {
    return `${areaToken} follow-through`;
  }
  return "Weekly follow-through";
}

function planResultKeywordCandidates(actions) {
  const stopWords = new Set([
    "the", "and", "for", "with", "from", "that", "this", "into", "through",
    "about", "your", "you", "our", "their", "then", "than", "just", "also",
    "will", "what", "when", "where", "have", "has", "had", "plan", "planned",
    "task", "action", "work", "week", "weekly", "daily", "today", "tomorrow"
  ]);
  const counts = new Map();
  for (const action of Array.isArray(actions) ? actions : []) {
    const tokens = String(action || "")
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, " ")
      .split(/\s+/)
      .map((token) => token.trim())
      .filter((token) => token.length >= 3 && !stopWords.has(token) && !/^\d+$/.test(token))
      .map((token) => (token.endsWith("s") && token.length > 4 ? token.slice(0, -1) : token));
    for (const token of tokens) {
      if (PLAN_RESULT_ACTION_VERBS.has(token) || PLAN_RESULT_GENERIC_TOKENS.has(token)) {
        continue;
      }
      counts.set(token, (counts.get(token) || 0) + 1);
    }
  }

  return Array.from(counts.entries())
    .sort((a, b) => {
      if (b[1] !== a[1]) return b[1] - a[1];
      if (b[0].length !== a[0].length) return b[0].length - a[0].length;
      return a[0].localeCompare(b[0]);
    })
    .slice(0, 3)
    .map(([token]) => token);
}

const PLAN_RESULT_ACTION_VERBS = new Set([
  "finish", "file", "send", "review", "update", "clean", "get", "make",
  "call", "email", "organize", "plan", "start", "complete", "check",
  "track", "build", "set", "create", "work", "manage", "fix", "shop",
  "sign", "walk", "follow", "keep", "do"
]);

const PLAN_RESULT_GENERIC_TOKENS = new Set([
  "thing", "item", "task", "action", "result", "progress", "goal",
  "weekly", "daily", "today", "tomorrow", "week", "day"
]);

function buildPlanResultAutoWriteResponse({ message, confidence, evidence }) {
  const cleanedMessage = normalizePlanResultPhrase(message);
  return {
    message: cleanedMessage,
    chips: [],
    actions: [],
    debug: {
      usedContext: false,
      confidence: confidence === "high" ? "high" : (confidence === "medium" ? "medium" : "low"),
      evidence: Array.isArray(evidence) ? evidence.slice(0, 4).map((item) => String(item || "")).filter(Boolean) : []
    }
  };
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

function coerceInsightText(value) {
  const normalized = normalizeInsightText(value);
  if (!normalized) return "";

  const rawSentences = normalized
    .match(/[^.!?]+[.!?]?/g)
    ?.map((s) => s.trim())
    .filter(Boolean) || [];

  const limitedSentences = rawSentences
    .slice(0, 3)
    .map((sentence) => /[.!?]$/.test(sentence) ? sentence : `${sentence}.`);

  if (limitedSentences.length === 0) return "";

  const rebuilt = [];
  let wordCount = 0;
  for (const sentence of limitedSentences) {
    const sentenceWords = sentence.split(/\s+/).filter(Boolean);
    if (sentenceWords.length === 0) continue;
    const remainingWords = 40 - wordCount;
    if (remainingWords <= 0) break;

    if (sentenceWords.length <= remainingWords) {
      rebuilt.push(sentence);
      wordCount += sentenceWords.length;
      continue;
    }

    // Preserve a second/third sentence when possible by trimming it to fit
    // instead of dropping the entire tail and failing validation.
    if (rebuilt.length > 0 && remainingWords >= 3) {
      const trimmedSentence = `${sentenceWords.slice(0, remainingWords).join(" ")}.`;
      rebuilt.push(trimmedSentence);
      wordCount += remainingWords;
    }
    break;
  }

  const candidate = rebuilt.join(" ").trim();
  return isValidInsightText(candidate) ? candidate : "";
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
  const retryMessage = "Processing error. Please try again later.";
  const rootCause = retryMessage;
  const nextDirection = retryMessage;
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

function safeChatFallback({ hasContext, context, message, intent, route, allowRouteSuggestionCards = true }) {
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
  const fallbackSuggestionCards = (hasContext && allowRouteSuggestionCards)
    ? buildRouteSuggestionCards(route, context)
    : [];
  return {
    message: fallbackMessage,
    grounding: fallbackGrounding,
    suggestionCards: fallbackSuggestionCards,
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

function shouldUseDeterministicRouteResponse(route) {
  const routeID = Number(route?.id);
  return Number.isFinite(routeID) && routeID >= 1 && routeID <= 8;
}

function buildDeterministicRouteMessage(route) {
  const routeID = Number(route?.id);
  const target = nonEmptyString(route?.target);
  if (routeID === 1) {
    return `I generated Daily Little Wins options${target ? ` for ${target}` : ""} below based on your current context.`;
  }
  if (routeID === 2) {
    return `I generated mission rewrite options${target ? ` for ${target}` : ""} below based on your current context.`;
  }
  if (routeID === 3) {
    return `I generated identity options${target ? ` for ${target}` : ""} below based on your current context.`;
  }
  if (routeID === 4) {
    return `I generated next-step options${target ? ` for ${target}` : ""} below based on your current context.`;
  }
  if (routeID === 5) {
    return `I generated plan options${target ? ` for ${target}` : ""} below based on your current context.`;
  }
  if (routeID === 6) {
    return `I generated passion options${target ? ` for ${target}` : ""} below based on your current context.`;
  }
  if (routeID === 7) {
    return "I generated Purpose Vision options below based on your current context.";
  }
  return "I prepared suggestions below.";
}

function buildDeterministicRouteResponse({ hasContext, context, route, message }) {
  const fallbackSuggestionCards = (hasContext && route)
    ? buildRouteSuggestionCards(route, context)
    : [];
  const flattenedActions = flattenSuggestionCardsToActions(fallbackSuggestionCards, context);
  return {
    message: nonEmptyString(message) || "I prepared suggestions below.",
    grounding: hasContext ? collectGrounding([], context, { maxItems: 3 }) : [],
    suggestionCards: fallbackSuggestionCards,
    nextAction: normalizeNextAction(null, fallbackSuggestionCards, {
      context,
      confidence: fallbackSuggestionCards.length > 0 ? "medium" : "low"
    }),
    chips: [],
    actions: flattenedActions,
    debug: {
      usedContext: Boolean(hasContext),
      confidence: fallbackSuggestionCards.length > 0 ? "medium" : "low",
      evidence: hasContext ? extractEvidencePathsFromContext(context, 3) : []
    }
  };
}

function detectHeuristicPromptType(message) {
  const text = nonEmptyString(message).toLowerCase();
  if (!text) return "";
  const wantsPersonality =
    /\bwhat personality\b/.test(text) ||
    /\bmy personality\b/.test(text) ||
    /\bpersonality profile\b/.test(text) ||
    /\bwhat profile\b/.test(text);
  if (wantsPersonality) return "personality_profile";
  const wantsSelfSummary =
    /\bwhat do you know about me\b/.test(text) ||
    /\bwhat have you learned about me\b/.test(text) ||
    /\bwhat do you know so far\b/.test(text) ||
    /\babout me so far\b/.test(text) ||
    /\bsummarize me\b/.test(text);
  if (wantsSelfSummary) return "self_summary";
  const wantsGoals =
    /\b(goals?|outcomes?)\b/.test(text) &&
    (/\b(each|every|all)\b/.test(text) || /\bcategory|categories|area|areas\b/.test(text));
  if (wantsGoals) return "goals_per_category";
  return "";
}

function buildDeterministicHeuristicPromptResponse({ hasContext, context, promptType, latestUserMessage }) {
  if (promptType === "personality_profile") {
    return buildPersonalityProfileDeterministicResponse({ hasContext, context });
  }
  if (promptType === "self_summary") {
    return buildKnowMeSoFarDeterministicResponse({ hasContext, context });
  }
  if (promptType === "goals_per_category") {
    return buildGoalsPerCategoryDeterministicResponse({ hasContext, context });
  }
  return safeChatFallback({
    hasContext,
    context,
    message: "I prepared suggestions below based on your current Loom context.",
    allowRouteSuggestionCards: false
  });
}

function buildReliableNonRouteFallbackResponse({ hasContext, context, latestUserMessage, intent }) {
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const topCategory = categories[0] || null;
  const topCategoryName = nonEmptyString(topCategory?.name) || "your top area";
  const topCategoryId = nonEmptyString(topCategory?.id);
  const topCategoryLittleWins = Array.isArray(topCategory?.littleWins)
    ? topCategory.littleWins.map((item) => nonEmptyString(item)).filter(Boolean)
    : [];
  const goals = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  const topGoal = goals[0] || null;
  const topGoalTitle = nonEmptyString(topGoal?.title);
  const captureCount = Number.isFinite(Number(context?.capture?.totalCount))
    ? Number(context.capture.totalCount)
    : 0;
  const purpose = nonEmptyString(context?.drivingForce?.purpose || context?.drivingForce?.vision);
  const prompt = nonEmptyString(latestUserMessage);
  const promptLead = prompt ? `For "${truncate(prompt, 90)}",` : "Based on your current Loom data,";

  const summaryLines = [
    `${promptLead} here is a reliable, context-based answer:`,
    purpose ? `• Your direction: ${truncate(purpose, 160)}` : "",
    `• Priority area right now: ${topCategoryName}`,
    topGoalTitle ? `• Active goal: ${topGoalTitle}` : "",
    captureCount > 0 ? `• Capture queue: ${captureCount} items` : ""
  ].filter(Boolean);
  summaryLines.push("I added practical next actions below so you can move immediately.");

  const options = buildReliableFallbackActionOptions({
    topCategoryName,
    topCategoryId,
    topCategoryLittleWins,
    topGoalTitle
  });

  const suggestionCards = options.length > 0
    ? [{
      id: "reliable-next-actions",
      title: "Reliable next actions",
      description: "",
      options
    }]
    : [];

  return {
    message: summaryLines.join("\n"),
    grounding: hasContext ? collectGrounding([], context, { maxItems: 4 }) : [],
    suggestionCards,
    nextAction: normalizeNextAction(null, suggestionCards, {
      context,
      confidence: suggestionCards.length > 0 ? "medium" : "low"
    }),
    chips: [],
    actions: flattenSuggestionCardsToActions(suggestionCards, context),
    debug: {
      usedContext: Boolean(hasContext),
      confidence: suggestionCards.length > 0 ? "medium" : "low",
      evidence: hasContext
        ? uniqueOrdered([...extractEvidencePathsFromContext(context, 4), "fallback:non_route_reliable"]).slice(0, 8)
        : ["fallback:non_route_reliable"]
    }
  };
}

function buildReliableFallbackActionOptions({ topCategoryName, topCategoryId, topCategoryLittleWins, topGoalTitle }) {
  const hasCategoryId = /^[0-9a-f-]{36}$/i.test(nonEmptyString(topCategoryId));
  const littleWinCandidates = uniqueOrdered(
    [
      topGoalTitle ? `15-minute progress on ${truncate(topGoalTitle, 64)}` : "",
      `Plan tomorrow priorities for ${truncate(topCategoryName, 40)}`,
      "Close one open loop today"
    ].filter(Boolean)
  );

  const littleWinOptions = littleWinCandidates.slice(0, 2).map((activity, index) => {
    if (!hasCategoryId) {
      return {
        id: `reliable-action-${index + 1}`,
        label: String.fromCharCode(65 + index),
        title: activity,
        type: "createCaptureAction",
        payload: { text: activity }
      };
    }
    const shouldReplace = topCategoryLittleWins.length >= 3;
    if (shouldReplace) {
      const replaceTargets = chooseLittleWinReplacementTargets(topCategoryLittleWins, topCategoryName, littleWinCandidates.length);
      const replaceActivity = replaceTargets[index % Math.max(1, replaceTargets.length)] || topCategoryLittleWins[0];
      return {
        id: `reliable-action-${index + 1}`,
        label: String.fromCharCode(65 + index),
        title: `Replace "${truncate(replaceActivity, 52)}" with "${truncate(activity, 64)}"`,
        type: "replaceLittleWin",
        payload: {
          categoryId: topCategoryId,
          activity,
          replaceActivity
        }
      };
    }
    return {
      id: `reliable-action-${index + 1}`,
      label: String.fromCharCode(65 + index),
      title: activity,
      type: "addLittleWin",
      payload: {
        categoryId: topCategoryId,
        activity,
        appleHealthEligible: inferAppleHealthEligibility(activity, topCategoryName)
      }
    };
  });

  const captureTitle = topGoalTitle
    ? `Draft execution checklist for ${truncate(topGoalTitle, 64)}`
    : `Sort capture for ${truncate(topCategoryName, 40)}`;
  const captureOption = {
    id: "reliable-action-3",
    label: "C",
    title: captureTitle,
    type: "createCaptureAction",
    payload: { text: captureTitle }
  };

  return [...littleWinOptions, captureOption].slice(0, 3);
}

function buildGoalsPerCategoryDeterministicResponse({ hasContext, context }) {
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const activeGoals = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  const existingGoalTitles = new Set(
    activeGoals
      .map((goal) => nonEmptyString(goal?.title).toLowerCase())
      .filter(Boolean)
  );
  const topCategories = categories.slice(0, 3);

  const options = topCategories
    .map((category, index) => {
      const categoryName = nonEmptyString(category?.name) || `Category ${index + 1}`;
      const categoryId = nonEmptyString(category?.id);
      const idea = goalIdeaForCategory(categoryName, existingGoalTitles, index);
      if (!idea) return null;
      if (!/^[0-9a-f-]{36}$/i.test(categoryId)) {
        return {
          id: `goal-idea-${index + 1}`,
          label: String.fromCharCode(65 + index),
          title: `${categoryName}: ${idea}`,
          type: "createCaptureAction",
          payload: { text: `Draft outcome for ${categoryName}: ${idea}` }
        };
      }
      return {
        id: `goal-idea-${index + 1}`,
        label: String.fromCharCode(65 + index),
        title: `${categoryName}: ${idea}`,
        type: "createOutcome",
        payload: {
          categoryId,
          title: idea,
          measurable: false,
          unit: ""
        }
      };
    })
    .filter(Boolean);

  const suggestionCards = options.length > 0
    ? [{
      id: "goals-by-category",
      title: "Goal ideas by category",
      description: "",
      options
    }]
    : [];
  const actions = flattenSuggestionCardsToActions(suggestionCards, context);

  return {
    message: "I generated goal ideas for your categories below based on your current context.",
    grounding: hasContext ? collectGrounding([], context, { maxItems: 4 }) : [],
    suggestionCards,
    nextAction: normalizeNextAction(null, suggestionCards, {
      context,
      confidence: suggestionCards.length > 0 ? "medium" : "low"
    }),
    chips: [],
    actions,
    debug: {
      usedContext: Boolean(hasContext),
      confidence: suggestionCards.length > 0 ? "medium" : "low",
      evidence: hasContext
        ? uniqueOrdered([...extractEvidencePathsFromContext(context, 4), "heuristic:goals_per_category"]).slice(0, 8)
        : ["heuristic:goals_per_category"]
    }
  };
}

function buildPersonalityProfileDeterministicResponse({ hasContext, context }) {
  const profile = nonEmptyString(context?.personalityProfile?.profile || context?.personalityProfile);
  const diagnostic = context?.diagnostic && typeof context.diagnostic === "object" ? context.diagnostic : {};
  const planningStyle = nonEmptyString(diagnostic?.planningStyle);
  const breaksFirst = nonEmptyString(diagnostic?.breaksFirst);
  const firstChange = nonEmptyString(diagnostic?.firstChange);
  const rootCause = nonEmptyString(diagnostic?.rootCause);
  const nextDirection = nonEmptyString(diagnostic?.nextDirection);

  const lines = [];
  lines.push(profile ? `Your current personality profile in Loom is: ${profile}.` : "You do not have a saved personality profile yet.");
  if (planningStyle) lines.push(`Planning style: ${truncate(planningStyle, 120)}.`);
  if (breaksFirst) lines.push(`What breaks first: ${truncate(breaksFirst, 120)}.`);
  if (firstChange) lines.push(`Desired first change: ${truncate(firstChange, 140)}.`);
  if (rootCause) lines.push(`Pattern Loom sees: ${truncate(rootCause, 170)}.`);
  if (nextDirection) lines.push(`Direction Loom suggests: ${truncate(nextDirection, 170)}.`);
  if (!profile && !planningStyle && !breaksFirst && !firstChange && !rootCause && !nextDirection) {
    lines.push("I need a bit more diagnostic data to infer this confidently.");
  }

  return {
    message: lines.join("\n"),
    grounding: hasContext ? collectGrounding([], context, { maxItems: 4 }) : [],
    suggestionCards: [],
    nextAction: null,
    chips: [],
    actions: [],
    debug: {
      usedContext: Boolean(hasContext),
      confidence: hasContext ? "high" : "low",
      evidence: hasContext
        ? uniqueOrdered([...extractEvidencePathsFromContext(context, 4), "heuristic:personality_profile"]).slice(0, 8)
        : ["heuristic:personality_profile"]
    }
  };
}

function buildKnowMeSoFarDeterministicResponse({ hasContext, context }) {
  const purpose = nonEmptyString(context?.drivingForce?.purpose);
  const vision = nonEmptyString(context?.drivingForce?.vision);
  const passions = Array.isArray(context?.drivingForce?.passions) ? context.drivingForce.passions : [];
  const passionLabels = passions
    .map((item) => nonEmptyString(item?.title || item?.passion))
    .filter(Boolean)
    .slice(0, 4);
  const profile = nonEmptyString(context?.personalityProfile?.profile || context?.personalityProfile);
  const diagnostic = context?.diagnostic && typeof context.diagnostic === "object" ? context.diagnostic : {};
  const areas = Array.isArray(diagnostic?.areas) ? diagnostic.areas.map((item) => nonEmptyString(item)).filter(Boolean).slice(0, 3) : [];
  const rootCause = nonEmptyString(diagnostic?.rootCause);
  const nextDirection = nonEmptyString(diagnostic?.nextDirection);
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const topCategories = categories.map((item) => nonEmptyString(item?.name)).filter(Boolean).slice(0, 3);
  const activeGoals = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  const goal = activeGoals[0] || null;
  const goalTitle = nonEmptyString(goal?.title);
  const goalProgress = nonEmptyString(goal?.progressSummary);
  const captureCount = Number.isFinite(Number(context?.capture?.totalCount))
    ? Number(context.capture.totalCount)
    : 0;

  const lines = [];
  lines.push("Here’s what I know about you so far from Loom:");
  if (profile) lines.push(`• Profile: ${profile}`);
  if (vision) lines.push(`• Vision: ${truncate(vision, 180)}`);
  if (purpose) lines.push(`• Purpose: ${truncate(purpose, 180)}`);
  if (passionLabels.length > 0) lines.push(`• Passions: ${passionLabels.join(", ")}`);
  if (topCategories.length > 0) lines.push(`• Main fulfillment areas: ${topCategories.join(", ")}`);
  if (goalTitle) {
    lines.push(`• Active goal: ${goalTitle}${goalProgress ? ` (${goalProgress})` : ""}`);
  }
  if (captureCount > 0) lines.push(`• Capture queue: ${captureCount} items right now`);
  if (areas.length > 0) lines.push(`• Diagnostic focus areas: ${areas.join(", ")}`);
  if (rootCause) lines.push(`• Pattern I see: ${truncate(rootCause, 160)}`);
  if (nextDirection) lines.push(`• Best next direction: ${truncate(nextDirection, 160)}`);
  lines.push("If you want, I can turn this into a one-week focus plan next.");

  return {
    message: lines.join("\n"),
    grounding: hasContext ? collectGrounding([], context, { maxItems: 5 }) : [],
    suggestionCards: [],
    nextAction: null,
    chips: [],
    actions: [],
    debug: {
      usedContext: Boolean(hasContext),
      confidence: hasContext ? "high" : "low",
      evidence: hasContext
        ? uniqueOrdered([...extractEvidencePathsFromContext(context, 5), "heuristic:self_summary"]).slice(0, 8)
        : ["heuristic:self_summary"]
    }
  };
}

function goalIdeaForCategory(categoryName, existingGoalTitles, seed = 0) {
  const key = nonEmptyString(categoryName).toLowerCase();
  let candidates = [];
  if (key.includes("wealth") || key.includes("finance")) {
    candidates = [
      "Build a 30-day spending plan",
      "Pay down one high-interest debt",
      "Increase monthly savings rate"
    ];
  } else if (key.includes("faith") || key.includes("spiritual")) {
    candidates = [
      "Complete 20 days of morning prayer",
      "Read one spiritual chapter daily",
      "Practice weekly reflection"
    ];
  } else if (key.includes("love") || key.includes("relationship")) {
    candidates = [
      "Schedule two quality-time blocks weekly",
      "Run a daily 10-minute relationship check-in",
      "Practice one gratitude message daily"
    ];
  } else if (key.includes("health") || key.includes("energy")) {
    candidates = [
      "Walk 30 minutes five days weekly",
      "Follow nutrition plan six days weekly",
      "Sleep 7+ hours at least five nights weekly"
    ];
  } else {
    candidates = [
      `Define a 30-day milestone for ${categoryName}`,
      `Complete one weekly execution block for ${categoryName}`,
      `Track progress weekly in ${categoryName}`
    ];
  }
  for (let i = 0; i < candidates.length; i += 1) {
    const candidate = candidates[(i + seed) % candidates.length];
    if (!existingGoalTitles.has(candidate.toLowerCase())) return candidate;
  }
  return candidates[0] || "";
}

function buildBestUseLoomDeterministicResponse({ hasContext, context, route }) {
  const message = buildBestUseLoomGuidanceMessage(context);
  return {
    message,
    grounding: hasContext ? collectGrounding([], context, { maxItems: 5, route }) : [],
    suggestionCards: [],
    nextAction: null,
    chips: [],
    actions: [],
    debug: {
      usedContext: Boolean(hasContext),
      confidence: "high",
      evidence: hasContext ? extractEvidencePathsFromContext(context, 5) : []
    }
  };
}

function buildBestUseLoomGuidanceMessage(context) {
  const purpose = nonEmptyString(context?.drivingForce?.purpose);
  const vision = nonEmptyString(context?.drivingForce?.vision);
  const captureCount = Number.isFinite(Number(context?.capture?.totalCount))
    ? Number(context.capture.totalCount)
    : 0;
  const quickCompletions = Number.isFinite(Number(context?.capture?.quickCompletionsLast7Days))
    ? Number(context.capture.quickCompletionsLast7Days)
    : 0;
  const actionBlocks = Array.isArray(context?.currentWeekActionBlocks) ? context.currentWeekActionBlocks : [];
  const firstBlock = actionBlocks[0] || null;
  const firstBlockTitle = nonEmptyString(firstBlock?.title || firstBlock?.category);
  const firstBlockActions = Array.isArray(firstBlock?.actions) ? firstBlock.actions.map((item) => nonEmptyString(item)).filter(Boolean) : [];
  const topFulfillment = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories.slice(0, 2) : [];
  const firstArea = topFulfillment[0] || null;
  const firstAreaName = nonEmptyString(firstArea?.name);
  const firstAreaLittleWins = Array.isArray(firstArea?.littleWins) ? firstArea.littleWins.map((x) => nonEmptyString(x)).filter(Boolean).slice(0, 3) : [];
  const goals = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  const firstGoal = goals[0] || null;
  const goalTitle = nonEmptyString(firstGoal?.title);
  const goalProgress = nonEmptyString(firstGoal?.progressSummary);
  const diagnosticRoot = nonEmptyString(context?.diagnostic?.rootCause);
  const diagnosticDirection = nonEmptyString(context?.diagnostic?.nextDirection);

  const p1 = purpose || vision
    ? `Your best use of Loom is to treat it as a daily execution system for [[P:${truncate(purpose || vision, 120)}]], not as a place to collect more tasks.`
    : "Your best use of Loom is to treat it as a daily execution system, not as a place to collect more tasks.";
  const p2 = `Run Loom in this order: [[A:Capture -> Action Blocks (weekly) -> Little Wins (daily) -> Reflect (after execution)]]. Capture should stay fast, Action Blocks should be finished by week end, Little Wins should protect daily consistency, and Reflect should happen after blocks are completed to lock in learning.`;
  const p3 = [
    captureCount > 0 ? `You currently have [[A:${captureCount}]] capture items` : "",
    quickCompletions === 0 ? "with no quick completions in the last 7 days" : `with ${quickCompletions} quick completions in the last 7 days`,
    firstBlockTitle ? `and an active block in [[F:${firstBlockTitle}]]` : "",
    firstBlockActions.length > 0 ? `containing ${firstBlockActions.slice(0, 2).join(" + ")}` : ""
  ].filter(Boolean).join(" ").replace(/\s+/g, " ").trim();
  const p4 = [
    firstAreaName && firstAreaLittleWins.length > 0
      ? `In [[F:${firstAreaName}]], keep only three Little Wins that are specific and finishable (example style: ${firstAreaLittleWins.slice(0, 2).join("; ")}).`
      : "",
    goalTitle
      ? `For [[O:${goalTitle}]] (${goalProgress || "progress not tracked yet"}), connect at least one Action Block task and one Little Win to the same outcome this week.`
      : ""
  ].filter(Boolean).join(" ");
  const p5 = buildBestUseLoomDiagnosticSection({
    diagnosticRoot,
    diagnosticDirection,
    firstAreaName,
    firstBlockTitle
  });
  const p6 = "Agile mode: low time = 10-minute triage (Capture 3, plan 1 block, do 1 Little Win). High energy = 30-minute weekly pass (clean Capture, tighten this week’s blocks, and link each to one outcome).";

  return [p1, p2, p3, p4, p5, p6].filter(Boolean).join("\n\n");
}

function buildBestUseLoomDiagnosticSection({ diagnosticRoot, diagnosticDirection, firstAreaName, firstBlockTitle }) {
  if (!diagnosticRoot && !diagnosticDirection) return "";
  const area = nonEmptyString(firstAreaName) || nonEmptyString(firstBlockTitle) || "your top area";
  const parts = ["Diagnostic pattern (from your data):"];
  if (diagnosticRoot) {
    parts.push(`• Root cause: "${truncate(diagnosticRoot, 180)}"`);
  }
  if (diagnosticDirection) {
    parts.push(`• Direction: "${truncate(diagnosticDirection, 180)}"`);
  }
  parts.push(`Apply this in [[F:${area}]] first, then mirror the same structure in your next area.`);
  return parts.join("\n");
}

function buildUserFacingChatErrorMessage(result) {
  const errorText = nonEmptyString(result?.error).toLowerCase();
  if (!errorText) {
    return "Couldn’t generate a LoomAI response right now. Please try again.";
  }
  if (errorText.includes("upstream timeout")) {
    return "LoomAI timed out while generating this response. Please try again.";
  }
  if (errorText.includes("upstream request failed")) {
    return "LoomAI couldn’t reach the model service. Please try again.";
  }
  if (errorText.includes("upstream model error")) {
    return "LoomAI hit a model error while generating this response. Please try again.";
  }
  if (errorText.includes("invalid upstream json") || errorText.includes("missing model output")) {
    return "LoomAI returned an invalid response. Please try again.";
  }
  return "Couldn’t generate a LoomAI response right now. Please try again.";
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

function isIntentContextPack(context) {
  const src = context && typeof context === "object" ? context : null;
  if (!src) return false;
  const version = nonEmptyString(src.contextVersion || src.version).toLowerCase();
  return version === "intent_pack_v1" && src.layers && typeof src.layers === "object";
}

function hasMeaningfulPackedLoomContext(contextPack) {
  const src = contextPack && typeof contextPack === "object" ? contextPack : null;
  if (!src) return false;
  const layers = src.layers && typeof src.layers === "object" ? src.layers : {};
  const identity = layers.identity && typeof layers.identity === "object" ? layers.identity : {};
  const currentReality = layers.currentReality && typeof layers.currentReality === "object" ? layers.currentReality : {};
  const targetObject = layers.targetObject && typeof layers.targetObject === "object" ? layers.targetObject : {};
  return Boolean(
    identity.diagnostic ||
      identity.purpose ||
      identity.personalityProfile ||
      currentReality.fulfillment ||
      currentReality.goals ||
      currentReality.week ||
      currentReality.capture ||
      targetObject.type
  );
}

function compactPackedContextForModel(contextPack, { route = null } = {}) {
  const src = contextPack && typeof contextPack === "object" ? contextPack : {};
  const layers = src.layers && typeof src.layers === "object" ? src.layers : {};
  const identitySrc = layers.identity && typeof layers.identity === "object" ? layers.identity : {};
  const currentRealitySrc = layers.currentReality && typeof layers.currentReality === "object" ? layers.currentReality : {};
  const targetObjectSrc = layers.targetObject && typeof layers.targetObject === "object" ? layers.targetObject : {};
  const stableSrc = src.stableContext && typeof src.stableContext === "object" ? src.stableContext : {};

  const routeID = Number.isFinite(Number(src?.intent?.routeID))
    ? Number(src.intent.routeID)
    : (Number.isFinite(Number(route?.id)) ? Number(route.id) : null);
  const routeKey = nonEmptyString(src?.intent?.routeKey) || nonEmptyString(route?.key) || null;
  const routeTarget = nonEmptyString(src?.intent?.target) || nonEmptyString(route?.target) || null;

  const modelContext = {
    generatedAt: normalizeCompactTimestamp(src.generatedAt),
    personalizationHash: nonEmptyString(src.personalizationHash) || null,
    intent: {
      routeID,
      routeKey,
      target: routeTarget
    },
    layers: {
      identity: pruneEmptyObject({
        diagnostic: cleanDiagnosticSummary(identitySrc?.diagnostic),
        purpose: cleanDrivingForceSummary(identitySrc?.purpose),
        personalityProfile: cleanCompactTitle(identitySrc?.personalityProfile, 72) || null
      }),
      currentReality: pruneEmptyObject({
        fulfillment: cleanFulfillmentCategories(currentRealitySrc?.fulfillment),
        goals: cleanActiveGoals(currentRealitySrc?.goals),
        week: (() => {
          const blocks = cleanActionBlocks(currentRealitySrc?.week?.currentWeekActionBlocks);
          return blocks.length > 0 ? { currentWeekActionBlocks: blocks } : null;
        })(),
        capture: cleanCaptureSummary(currentRealitySrc?.capture)
      }),
      targetObject: pruneEmptyObject(normalizeTargetObjectLayer(targetObjectSrc))
    },
    stableContext: {
      hash: nonEmptyString(stableSrc.hash) || "",
      changed: Boolean(stableSrc.changed),
      appGuide: cleanAppGuide(stableSrc.appGuide),
      dataInventory: cleanDataInventory(stableSrc.dataInventory),
      counts: {
        appGuide: Number.isFinite(Number(stableSrc?.counts?.appGuide))
          ? Math.max(0, Math.floor(Number(stableSrc.counts.appGuide)))
          : (Array.isArray(stableSrc.appGuide) ? stableSrc.appGuide.length : 0),
        dataInventory: Number.isFinite(Number(stableSrc?.counts?.dataInventory))
          ? Math.max(0, Math.floor(Number(stableSrc.counts.dataInventory)))
          : (Array.isArray(stableSrc.dataInventory) ? stableSrc.dataInventory.length : 0)
      }
    }
  };

  return {
    modelContext,
    payloadContextMeta: {
      includedSections: summarizeIncludedContextSections(modelContext),
      stableContextHash: nonEmptyString(modelContext?.stableContext?.hash) || null,
      stableContextChanged: Boolean(modelContext?.stableContext?.changed),
      stableContextSent:
        (Array.isArray(modelContext?.stableContext?.appGuide) && modelContext.stableContext.appGuide.length > 0) ||
        (Array.isArray(modelContext?.stableContext?.dataInventory) && modelContext.stableContext.dataInventory.length > 0)
    }
  };
}

async function hydratePackedStableContextForModel(result, { route = null } = {}) {
  const src = result && typeof result === "object" ? result : {};
  const modelContext = src.modelContext && typeof src.modelContext === "object" ? src.modelContext : {};
  const stable = modelContext.stableContext && typeof modelContext.stableContext === "object"
    ? modelContext.stableContext
    : {};
  const includeStableBlocksByIntent = shouldIncludeStableBlocksForIntent(route);

  let appGuide = cleanAppGuide(stable.appGuide);
  let dataInventory = cleanDataInventory(stable.dataInventory);
  const hash = nonEmptyString(stable.hash);
  const changed = includeStableBlocksByIntent ? Boolean(stable.changed) : false;
  const sentInline = appGuide.length > 0 || dataInventory.length > 0;

  if (hash && sentInline) {
    await cacheStableContextBlocks(hash, { appGuide, dataInventory });
  } else if (includeStableBlocksByIntent && hash) {
    const cached = await readStableContextBlocks(hash);
    if (cached) {
      appGuide = cached.appGuide;
      dataInventory = cached.dataInventory;
    }
  }

  if (!includeStableBlocksByIntent) {
    appGuide = [];
    dataInventory = [];
  }

  const countsFromSource = stable?.counts && typeof stable.counts === "object" ? stable.counts : {};
  const nextStableContext = {
    hash,
    changed,
    appGuide,
    dataInventory,
    counts: {
      appGuide: Number.isFinite(Number(countsFromSource.appGuide))
        ? Math.max(0, Math.floor(Number(countsFromSource.appGuide)))
        : appGuide.length,
      dataInventory: Number.isFinite(Number(countsFromSource.dataInventory))
        ? Math.max(0, Math.floor(Number(countsFromSource.dataInventory)))
        : dataInventory.length
    }
  };
  const nextModelContext = {
    ...modelContext,
    stableContext: nextStableContext
  };

  return {
    modelContext: nextModelContext,
    payloadContextMeta: {
      includedSections: summarizeIncludedContextSections(nextModelContext),
      stableContextHash: nonEmptyString(nextStableContext.hash) || null,
      stableContextChanged: nextStableContext.changed,
      stableContextSent: appGuide.length > 0 || dataInventory.length > 0
    }
  };
}

function normalizeTargetObjectLayer(input) {
  const src = input && typeof input === "object" ? input : {};
  const type = cleanCompactText(src.type, 40);
  if (!type) return null;
  const base = { type };
  if (type === "fulfillment_area") {
    return {
      ...base,
      id: cleanCompactText(src.id, 40),
      name: cleanCompactTitle(src.name, 72),
      mission: normalizeMissionText(src.mission),
      identity: cleanStringList(src.identity, { maxItems: 3, maxChars: 64, minLength: 2, allowJunkTitles: false }),
      littleWins: cleanStringList(src.littleWins, { maxItems: 3, maxChars: 72, minLength: 2, allowJunkTitles: false })
    };
  }
  if (type === "goal") {
    return {
      ...base,
      id: cleanCompactText(src.id, 40),
      title: cleanCompactTitle(src.title, 96),
      category: cleanCompactTitle(src.category, 72),
      measurable: Boolean(src.measurable),
      progressSummary: cleanCompactText(src.progressSummary, 140)
    };
  }
  if (type === "passion_type") {
    return {
      ...base,
      emotion: normalizePassionType(src.emotion),
      relatedPassions: cleanPassions(src.relatedPassions)
    };
  }
  if (type === "purpose_vision") {
    return {
      ...base,
      vision: cleanCompactText(src.vision, 240),
      purpose: cleanCompactText(src.purpose, 240)
    };
  }
  if (type === "loom_usage") {
    return {
      ...base,
      prompt: cleanCompactText(src.prompt, 220)
    };
  }
  return base;
}

function legacyContextFromIntentPack(contextPack) {
  const compacted = compactPackedContextForModel(contextPack, { route: null });
  const modelContext = compacted?.modelContext && typeof compacted.modelContext === "object"
    ? compacted.modelContext
    : {};
  const identity = modelContext?.layers?.identity && typeof modelContext.layers.identity === "object"
    ? modelContext.layers.identity
    : {};
  const currentReality = modelContext?.layers?.currentReality && typeof modelContext.layers.currentReality === "object"
    ? modelContext.layers.currentReality
    : {};
  const targetObject = modelContext?.layers?.targetObject && typeof modelContext.layers.targetObject === "object"
    ? modelContext.layers.targetObject
    : {};
  const stableContext = modelContext?.stableContext && typeof modelContext.stableContext === "object"
    ? modelContext.stableContext
    : {};

  const fulfillment = Array.isArray(currentReality.fulfillment) ? currentReality.fulfillment : [];
  const goals = Array.isArray(currentReality.goals) ? currentReality.goals : [];
  const blocks = Array.isArray(currentReality?.week?.currentWeekActionBlocks)
    ? currentReality.week.currentWeekActionBlocks
    : [];

  const mergedFulfillment = targetObject.type === "fulfillment_area"
    ? mergeUniqueByKey([{
      id: cleanCompactText(targetObject.id, 40),
      name: cleanCompactTitle(targetObject.name, 72),
      mission: normalizeMissionText(targetObject.mission),
      identity: cleanStringList(targetObject.identity, { maxItems: 3, maxChars: 64, minLength: 2, allowJunkTitles: false }),
      littleWins: cleanStringList(targetObject.littleWins, { maxItems: 3, maxChars: 72, minLength: 2, allowJunkTitles: false }),
      weeklyScore: null
    }, ...fulfillment], (item) => `${String(item?.id || "").toLowerCase()}|${String(item?.name || "").toLowerCase()}`)
    : fulfillment;

  const mergedGoals = targetObject.type === "goal"
    ? mergeUniqueByKey([{
      id: cleanCompactText(targetObject.id, 40),
      title: cleanCompactTitle(targetObject.title, 96),
      category: cleanCompactTitle(targetObject.category, 72),
      measurable: Boolean(targetObject.measurable),
      progressSummary: cleanCompactText(targetObject.progressSummary, 140)
    }, ...goals], (item) => `${String(item?.id || "").toLowerCase()}|${String(item?.title || "").toLowerCase()}`)
    : goals;

  return {
    generatedAt: modelContext.generatedAt || null,
    personalizationHash: nonEmptyString(modelContext.personalizationHash) || null,
    diagnostic: identity.diagnostic || null,
    personalityProfile: nonEmptyString(identity.personalityProfile) || null,
    drivingForce: identity.purpose || null,
    fulfillmentCategories: mergedFulfillment,
    activeOutcomes: mergedGoals,
    currentWeekActionBlocks: blocks,
    capture: currentReality.capture || null,
    appGuide: Array.isArray(stableContext.appGuide) ? stableContext.appGuide : [],
    dataInventory: Array.isArray(stableContext.dataInventory) ? stableContext.dataInventory : [],
    sectionTimestamps: {
      purpose: modelContext.generatedAt || "",
      fulfillment: modelContext.generatedAt || "",
      outcomes: modelContext.generatedAt || "",
      actionBlocks: modelContext.generatedAt || "",
      capture: modelContext.generatedAt || "",
      diagnostic: modelContext.generatedAt || "",
      diagnostics: modelContext.generatedAt || ""
    }
  };
}

function mergeUniqueByKey(items, keyFn) {
  const source = Array.isArray(items) ? items : [];
  const seen = new Set();
  const out = [];
  for (const item of source) {
    if (!item || typeof item !== "object") continue;
    const key = String(keyFn(item) || "").toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(item);
  }
  return out;
}

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
  } else if (routeID === 6) {
    categories = [];
    goals = goals.slice(0, 2);
    blocks = blocks.slice(0, 2);
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
  const hydratedBlocks = (!includeFull && includeStableBlocksByIntent && hash)
    ? await readStableContextBlocks(hash)
    : null;
  const effectiveAppGuide = includeFull
    ? payload.appGuide
    : (hydratedBlocks?.appGuide || []);
  const effectiveDataInventory = includeFull
    ? payload.dataInventory
    : (hydratedBlocks?.dataInventory || []);

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
      appGuide: effectiveAppGuide,
      dataInventory: effectiveDataInventory,
      counts: {
        appGuide: effectiveAppGuide.length,
        dataInventory: effectiveDataInventory.length
      }
    }
  };
}

async function readStableContextBlocks(hash) {
  if (!hash) return null;
  const key = new Request(`https://loom-cache.internal/stable-context/blocks/${hash}`);
  try {
    const cached = await caches.default.match(key);
    if (!cached) return null;
    const json = await cached.json();
    return {
      appGuide: cleanAppGuide(json?.appGuide),
      dataInventory: cleanDataInventory(json?.dataInventory)
    };
  } catch {
    return null;
  }
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
  const lowered = message.toLowerCase();
  if (
    lowered.includes("couldn’t generate a loomai response") ||
    lowered.includes("couldn't generate a loomai response") ||
    lowered.includes("timed out while generating") ||
    lowered.includes("couldn’t reach the model service") ||
    lowered.includes("couldn't reach the model service") ||
    lowered.includes("hit a model error") ||
    lowered.includes("returned an invalid response")
  ) {
    return false;
  }
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
  if (!text) return "love";
  if (text === "vow") return "vows";
  if (text === "just" || text === "hate" || text === "hates") return "hate";
  if (["love", "vows", "thrill"].includes(text)) return text;
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

function normalizeModelCopy(value, { preserveNewlines = false } = {}) {
  let text = String(value || "");
  if (!text) return "";

  text = text
    .replace(/\u00a0/g, " ")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/[“”]/g, "\"")
    .replace(/[‘’]/g, "'")
    .replace(/[–—]/g, " - ")
    .replace(/[‐‑‒−]/g, "-")
    .replace(/…/g, "...")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/(^|[\s(])\*{1,3}([^*]+)\*{1,3}(?=[\s).,!?]|$)/g, "$1$2")
    .replace(/(^|[\s(])_{1,3}([^_]+)_{1,3}(?=[\s).,!?]|$)/g, "$1$2");

  if (preserveNewlines) {
    text = text
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .replace(/[ \t\f\v]+/g, " ")
      .replace(/\n{3,}/g, "\n\n");
  } else {
    text = text.replace(/\s+/g, " ");
  }

  return text.trim();
}

function composeMessage(message, { context, route }) {
  const source = normalizeModelCopy(message, { preserveNewlines: true });
  if (!source) return composeFallbackMessage(context, route);

  const forbiddenInteraction = [
    /\bsources?\b/i,
    /\bwhich should i (add|edit|replace|pick)\b/i,
    /\boption [abc]\b/i,
    /\bchoose (a|b|c)\b/i,
    /\bhere (are|is)\b.*\boptions?\b/i,
    /\b(the )?(options|suggestions) below\b/i,
    /\b(pick|choose) (one|an option)\b/i
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
    .map((p) => truncateParagraphCleanly(p, 280))
    .slice(0, 3);

  if (paragraphCandidates.length === 0) {
    return composeFallbackMessage(context, route);
  }

  return paragraphCandidates
    .join("\n\n")
    .replace(/:\s*$/, ".")
    .trim();
}

function truncateParagraphCleanly(value, maxChars = 280) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (!text) return "";
  if (text.length <= maxChars) return text;

  const window = text.slice(0, maxChars + 1);
  const sentenceBreak = Math.max(
    window.lastIndexOf(". "),
    window.lastIndexOf("! "),
    window.lastIndexOf("? ")
  );
  if (sentenceBreak >= Math.floor(maxChars * 0.55)) {
    return window.slice(0, sentenceBreak + 1).trim();
  }

  const wordBreak = window.lastIndexOf(" ");
  if (wordBreak >= Math.floor(maxChars * 0.7)) {
    const cut = window.slice(0, wordBreak).trim();
    return /[.!?]$/.test(cut) ? cut : `${cut}.`;
  }

  const hardCut = text.slice(0, maxChars).trim();
  return /[.!?]$/.test(hardCut) ? hardCut : `${hardCut}.`;
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
  const hasActionBlockGrounding = hasGroundableActionBlocks(context);

  for (const item of rawItems) {
    const rawSection = nonEmptyString(item?.section);
    const rawField = nonEmptyString(item?.field);
    if (!rawSection || !rawField) continue;
    const labels = normalizeGroundingLabels(rawSection, rawField);
    if (!hasActionBlockGrounding && labels.section === "Action Blocks") continue;
    const section = truncate(labels.section, 64);
    const field = truncate(labels.field, 96);
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
    const labels = normalizeGroundingLabels(item.section, item.field);
    const key = `${labels.section.toLowerCase()}|${labels.field.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    normalized.push({
      section: truncate(labels.section, 64),
      field: truncate(labels.field, 96),
      timestamp: normalizeGroundingTimestamp(item.timestamp)
    });
  }
  return normalized.slice(0, maxItems);
}

function normalizeGroundingLabels(section, field) {
  const rawSection = String(section || "").trim();
  const rawField = String(field || "").trim();
  const combined = `${rawSection}.${rawField}`.toLowerCase();

  const mapField = () => {
    if (combined.includes("fulfillmentcategories") && combined.includes(".name")) return "Fulfillment Area";
    if (combined.includes("currentweekactionblocks")) return "Current Week Actions";
    if (combined.includes("capture.totalcount")) return "Capture Count";
    if (combined.includes("datainventory")) return "Data Inventory";
    if (combined.includes("appguide")) return "App Guide";
    if (combined.includes("mission")) return "Mission";
    if (combined.includes("vision")) return "Vision";
    if (combined.includes("purpose")) return "Purpose";
    if (combined.includes("passion")) return "Passions";
    if (combined.includes("identity")) return "Identity";
    if (combined.includes("littlewin") || combined.includes("little_win")) return "Little Wins";
    if (combined.includes("outcome") || combined.includes("goal")) return "Goals";
    if (combined.includes("actionblock") || combined.includes("currentweekactionblocks") || combined.includes("actions")) {
      return "Action Blocks";
    }
    if (combined.includes("capture")) return "Capture";
    if (combined.includes("diagnostic") || combined.includes("personalization")) return "Diagnostic";
    if (combined.includes("inventory")) return "Data Inventory";
    if (combined.includes("guide")) return "App Guide";
    return humanizeGroundingPath(rawField) || "Context";
  };

  const mapSection = () => {
    if (combined.includes("purpose") || combined.includes("vision") || combined.includes("passion")) return "Purpose";
    if (combined.includes("fulfillment") || combined.includes("mission") || combined.includes("identity") || combined.includes("littlewin")) {
      return "Fulfillment";
    }
    if (combined.includes("outcome") || combined.includes("goal")) return "Goals";
    if (combined.includes("actionblock") || combined.includes("currentweekactionblocks")) return "Action Blocks";
    if (combined.includes("capture")) return "Capture";
    if (combined.includes("diagnostic") || combined.includes("personalization")) return "Diagnostic";
    if (combined.includes("inventory")) return "Data Inventory";
    if (combined.includes("guide")) return "App Guide";
    return humanizeGroundingPath(rawSection) || "Context";
  };

  return {
    section: mapSection(),
    field: mapField()
  };
}

function humanizeGroundingPath(value) {
  const text = String(value || "").trim();
  if (!text) return "";
  const noIndexes = text
    .replace(/\[[0-9]+\]/g, "")
    .replace(/\[[^\]]*\]/g, "");
  const segments = noIndexes.split(".").map((part) => part.trim()).filter(Boolean);
  const tail = segments.length > 0 ? segments[segments.length - 1] : "";
  if (!tail) return "";
  const spaced = tail
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!spaced) return "";
  return spaced
    .split(" ")
    .map((word) => (word ? `${word.charAt(0).toUpperCase()}${word.slice(1)}` : ""))
    .join(" ");
}

function buildFallbackGrounding(context, route) {
  const items = [];
  const hasActionBlockGrounding = hasGroundableActionBlocks(context);
  const add = (section, field, timestamp) => {
    if (!section || !field) return;
    if (section === "Action Blocks" && !hasActionBlockGrounding) return;
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
    if (hasActionBlockGrounding) {
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
  if (hasActionBlockGrounding) {
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

function hasGroundableActionBlocks(context) {
  const blocks = Array.isArray(context?.currentWeekActionBlocks) ? context.currentWeekActionBlocks : [];
  if (blocks.length === 0) return false;
  return blocks.some((item) => {
    const actions = Array.isArray(item?.actions) ? item.actions : [];
    const hasAction = actions.some((action) => nonEmptyString(action));
    const hasTitle = Boolean(nonEmptyString(item?.title));
    return hasAction || hasTitle;
  });
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
  const routeCards = buildRouteSuggestionCards(route, context);
  if (level === "low") {
    return routeCards;
  }

  const normalizedCards = normalizeSuggestionCards(inputCards, context);
  if (normalizedCards.length > 0) return normalizedCards;

  if (routeCards.length > 0) return routeCards;

  return actionsToSuggestionCards(inputActions, context);
}

function normalizeSuggestionCards(inputCards, context) {
  const source = Array.isArray(inputCards) ? inputCards : [];
  const cards = [];
  const seen = new Set();

  for (const card of source) {
    const title = truncate(normalizeModelCopy(nonEmptyString(card?.title)), 120);
    if (!title) continue;
    const description = "";
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
    const title = truncate(normalizeModelCopy(nonEmptyString(option?.title)), 120);
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
    description: "",
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
    const category = resolveCategoryFromRouteTarget(target, context);
    const options = buildLittleWinRouteOptions({ category, categoryId, target, context });
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
    const category = target || "this area";
    const categoryRecord = resolveCategoryFromRouteTarget(category, context);
    const categoryIdForIdentity = categoryId || firstCategoryIdFromContext(context);
    const existingIdentities = uniqueOrdered(
      (Array.isArray(categoryRecord?.identity) ? categoryRecord.identity : [])
        .map((item) => normalizeModelCopy(nonEmptyString(item)))
        .filter(Boolean)
    );
    const shouldReplaceIdentity = existingIdentities.length >= 3;
    const replaceIdentityTargets = shouldReplaceIdentity
      ? chooseIdentityReplacementTargets(existingIdentities, category, 3)
      : [];
    const identityCandidates = ["Clear Communicator", "Consistent Connector", "Calm Finisher"];
    const options = identityCandidates.map((identity, index) => {
      if (shouldReplaceIdentity) {
        const replaceIdentityTarget =
          replaceIdentityTargets.length > 0
            ? replaceIdentityTargets[index % replaceIdentityTargets.length]
            : "";
        return {
          title: `Replace "${truncate(replaceIdentityTarget, 64)}" with "${identity}"`,
          type: "replaceFulfillmentIdentity",
          payload: {
            categoryId: categoryIdForIdentity,
            categoryName: category,
            replaceIdentity: replaceIdentityTarget,
            identity
          }
        };
      }
      return {
        title: identity,
        type: "addFulfillmentIdentity",
        payload: { categoryId: categoryIdForIdentity, categoryName: category, identity }
      };
    });
    return [buildCardFromOptions(`Identity options for ${category}`, "", options, context)];
  }

  if (route.id === 4) {
    const goalName = target || "this goal";
    const goal = resolveGoalFromRouteTarget(goalName, context);
    const options = buildGoalExecutionOptions({
      goalName,
      goalCategory: nonEmptyString(goal?.category),
      context,
      variant: "next"
    });
    return [buildCardFromOptions(`Next steps for ${goalName}`, "Choose one goal-supporting action.", options, context)];
  }

  if (route.id === 5) {
    const goalName = target || "this goal";
    const goal = resolveGoalFromRouteTarget(goalName, context);
    const options = buildGoalExecutionOptions({
      goalName,
      goalCategory: nonEmptyString(goal?.category),
      context,
      variant: "plan"
    });
    return [buildCardFromOptions(`Plan for ${goalName}`, "Choose one action to add now.", options, context)];
  }

  if (route.id === 6) {
    const passionType = normalizePassionType(target || "love");
    const options = buildPassionRouteOptions({ passionType, context });
    return [buildCardFromOptions(`New passions for ${passionType}`, "Choose one passion to add.", options, context)];
  }

  if (route.id === 7) {
    const options = [
      { title: "Vision option A", type: "updatePurposeVision", payload: { text: "I build a life where my daily actions match my long-term values and commitments." } },
      { title: "Vision option B", type: "updatePurposeVision", payload: { text: "I create steady progress across the areas that matter most by finishing the right work each week." } },
      { title: "Vision option C", type: "updatePurposeVision", payload: { text: "I live with clear direction, focused execution, and systems that support meaningful growth." } }
    ];
    return [buildCardFromOptions("New Purpose Vision", "Choose one vision rewrite.", options, context)];
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
    description: "",
    options: normalizedOptions
  };
}

function stripSuggestionCardCommentary(cards) {
  const source = Array.isArray(cards) ? cards : [];
  return source.map((card) => ({
    ...card,
    description: ""
  }));
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

function resolveCategoryFromRouteTarget(target, context) {
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  if (!target) return categories[0] || null;
  const found = categories.find(
    (item) => String(item?.name || "").trim().toLowerCase() === target.toLowerCase()
  );
  return found || categories[0] || null;
}

function resolveGoalFromRouteTarget(target, context) {
  const goals = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes : [];
  if (!target) return goals[0] || null;
  const found = goals.find(
    (item) => String(item?.title || "").trim().toLowerCase() === target.toLowerCase()
  );
  return found || goals[0] || null;
}

function buildGoalExecutionOptions({ goalName, goalCategory, context, variant = "plan" }) {
  const normalizedGoal = nonEmptyString(goalName) || "this goal";
  const templates = goalExecutionTemplates(normalizedGoal, variant);
  const category = resolveCategoryFromRouteTarget(goalCategory, context);
  const categoryId = nonEmptyString(category?.id) || firstCategoryIdFromContext(context);
  const existingLittleWins = uniqueOrdered(
    (Array.isArray(category?.littleWins) ? category.littleWins : [])
      .map((item) => normalizeModelCopy(nonEmptyString(item)))
      .filter(Boolean)
  );
  const shouldReplaceLittleWin = Boolean(categoryId) && existingLittleWins.length >= 3;
  const replaceTargets = shouldReplaceLittleWin
    ? chooseLittleWinReplacementTargets(existingLittleWins, nonEmptyString(category?.name), templates.littleWins.length)
    : [];

  const littleWinActions = templates.littleWins.map((activity, index) => {
    const cleanedActivity = truncate(normalizeModelCopy(nonEmptyString(activity)), 120);
    if (!cleanedActivity) return null;
    if (!categoryId) {
      return {
        title: cleanedActivity,
        type: "createCaptureAction",
        payload: { text: cleanedActivity }
      };
    }
    if (shouldReplaceLittleWin) {
      const replaceActivity =
        replaceTargets[index % Math.max(1, replaceTargets.length)] || existingLittleWins[index % existingLittleWins.length];
      return {
        title: `Replace "${truncate(replaceActivity, 64)}" with "${cleanedActivity}"`,
        type: "replaceLittleWin",
        payload: {
          categoryId,
          activity: cleanedActivity,
          replaceActivity
        }
      };
    }
    return {
      title: cleanedActivity,
      type: "addLittleWin",
      payload: {
        categoryId,
        activity: cleanedActivity,
        appleHealthEligible: inferAppleHealthEligibility(cleanedActivity, goalCategory || nonEmptyString(category?.name))
      }
    };
  }).filter(Boolean);

  const captureActions = templates.capture.map((text) => {
    const cleaned = truncate(normalizeModelCopy(nonEmptyString(text)), 140);
    if (!cleaned) return null;
    return {
      title: cleaned,
      type: "createCaptureAction",
      payload: { text: cleaned }
    };
  }).filter(Boolean);

  const deduped = [];
  const seen = new Set();
  for (const option of [...littleWinActions, ...captureActions]) {
    if (!option || typeof option !== "object") continue;
    const type = nonEmptyString(option.type);
    const title = nonEmptyString(option.title);
    if (!type || !title) continue;
    const payload = option.payload && typeof option.payload === "object" ? option.payload : {};
    const dedupeKey = `${type}|${title.toLowerCase()}|${JSON.stringify(payload)}`;
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    deduped.push(option);
    if (deduped.length >= 3) break;
  }
  return deduped;
}

function goalExecutionTemplates(goalName, variant) {
  const lower = nonEmptyString(goalName).toLowerCase();
  const isWeightGoal = /\b(lose|loss|weight|lbs?|kg|fat|diet|walk|gym|cardio)\b/.test(lower);
  const isFinanceGoal = /\b(save|debt|money|finance|budget|income|net worth|invest)\b/.test(lower);

  if (isWeightGoal) {
    const littleWins = variant === "next"
      ? ["Follow diet plan today", "Walk 30 minutes today"]
      : ["Follow diet plan daily", "Walk 30 minutes daily"];
    return {
      littleWins,
      capture: ["Sign up for gym", "Shop for healthy food", "Prep healthy meals for 2 days"]
    };
  }

  if (isFinanceGoal) {
    const littleWins = variant === "next"
      ? ["Track every purchase today", "Review account balances"]
      : ["Track spending daily", "Move money to savings daily"];
    return {
      littleWins,
      capture: ["Set up auto-transfer to savings", "Cancel one unused subscription", "Create a debt payoff checklist"]
    };
  }

  return {
    littleWins: [
      `15-minute progress on ${truncate(goalName, 64)}`,
      `Daily check-in for ${truncate(goalName, 64)}`
    ],
    capture: [
      `Create a weekly checklist for ${truncate(goalName, 64)}`,
      `Schedule one focused block for ${truncate(goalName, 64)}`,
      `List one blocker and one fix for ${truncate(goalName, 64)}`
    ]
  };
}

const LITTLE_WIN_CORPUS_BY_CATEGORY = {
  "Career & Business": [
    "Plan top priorities",
    "Deep work session",
    "Follow up contact",
    "Request feedback",
    "Protect focus block",
    "Plan tomorrow priorities"
  ],
  "Faith & Spirituality": [
    "Morning prayer",
    "Scripture reading",
    "Quiet meditation",
    "Gratitude reflection",
    "Pray for others",
    "Practice stillness"
  ],
  "Wealth & Finance": [
    "Review daily spending",
    "Track one expense",
    "Check account balances",
    "Transfer small savings",
    "Cancel unused subscription",
    "Pay extra debt",
    "Review financial plan",
    "Organize financial documents"
  ],
  "Love & Relationships": [
    "Send appreciation text",
    "10-minute check-in",
    "Ask one deeper question",
    "Offer one act of help",
    "Plan quality time",
    "Share one gratitude"
  ],
  "Health & Energy": [
    "10-minute walk",
    "Hydrate before lunch",
    "Prepare one healthy meal",
    "Sleep prep 30 minutes early",
    "15-minute mobility session",
    "Mindfulness break"
  ],
  "default": [
    "Plan tomorrow priorities",
    "Complete one 15-minute task",
    "Clear one small blocker",
    "Do one focused reset",
    "Review progress briefly",
    "Close one open loop"
  ]
};

function buildLittleWinRouteOptions({ category, categoryId, target, context }) {
  const categoryName = nonEmptyString(category?.name) || nonEmptyString(target) || "this area";
  const existingLittleWins = uniqueOrdered(
    (Array.isArray(category?.littleWins) ? category.littleWins : [])
      .map((item) => normalizeModelCopy(nonEmptyString(item)))
      .filter(Boolean)
  );
  const candidateTitles = selectLittleWinCandidates({
    categoryName,
    category,
    context,
    existingLittleWins
  });

  if (candidateTitles.length > 0) {
    const shouldReplace = existingLittleWins.length >= 3;
    const replaceActivityTargets = shouldReplace
      ? chooseLittleWinReplacementTargets(existingLittleWins, categoryName, candidateTitles.length)
      : [];
    return candidateTitles.map((title, index) => {
      if (shouldReplace) {
        const replaceActivity =
          replaceActivityTargets.length > 0
            ? replaceActivityTargets[index % replaceActivityTargets.length]
            : existingLittleWins[index % existingLittleWins.length];
        return {
          title: `Replace "${truncate(replaceActivity, 64)}" with "${truncate(title, 72)}"`,
          type: "replaceLittleWin",
          payload: {
            categoryId,
            activity: title,
            replaceActivity
          }
        };
      }
      return {
        title,
        type: "addLittleWin",
        payload: {
          categoryId,
          activity: title,
          appleHealthEligible: inferAppleHealthEligibility(title, categoryName)
        }
      };
    });
  }

  return [
    {
      title: `10-minute step for ${categoryName}`,
      type: "addLittleWin",
      payload: { categoryId, activity: `10-minute step for ${categoryName}`, appleHealthEligible: false }
    },
    {
      title: `15-minute reset for ${categoryName}`,
      type: "addLittleWin",
      payload: { categoryId, activity: `15-minute reset for ${categoryName}`, appleHealthEligible: false }
    },
    {
      title: `20-minute completion block for ${categoryName}`,
      type: "addLittleWin",
      payload: { categoryId, activity: `20-minute completion block for ${categoryName}`, appleHealthEligible: false }
    }
  ];
}

function buildPassionRouteOptions({ passionType, context }) {
  const normalizedType = normalizePassionType(passionType || "love");
  const purpose = nonEmptyString(context?.drivingForce?.purpose);
  const vision = nonEmptyString(context?.drivingForce?.vision);
  const diagnosticRoot = nonEmptyString(context?.diagnostic?.rootCause);
  const diagnosticDirection = nonEmptyString(context?.diagnostic?.nextDirection);
  const firstGoal = Array.isArray(context?.activeOutcomes) ? context.activeOutcomes[0] : null;
  const firstGoalTitle = nonEmptyString(firstGoal?.title);
  const purposeCue = purpose || vision ? "in line with your purpose and vision" : "with clear intention";
  const diagnosticCue = diagnosticDirection || diagnosticRoot
    ? truncate(nonEmptyString(diagnosticDirection) || nonEmptyString(diagnosticRoot), 64)
    : "";

  let textCandidates;
  if (normalizedType === "love") {
    textCandidates = [
      "Choosing connection and compassion daily, even when your schedule feels noisy.",
      `Showing up with patience and follow-through ${purposeCue}.`,
      "Strengthening trust by keeping one small promise every day."
    ];
  } else if (normalizedType === "vows") {
    textCandidates = [
      "Honoring long-term commitments with steady weekly execution.",
      "Choosing discipline over drift through repeatable systems.",
      "Building identity through consistent follow-through on the right work."
    ];
  } else if (normalizedType === "thrill") {
    textCandidates = [
      "Creating breakthrough momentum by finishing one meaningful challenge each week.",
      "Turning pressure into progress through focused execution blocks.",
      `Pursuing high-impact wins with courage, clarity, and measurable follow-through${firstGoalTitle ? ` toward ${firstGoalTitle}` : ""}.`
    ];
  } else {
    textCandidates = [
      "Refusing avoidance by naming the hardest truth and acting on it immediately.",
      "Confronting drift with one direct, measurable action every day.",
      `Eliminating vague busyness by replacing it with concrete execution${diagnosticCue ? ` (${diagnosticCue})` : ""}.`
    ];
  }

  const uniqueTexts = uniqueOrdered(
    textCandidates
      .map((item) => normalizeModelCopy(nonEmptyString(item)))
      .filter(Boolean)
      .map((item) => truncate(item, 120))
  ).slice(0, 3);

  return uniqueTexts.map((text) => ({
    title: text,
    type: "addPassionItem",
    payload: {
      passionType: normalizedType,
      text
    }
  }));
}

function extractActionHintsForCategory(categoryName, context) {
  const blocks = Array.isArray(context?.currentWeekActionBlocks) ? context.currentWeekActionBlocks : [];
  const filtered = blocks.filter((block) => {
    const title = nonEmptyString(block?.title).toLowerCase();
    const category = nonEmptyString(block?.category).toLowerCase();
    const target = nonEmptyString(categoryName).toLowerCase();
    return target && (title === target || category === target);
  });
  const source = filtered.length > 0 ? filtered : blocks.slice(0, 1);
  const items = [];
  for (const block of source) {
    const actions = Array.isArray(block?.actions) ? block.actions : [];
    for (const action of actions) {
      const text = normalizeModelCopy(nonEmptyString(action));
      if (!text) continue;
      items.push(text);
      if (items.length >= 3) return items;
    }
  }
  return items;
}

function selectLittleWinCandidates({ categoryName, category, context, existingLittleWins }) {
  const normalizedCategory = normalizeLittleWinCorpusCategory(categoryName);
  const corpus = LITTLE_WIN_CORPUS_BY_CATEGORY[normalizedCategory] || LITTLE_WIN_CORPUS_BY_CATEGORY.default;
  const existingNorm = existingLittleWins.map(normalizeLittleWinForCompare).filter(Boolean);
  const mission = normalizeModelCopy(nonEmptyString(category?.mission));
  const purpose = normalizeModelCopy(nonEmptyString(context?.drivingForce?.purpose));
  const actionHints = extractActionHintsForCategory(categoryName, context);
  const signalText = [mission, purpose, ...actionHints].join(" ").toLowerCase();

  const scored = corpus
    .map((item) => normalizeModelCopy(nonEmptyString(item)))
    .filter(Boolean)
    .filter((item) => {
      const normalized = normalizeLittleWinForCompare(item);
      if (!normalized) return false;
      if (existingNorm.includes(normalized)) return false;
      return !isLittleWinSuggestionTooSimilarToExisting(item, existingLittleWins);
    })
    .map((item) => ({
      item,
      score: scoreLittleWinCandidate(item, normalizedCategory, signalText)
    }))
    .sort((a, b) => b.score - a.score || a.item.localeCompare(b.item))
    .map((row) => row.item);

  if (scored.length >= 3) return scored.slice(0, 3);

  const fallbacks = uniqueOrdered([
    ...scored,
    mission ? `15-minute action toward: ${truncate(mission, 64)}` : "",
    `10-minute step for ${categoryName}`,
    `15-minute reset for ${categoryName}`,
    `Close one open loop for ${categoryName}`
  ].filter(Boolean));
  return fallbacks
    .filter((item) => !isLittleWinSuggestionTooSimilarToExisting(item, existingLittleWins))
    .slice(0, 3);
}

function normalizeLittleWinCorpusCategory(category) {
  const lowered = nonEmptyString(category).toLowerCase();
  if (lowered === "health & vitality") return "Health & Energy";
  if (lowered === "wealth & lifestyle") return "Wealth & Finance";
  if (lowered === "mind & meaning") return "Mindset & Resilience";
  if (lowered === "leadership & impact") return "Service & Impact";
  return nonEmptyString(category);
}

function scoreLittleWinCandidate(candidate, categoryName, signalText) {
  const text = nonEmptyString(candidate).toLowerCase();
  if (!text) return 0;
  let score = 0;
  const categoryKeywords = categoryKeywordSet(categoryName);
  for (const keyword of categoryKeywords) {
    if (text.includes(keyword)) score += 2;
    if (signalText.includes(keyword)) score += 1;
  }
  const candidateTokens = new Set(text.split(/\s+/).filter(Boolean));
  const signalTokens = new Set(String(signalText || "").split(/\s+/).filter(Boolean));
  for (const token of candidateTokens) {
    if (token.length >= 4 && signalTokens.has(token)) score += 1;
  }
  if (/\b(review|track|check|plan|organize|transfer|cancel|pay)\b/.test(text)) score += 1;
  if (text.split(/\s+/).length <= 5) score += 1;
  return score;
}

function categoryKeywordSet(categoryName) {
  const key = nonEmptyString(categoryName).toLowerCase();
  if (key.includes("wealth") || key.includes("finance") || key.includes("money")) {
    return ["budget", "spend", "expense", "account", "saving", "subscription", "debt", "financial", "money"];
  }
  if (key.includes("faith") || key.includes("spiritual")) {
    return ["prayer", "scripture", "gratitude", "meditation", "reflect"];
  }
  if (key.includes("love") || key.includes("relationship")) {
    return ["check", "gratitude", "listen", "quality", "support", "text"];
  }
  if (key.includes("health") || key.includes("energy")) {
    return ["walk", "sleep", "workout", "hydrate", "mindfulness"];
  }
  return ["plan", "review", "track", "organize"];
}

function chooseLittleWinReplacementTargets(existingLittleWins, categoryName, maxCount = 3) {
  const source = Array.isArray(existingLittleWins) ? existingLittleWins : [];
  if (source.length === 0) return [];
  const keywords = categoryKeywordSet(categoryName);
  const scored = source.map((item) => {
    const text = nonEmptyString(item).toLowerCase();
    let relevance = 0;
    for (const keyword of keywords) {
      if (text.includes(keyword)) relevance += 1;
    }
    if (/\breset\b|\bcleanup\b|\bgeneral\b/.test(text)) relevance -= 1;
    return { item, relevance };
  }).sort((a, b) => a.relevance - b.relevance || a.item.localeCompare(b.item));
  const limit = Math.max(1, Math.floor(Number(maxCount) || 3));
  return scored
    .map((row) => nonEmptyString(row?.item))
    .filter(Boolean)
    .slice(0, Math.min(limit, source.length));
}

function chooseIdentityReplacementTargets(existingIdentities, categoryName, maxCount = 3) {
  const source = Array.isArray(existingIdentities) ? existingIdentities : [];
  if (source.length === 0) return [];
  const keywords = categoryKeywordSet(categoryName);
  const scored = source.map((item) => {
    const text = nonEmptyString(item).toLowerCase();
    let relevance = 0;
    for (const keyword of keywords) {
      if (text.includes(keyword)) relevance += 1;
    }
    if (/\bhelper\b|\bgood\b|\bbetter\b|\bbest\b/.test(text)) relevance -= 1;
    return { item, relevance };
  }).sort((a, b) => a.relevance - b.relevance || a.item.localeCompare(b.item));
  const limit = Math.max(1, Math.floor(Number(maxCount) || 3));
  return scored
    .map((row) => nonEmptyString(row?.item))
    .filter(Boolean)
    .slice(0, Math.min(limit, source.length));
}

function isLittleWinSuggestionTooSimilarToExisting(candidate, existing) {
  const candidateNorm = normalizeLittleWinForCompare(candidate);
  if (!candidateNorm) return false;
  const candidateTokens = new Set(candidateNorm.split(" ").filter(Boolean));
  const source = Array.isArray(existing) ? existing : [];
  for (const item of source) {
    const itemNorm = normalizeLittleWinForCompare(item);
    if (!itemNorm) continue;
    if (itemNorm === candidateNorm) return true;
    if (candidateNorm.includes(itemNorm) || itemNorm.includes(candidateNorm)) return true;
    const itemTokens = new Set(itemNorm.split(" ").filter(Boolean));
    if (itemTokens.size === 0) continue;
    const overlap = [...candidateTokens].filter((token) => itemTokens.has(token)).length;
    const ratio = overlap / Math.max(1, Math.min(candidateTokens.size, itemTokens.size));
    if (ratio >= 0.6) return true;
  }
  return false;
}

function normalizeLittleWinForCompare(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function inferAppleHealthEligibility(activity, categoryName) {
  const lower = `${nonEmptyString(activity)} ${nonEmptyString(categoryName)}`.toLowerCase();
  return /\b(steps?|walk|run|workout|exercise|sleep|mindful|mindfulness|active minutes?|calories?)\b/.test(lower);
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
  suggestionCards = stripSuggestionCardCommentary(suggestionCards.slice(0, 3));

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
  const text = normalizeModelCopy(message, { preserveNewlines: true });
  if (!text) return "";
  const lines = text.split(/\n+/).map((line) => line.trim()).filter(Boolean);
  const blocked = [
    /\bsources?\b/i,
    /\bwhich should i (add|edit|replace|choose)\b/i,
    /\boption [abc]\b/i,
    /\bchoose (a|b|c)\b/i,
    /\bhere (are|is)\b.*\boptions?\b/i,
    /\b(the )?(options|suggestions) below\b/i,
    /\b(pick|choose) (one|an option)\b/i
  ];
  const kept = lines.filter((line) => !blocked.some((pattern) => pattern.test(line)));
  return kept.join("\n\n").replace(/:\s*$/, ".").trim();
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
  "addFulfillmentIdentity",
  "replaceFulfillmentIdentity",
  "addLittleWin",
  "replaceLittleWin",
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

    const title = normalizeModelCopy(String(action?.title || "").replace(/\s+/g, " ").trim());
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
  const text = normalizeModelCopy(nonEmptyString(src.text));
  const categoryId = nonEmptyString(src.categoryId || src.categoryID);
  const categoryName = nonEmptyString(src.categoryName || src.category);

  switch (type) {
    case "updatePurposeVision":
      return text ? { text: truncate(text, 260) } : null;
    case "addPassionItem": {
      const passionType = normalizePassionType(src.passionType || src.emotion || "love");
      if (!text) return null;
      return { passionType, text: truncate(text, 120) };
    }
    case "updateFulfillmentMission": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      if (!validCategoryId || !text) return null;
      return { categoryId: validCategoryId, text: truncate(text, 240) };
    }
    case "addFulfillmentIdentity": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const identity = normalizeModelCopy(nonEmptyString(src.identity || src.role || src.text));
      if (!validCategoryId || !identity) return null;
      const resolvedCategoryName = resolveCategoryNameById(validCategoryId, context);
      return {
        categoryId: validCategoryId,
        categoryName: truncate(nonEmptyString(categoryName) || resolvedCategoryName, 72),
        identity: truncate(identity, 120)
      };
    }
    case "replaceFulfillmentIdentity": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const identity = normalizeModelCopy(nonEmptyString(src.identity || src.role || src.text));
      const replaceIdentity = normalizeModelCopy(nonEmptyString(src.replaceIdentity || src.oldIdentity));
      if (!validCategoryId || !identity || !replaceIdentity) return null;
      const resolvedCategoryName = resolveCategoryNameById(validCategoryId, context);
      return {
        categoryId: validCategoryId,
        categoryName: truncate(nonEmptyString(categoryName) || resolvedCategoryName, 72),
        replaceIdentity: truncate(replaceIdentity, 120),
        identity: truncate(identity, 120)
      };
    }
    case "addLittleWin": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const activity = normalizeModelCopy(nonEmptyString(src.activity || src.text));
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
    case "replaceLittleWin": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const activity = normalizeModelCopy(nonEmptyString(src.activity || src.text));
      const replaceActivity = normalizeModelCopy(nonEmptyString(src.replaceActivity || src.oldActivity));
      if (!validCategoryId || !activity || !replaceActivity) return null;
      return {
        categoryId: validCategoryId,
        activity: truncate(activity, 140),
        replaceActivity: truncate(replaceActivity, 140)
      };
    }
    case "createOutcome": {
      const validCategoryId = normalizeCategoryId(categoryId, categoryName, context);
      const title = normalizeModelCopy(nonEmptyString(src.title || src.text));
      if (!validCategoryId || !title) return null;
      const measurable =
        typeof src.measurable === "boolean"
          ? src.measurable
          : String(src.measurable || "").toLowerCase() === "true";
      const unit = normalizeModelCopy(nonEmptyString(src.unit));
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

function resolveCategoryNameById(categoryId, context) {
  const id = nonEmptyString(categoryId);
  if (!id) return "";
  const categories = Array.isArray(context?.fulfillmentCategories) ? context.fulfillmentCategories : [];
  const found = categories.find((item) => nonEmptyString(item?.id).toLowerCase() === id.toLowerCase());
  return nonEmptyString(found?.name);
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
