import test from "node:test";
import assert from "node:assert/strict";
import { __test } from "../worker.js";

const visions = [
  "I build a calm, focused life where my work and health both move forward each week.",
  "I create stable routines that protect deep work, strong relationships, and clear recovery time.",
  "I grow my career and finances with steady consistency while still staying present at home.",
  "I become the kind of person who starts quickly, follows through, and keeps promises to myself.",
  "I design each week around my highest priorities so urgent noise does not run my life.",
  "I maintain high energy and simple systems that help me finish important work without burning out.",
  "I make meaningful progress on long-term goals while keeping balance across my core life areas.",
  "I operate with clear direction, strong boundaries, and daily action on what matters most."
];

const passions = [
  "Fitness training",
  "Public speaking",
  "Building useful products",
  "Family time",
  "Deep learning",
  "Financial independence",
  "Writing ideas clearly",
  "Coaching others",
  "Travel and exploration",
  "Creative problem solving",
  "Leading teams",
  "Teaching",
  "Designing systems",
  "Music",
  "Community building",
  "Entrepreneurship"
];

const representativeAreaScenarios = [
  ["Career & Business", "Wealth & Finance", "Home & Life"],
  ["Love & Relationships", "Home & Life", "Health & Energy"],
  ["Learning & Education", "Mindset & Resilience", "Faith & Spirituality"],
  ["Service & Impact", "Career & Business", "Home & Life"],
  ["Lifestyle & Experiences", "Learning & Education", "Career & Business"],
  ["Health & Energy", "Mindset & Resilience", "Home & Life"],
  ["Faith & Spirituality", "Mindset & Resilience", "Love & Relationships"],
  ["Wealth & Finance", "Career & Business", "Learning & Education"],
  ["Service & Impact", "Love & Relationships", "Home & Life"],
  ["Lifestyle & Experiences", "Health & Energy", "Mindset & Resilience"]
];

const questionnaire = {
  stress: [
    "Too many priorities competing",
    "Feeling behind or disorganized",
    "Distractions are stealing my focus",
    "Work pressure",
    "Money pressure",
    "Low energy / health",
    "Relationship tension",
    "Not sure yet"
  ],
  breaksFirst: [
    "I don't start",
    "I start, then lose momentum",
    "I get distracted",
    "I overthink it",
    "I don't finish what I start",
    "I'm not sure"
  ],
  planningStyle: [
    "React to what's urgent",
    "Keep a simple to-do list",
    "Plan, but get off track",
    "Plan and follow through consistently",
    "It depends on the day"
  ],
  firstChange: [
    "I feel in control (less stress)",
    "I know what matters (clear direction)",
    "I follow through (consistency)",
    "I make faster progress on big goals",
    "I feel balanced across life"
  ]
};

function buildCalibrationSummary() {
  const winnerCounts = new Map();
  const topBandCounts = new Map();
  const passionScenarios = [[], ...passions.map((item) => [item])];
  let total = 0;
  let comboIndex = 0;

  for (const stress of questionnaire.stress) {
    for (const breaksFirst of questionnaire.breaksFirst) {
      for (const planningStyle of questionnaire.planningStyle) {
        for (const firstChange of questionnaire.firstChange) {
          for (const vision of visions) {
            for (const chosenPassions of passionScenarios) {
              const areas = representativeAreaScenarios[comboIndex % representativeAreaScenarios.length];
              comboIndex += 1;
              const diagnostic = { stress, breaksFirst, planningStyle, firstChange, areas };
              const ranked = __test.rankPurposeProfilesHeuristically({
                diagnostic,
                vision,
                passions: chosenPassions
              });
              const seed = __test.buildPurposeProfileHeuristicSeed({
                diagnostic,
                vision,
                passions: chosenPassions
              });
              const picked = __test.pickPurposeProfileFromTopBand(ranked, seed);
              total += 1;
              winnerCounts.set(picked.profile, (winnerCounts.get(picked.profile) || 0) + 1);
              for (const item of __test.purposeProfileTopBand(ranked)) {
                topBandCounts.set(item.profile, (topBandCounts.get(item.profile) || 0) + 1);
              }
            }
          }
        }
      }
    }
  }

  const profiles = __test.purposeProfileCatalog.map((item) => item.profile);
  const winnerShares = Object.fromEntries(
    profiles.map((profile) => [profile, (winnerCounts.get(profile) || 0) / total])
  );
  const topBandShares = Object.fromEntries(
    profiles.map((profile) => [profile, (topBandCounts.get(profile) || 0) / total])
  );

  return {
    total,
    profiles,
    winnerShares,
    topBandShares,
    missingWinners: profiles.filter((profile) => !winnerCounts.has(profile)),
    missingTopBand: profiles.filter((profile) => !topBandCounts.has(profile))
  };
}

