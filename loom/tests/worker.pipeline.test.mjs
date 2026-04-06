import test from "node:test";
import assert from "node:assert/strict";
import { __test } from "../worker.js";

const mockContext = {
  generatedAt: "2026-03-05T10:00:00.000Z",
  sectionTimestamps: {
    purpose: "2026-03-05T09:00:00.000Z",
    fulfillment: "2026-03-04T09:00:00.000Z",
    outcomes: "2026-03-03T09:00:00.000Z",
    capture: "2026-03-02T09:00:00.000Z",
    actionBlocks: "2026-03-01T09:00:00.000Z"
  },
  drivingForce: {
    vision: "Build a life of calm execution and meaningful progress.",
    purpose: "End stress through focused follow-through.",
    passions: [{ emotion: "love", title: "Deep learning" }]
  },
  fulfillmentCategories: [{
    id: "11111111-1111-4111-8111-111111111111",
    name: "Health & Vitality",
    mission: "Maintain steady physical and mental energy."
  }],
  activeOutcomes: [{
    id: "22222222-2222-4222-8222-222222222222",
    title: "Sleep 7+ hours",
    category: "Health & Vitality",
    progressSummary: "Current 5 / Goal 7"
  }],
  currentWeekActionBlocks: [{ title: "Morning routine block" }],
  capture: { totalCount: 12, quickCompletionsLast7Days: 4 },
  dataInventory: [{ title: "Goals/Outcomes" }],
  appGuide: [{ title: "Action Blocks Workflow" }]
};

test("route 6 normalizes legacy 'just' emotion alias", () => {
  const route = __test.resolveChipIntentRoute("New passions for just");
  assert.equal(route?.id, 6);
  assert.equal(route?.target, "hate");
});

test("heuristic routing maps loose goal prompts to the right route and target", () => {
  const nextRoute = __test.detectHeuristicIntentRoute("What should I do next for Sleep 7+ hours?", mockContext);
  const planRoute = __test.detectHeuristicIntentRoute("Help me plan Sleep 7+ hours this week.", mockContext);

  assert.equal(nextRoute?.id, 4);
  assert.equal(nextRoute?.target, "Sleep 7+ hours");
  assert.equal(planRoute?.id, 5);
  assert.equal(planRoute?.target, "Sleep 7+ hours");
});

test("personalization brief carries the live goal, area, and action plan context", () => {
  const brief = __test.buildChatPersonalizationBrief({
    context: mockContext,
    latestUserMessage: "How should I plan Sleep 7+ hours this week?",
    route: { id: 5, key: "goal_plan", target: "Sleep 7+ hours" },
    unrelatedPrompt: false
  });

  assert.equal(brief.routeKey, "goal_plan");
  assert.match(brief.direction, /End stress|calm execution/i);
  assert.match(brief.fulfillmentArea, /Health & Vitality/i);
  assert.match(brief.goal, /Sleep 7\+ hours/i);
  assert.match(brief.actionPlan, /Morning routine block/i);
});

test("generic-response detector flags broad filler when no specific context appears", () => {
  assert.equal(
    __test.looksLikeGenericLoomChatMessage(
      "Start small, stay consistent, and build momentum this week.",
      mockContext,
      { route: { id: 5, key: "goal_plan", target: "Sleep 7+ hours" }, prompt: "How should I approach Sleep 7+ hours?" }
    ),
    true
  );

  assert.equal(
    __test.looksLikeGenericLoomChatMessage(
      '[[O:Sleep 7+ hours]] is the live target inside [[F:Health & Vitality]], so the answer should stay tied to that structure this week.',
      mockContext,
      { route: { id: 5, key: "goal_plan", target: "Sleep 7+ hours" }, prompt: "How should I approach Sleep 7+ hours?" }
    ),
    false
  );
});

test("sanitizeLoomChatResponse does not inject deterministic route cards on low confidence", () => {
  const output = __test.sanitizeLoomChatResponse({
    message: "Use one of these options.",
    grounding: [],
    suggestionCards: [],
    nextAction: null,
    chips: [],
    actions: [],
    debug: { usedContext: true, confidence: "low", evidence: ["drivingForce.vision"] }
  }, {
    context: mockContext,
    hasContext: true,
    latestUserMessage: "New passions for Love",
    intent: "loomai_chat"
  });

  assert.equal(output.suggestionCards.length, 0);
  assert.equal(output.actions.length, 0);
});

test("sanitizeLoomChatResponse preserves model-provided suggestion cards for routed prompts", () => {
  const output = __test.sanitizeLoomChatResponse({
    message: '[[O:Sleep 7+ hours]] needs a tighter plan this week.',
    grounding: [],
    suggestionCards: [{
      id: "goal-plan",
      title: "Plan for Sleep 7+ hours",
      description: "",
      options: [{
        id: "goal-plan-a",
        label: "A",
        title: "Set bedtime alarm for 10:30 PM",
        type: "createCaptureAction",
        payload: { text: "Set bedtime alarm for 10:30 PM" }
      }]
    }],
    nextAction: null,
    chips: [],
    actions: [],
    debug: { usedContext: true, confidence: "high", evidence: ["activeOutcomes[0].title"] }
  }, {
    context: mockContext,
    hasContext: true,
    latestUserMessage: "Plan for Sleep 7+ hours",
    intent: "loomai_chat"
  });

  assert.equal(output.suggestionCards.length, 1);
  assert.equal(output.suggestionCards[0].title, "Plan for Sleep 7+ hours");
  assert.equal(output.suggestionCards[0].options[0].type, "createCaptureAction");
});
