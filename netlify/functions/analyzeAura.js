"use strict";

const {analyzeAura, safeError} = require("./auraCore");

exports.handler = async (event) => {
  const headers = corsHeaders(event.headers && event.headers.origin);

  if (event.httpMethod === "OPTIONS") {
    return {
      statusCode: 204,
      headers,
      body: "",
    };
  }

  if (event.httpMethod !== "POST") {
    return json(405, {error: "method_not_allowed"}, headers);
  }

  try {
    const body = event.body ? JSON.parse(event.body) : {};
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      return json(500, {error: "missing_openai_api_key"}, headers);
    }

    const result = await analyzeAura({
      answers: body.answers,
      apiKey,
      model: process.env.AURA_OPENAI_MODEL || "gpt-4.1-mini",
    });

    return json(200, result, headers);
  } catch (error) {
    console.error("analyzeAura failed", safeError(error));
    return json(500, {error: "analysis_failed"}, headers);
  }
};

function json(statusCode, payload, headers) {
  return {
    statusCode,
    headers: {
      ...headers,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(payload),
  };
}

function corsHeaders(origin) {
  const allowedOrigins = parseAllowedOrigins();
  const headers = {
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (origin && (allowedOrigins.has("*") || allowedOrigins.has(origin))) {
    headers["Access-Control-Allow-Origin"] = origin;
  }

  return headers;
}

function parseAllowedOrigins() {
  return new Set(
    String(process.env.AURA_ALLOWED_ORIGINS || "")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
  );
}
