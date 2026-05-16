"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {_private} = require("./index");

test("normalizeAnswers fills missing answers and rejects unknown values", () => {
  const answers = _private.normalizeAnswers({
    overthink_texts: "Yes",
    act_unbothered: "No",
    emotionally_available: "Maybe",
  });

  assert.equal(answers.overthink_texts, "Yes");
  assert.equal(answers.act_unbothered, "No");
  assert.equal(answers.emotionally_available, "Sometimes");
  assert.equal(answers.reply_fast, "Sometimes");
  assert.equal(Object.keys(answers).length, 7);
});

test("sanitizeAnalysis clamps and normalizes API output", () => {
  const result = _private.sanitizeAnalysis({
    auraScore: 120,
    socialType: "Read Receipt Royalty",
    badgeTitle: "Instant Ghost",
    rarity: "Top 8% notification menace",
    visual: "pulse",
    roast: "You act unavailable but reply instantly.",
    hiddenPattern: "You hide effort by making care look accidental.",
    receipt: "Typed, deleted, replied in 12 seconds.",
    matchup: "Best with someone direct enough to skip the guessing game.",
    shareLine: "Fast replies. Slow feelings.",
    friendHook: "Ask friends if the chill act is convincing.",
    challenge: "Send this to the person who knows your phone is never dead.",
    metrics: [
      {name: "Overthink", value: 104},
      {name: "Unbothered Act", value: -3},
      {name: "Main Character", value: 72},
      {name: "Readability", value: 41},
    ],
  });

  assert.equal(result.auraScore, 98);
  assert.deepEqual(result.metrics, [
    {name: "Overthink", value: 100},
    {name: "Unbothered Act", value: 0},
    {name: "Main Character", value: 72},
    {name: "Readability", value: 41},
  ]);
});
