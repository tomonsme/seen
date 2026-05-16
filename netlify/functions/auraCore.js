"use strict";

const OpenAI = require("openai");
const {zodTextFormat} = require("openai/helpers/zod");
const {z} = require("zod");

const answerValues = new Set(["No", "Sometimes", "Yes"]);
const questionContext = [
  {
    id: "overthink_texts",
    prompt: "Do you overthink texts?",
    detail: "Especially after a dry reply.",
  },
  {
    id: "act_unbothered",
    prompt: "Do you act unbothered?",
    detail: "Even when you are very bothered.",
  },
  {
    id: "emotionally_available",
    prompt: "Are you emotionally available?",
    detail: "Be honest. Your friends already know.",
  },
  {
    id: "reply_fast",
    prompt: "Do you reply instantly?",
    detail: "While pretending you just saw it.",
  },
  {
    id: "main_character",
    prompt: "Do you have main character energy?",
    detail: "Accidental or fully intentional.",
  },
  {
    id: "hard_to_read",
    prompt: "Are you hard to read?",
    detail: "Mystery or poor communication.",
  },
  {
    id: "spiral_silently",
    prompt: "Do you spiral silently?",
    detail: "The group chat gets the live commentary.",
  },
];

const AuraAnalysisSchema = z.object({
  auraScore: z.number().int().min(41).max(98),
  socialType: z.string().min(3).max(36),
  badgeTitle: z.string().min(3).max(34),
  rarity: z.string().min(3).max(44),
  visual: z.enum(["pulse", "prism", "spark", "eclipse", "signal"]),
  roast: z.string().min(10).max(96),
  hiddenPattern: z.string().min(10).max(140),
  receipt: z.string().min(8).max(120),
  matchup: z.string().min(8).max(140),
  shareLine: z.string().min(6).max(82),
  friendHook: z.string().min(8).max(116),
  challenge: z.string().min(8).max(116),
  metrics: z.array(
    z.object({
      name: z.enum([
        "Overthink",
        "Unbothered Act",
        "Main Character",
        "Readability",
      ]),
      value: z.number().int().min(0).max(100),
    }),
  ).length(4),
});

const systemPrompt = [
  "You write AURA results for a US Gen Z social entertainment app.",
  "The result must feel simple, cute, visual, and screenshot-worthy.",
  "Tone: playful, sharp, warm, short. Roast the behavior, not the person.",
  "Do not diagnose mental health, sexuality, trauma, attachment style, or protected traits.",
  "Do not mention AI, prompts, scoring logic, JSON, or that this is generated.",
  "Avoid cruelty, bullying, slurs, profanity, and explicit sexual content.",
  "Write in American English.",
  "Prefer lines that friends would send to a group chat.",
  "Keep every field concise enough for a mobile result card.",
].join(" ");

async function analyzeAura({answers, apiKey, model}) {
  const normalizedAnswers = normalizeAnswers(answers);
  const openai = new OpenAI({apiKey});
  const response = await openai.responses.parse({
    model,
    input: [
      {
        role: "system",
        content: systemPrompt,
      },
      {
        role: "user",
        content: JSON.stringify({
          answers: normalizedAnswers,
          questions: questionContext,
          outputRules: {
            auraScore: "41-98. Higher means more socially intense.",
            visual:
              "pulse for texting energy, prism for spotlight, spark for soft chaos, eclipse for mystery, signal for analysis.",
            metrics:
              "Return exactly Overthink, Unbothered Act, Main Character, Readability.",
            shareLine:
              "Must be the most shareable one-liner. No hashtags.",
          },
        }),
      },
    ],
    text: {
      format: zodTextFormat(AuraAnalysisSchema, "aura_analysis"),
    },
    store: false,
    max_output_tokens: 900,
  });

  if (!response.output_parsed) {
    throw new Error("empty_ai_result");
  }

  return sanitizeAnalysis(response.output_parsed);
}

function normalizeAnswers(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("answers must be an object");
  }

  return Object.fromEntries(
    questionContext.map((question) => {
      const value = input[question.id];
      return [
        question.id,
        answerValues.has(value) ? value : "Sometimes",
      ];
    }),
  );
}

function sanitizeAnalysis(analysis) {
  const metricsByName = new Map(
    analysis.metrics.map((metric) => [
      metric.name,
      {
        name: metric.name,
        value: clampInt(metric.value, 0, 100),
      },
    ]),
  );

  return {
    auraScore: clampInt(analysis.auraScore, 41, 98),
    socialType: limitText(analysis.socialType, 36),
    badgeTitle: limitText(analysis.badgeTitle, 34),
    rarity: limitText(analysis.rarity, 44),
    visual: analysis.visual,
    roast: limitText(analysis.roast, 96),
    hiddenPattern: limitText(analysis.hiddenPattern, 140),
    receipt: limitText(analysis.receipt, 120),
    matchup: limitText(analysis.matchup, 140),
    shareLine: limitText(analysis.shareLine, 82),
    friendHook: limitText(analysis.friendHook, 116),
    challenge: limitText(analysis.challenge, 116),
    metrics: [
      metricOrDefault(metricsByName, "Overthink", 50),
      metricOrDefault(metricsByName, "Unbothered Act", 50),
      metricOrDefault(metricsByName, "Main Character", 50),
      metricOrDefault(metricsByName, "Readability", 50),
    ],
  };
}

function metricOrDefault(metricsByName, name, value) {
  return metricsByName.get(name) || {name, value};
}

function clampInt(value, min, max) {
  const numeric = Number.isFinite(value) ? Math.round(value) : min;
  return Math.min(max, Math.max(min, numeric));
}

function limitText(value, maxLength) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  return text.length <= maxLength ? text : text.slice(0, maxLength - 1).trim() + ".";
}

function safeError(error) {
  return {
    name: error && error.name,
    message: error && error.message,
    status: error && error.status,
    code: error && error.code,
  };
}

module.exports = {
  AuraAnalysisSchema,
  analyzeAura,
  normalizeAnswers,
  sanitizeAnalysis,
  safeError,
};