function bestProfile({ diagnostic, vision, passions }) {
  const ranked = __test.rankPurposeProfilesHeuristically({ diagnostic, vision, passions });
  const seed = __test.buildPurposeProfileHeuristicSeed({ diagnostic, vision, passions });
  return __test.pickPurposeProfileFromTopBand(ranked, seed)?.profile || "";
}

test("purpose profile rubric calibration keeps all profiles reachable and bounded", () => {
  const summary = buildCalibrationSummary();
  const winnerShares = Object.values(summary.winnerShares);
  const topBandShares = Object.values(summary.topBandShares);

  assert.equal(summary.total, 163200);
  assert.deepEqual(summary.missingWinners, []);
  assert.deepEqual(summary.missingTopBand, []);
  assert.ok(Math.max(...winnerShares) <= 0.15, "winner concentration is too high");
  assert.ok(Math.min(...winnerShares) >= 0.005, "at least one profile is still starved");
  assert.ok(Math.max(...topBandShares) <= 0.26, "top-band concentration is too high");
});

test("purpose profile rubric exposes direct specialist routes and area sensitivity", () => {
  assert.equal(bestProfile({
    diagnostic: {
      stress: "Work pressure",
      breaksFirst: "I don't finish what I start",
      planningStyle: "React to what's urgent",
      firstChange: "I feel in control (less stress)",
      areas: ["Career & Business", "Home & Life", "Wealth & Finance"]
    },
    vision: "I operate with clear direction, strong boundaries, and daily action on what matters most.",
    passions: ["Leading teams"]
  }), "Operational Commander");

  assert.equal(bestProfile({
    diagnostic: {
      stress: "Work pressure",
      breaksFirst: "I don't finish what I start",
      planningStyle: "React to what's urgent",
      firstChange: "I make faster progress on big goals",
      areas: ["Service & Impact", "Career & Business", "Home & Life"]
    },
    vision: "I operate with clear direction, strong boundaries, and daily action on what matters most.",
    passions: ["Community building"]
  }), "Crisis Navigator");

  assert.equal(bestProfile({
    diagnostic: {
      stress: "Not sure yet",
      breaksFirst: "I overthink it",
      planningStyle: "Keep a simple to-do list",
      firstChange: "I know what matters (clear direction)",
      areas: ["Learning & Education", "Wealth & Finance", "Career & Business"]
    },
    vision: "I design each week around my highest priorities so urgent noise does not run my life.",
    passions: ["Designing systems"]
  }), "Analytical Architect");

  assert.equal(bestProfile({
    diagnostic: {
      stress: "Not sure yet",
      breaksFirst: "I overthink it",
      planningStyle: "It depends on the day",
      firstChange: "I feel balanced across life",
      areas: ["Faith & Spirituality", "Mindset & Resilience", "Learning & Education"]
    },
    vision: "I make meaningful progress on long-term goals while keeping balance across my core life areas.",
    passions: ["Music"]
  }), "Reflective Synthesizer");

  assert.equal(bestProfile({
    diagnostic: {
      stress: "Not sure yet",
      breaksFirst: "I don't start",
      planningStyle: "It depends on the day",
      firstChange: "I make faster progress on big goals",
      areas: ["Learning & Education", "Lifestyle & Experiences", "Career & Business"]
    },
    vision: "I become the kind of person who starts quickly, follows through, and keeps promises to myself.",
    passions: ["Travel and exploration"]
  }), "Independent Pathfinder");

  const baseDiagnostic = {
    stress: "Not sure yet",
    breaksFirst: "I overthink it",
    planningStyle: "Keep a simple to-do list",
    firstChange: "I know what matters (clear direction)"
  };
  const vision = "I design each week around my highest priorities so urgent noise does not run my life.";
  const passions = ["Designing systems"];
  const analytical = bestProfile({
    diagnostic: {
      ...baseDiagnostic,
      areas: ["Learning & Education", "Wealth & Finance", "Career & Business"]
    },
    vision,
    passions
  });
  const reflective = bestProfile({
    diagnostic: {
      ...baseDiagnostic,
      areas: ["Faith & Spirituality", "Mindset & Resilience", "Love & Relationships"]
    },
    vision,
    passions
  });

  assert.equal(analytical, "Analytical Architect");
  assert.notEqual(reflective, analytical);
});
