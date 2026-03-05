import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { __test } from "../worker.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const snapshotPath = path.join(__dirname, "__snapshots__", "worker.pipeline.snapshots.json");

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

const chipPrompts = [
  "Daily Little Wins for Health & Vitality",
  "New Mission for Health & Vitality",
  "New Identity for Health & Vitality",
  "Next step for Sleep 7+ hours",
  "Plan for Sleep 7+ hours",
  "New passions for Love",
  "Improve my Purpose Vision",
  "How can I best use Loom?"
];

function runCase(prompt) {
  const route = __test.resolveChipIntentRoute(prompt);
  const suggestionCards = __test.buildSuggestionCards([], [], {
    context: mockContext,
    confidence: "medium",
    route
  });
  const grounding = __test.collectGrounding([], mockContext, { route, maxItems: 4 });
  const output = __test.validateOutput({
    message: "You can make focused progress this week.",
    grounding,
    suggestionCards,
    nextAction: null,
    chips: [],
    actions: [],
    debug: { usedContext: true, confidence: "medium", evidence: ["drivingForce.vision"] }
  }, {
    context: mockContext,
    hasContext: true,
    route
  });

  return {
    routeID: route?.id ?? null,
    routeKey: route?.key ?? null,
    suggestionCardCount: output.suggestionCards.length,
    suggestionCardTitle: output.suggestionCards[0]?.title ?? "",
    optionTypes: (output.suggestionCards[0]?.options ?? []).map((item) => item.type),
    nextActionType: output.nextAction?.type ?? "",
    groundingFields: output.grounding.map((item) => `${item.section}|${item.field}`),
    message: output.message
  };
}

test("worker pipeline snapshots for chip intents 1-8", () => {
  const actual = Object.fromEntries(chipPrompts.map((prompt) => [prompt, runCase(prompt)]));

  if (process.env.UPDATE_SNAPSHOTS === "1") {
    fs.mkdirSync(path.dirname(snapshotPath), { recursive: true });
    fs.writeFileSync(snapshotPath, `${JSON.stringify(actual, null, 2)}\n`, "utf8");
  }

  const expected = JSON.parse(fs.readFileSync(snapshotPath, "utf8"));
  assert.deepEqual(actual, expected);
});

test("route 6 normalizes legacy 'just' emotion alias", () => {
  const route = __test.resolveChipIntentRoute("New passions for just");
  assert.equal(route?.id, 6);
  assert.equal(route?.target, "hate");
});

test("route 6 still returns suggestion cards when model confidence is low", () => {
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

  assert.equal(output.suggestionCards.length, 1);
  assert.equal(output.suggestionCards[0].options.length, 3);
  assert.ok(output.suggestionCards[0].options.every((item) => item.type === "addPassionItem"));
  assert.equal(output.suggestionCards[0].options[0]?.payload?.passionType, "love");
});
