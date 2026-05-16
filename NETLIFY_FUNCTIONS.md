# Netlify Functions Setup

AURA can use Netlify Functions for the AI analysis endpoint without Firebase
Blaze. OpenAI usage may still cost money on the OpenAI side.

## Netlify Environment Variables

Set these in Netlify:

```txt
AURA_RESULT_ENGINE_TOKEN=your_openai_api_key
AURA_OPENAI_MODEL=gpt-5.4-mini
AURA_ALLOWED_ORIGINS=https://YOUR_SITE.netlify.app
```

For local development, keep `AURA_RESULT_ENGINE_TOKEN` in the root `.env`. Do
not put it inside `SEEN/Aura.env`.

## Endpoint

Netlify exposes the function at:

```txt
https://YOUR_SITE.netlify.app/.netlify/functions/analyzeAura
```

This repo also maps a shorter endpoint:

```txt
https://YOUR_SITE.netlify.app/api/analyzeAura
```

Use the shorter URL for `AURA_ANALYSIS_ENDPOINT`.

## Test Request

```sh
curl -X POST https://YOUR_SITE.netlify.app/api/analyzeAura \
  -H "Content-Type: application/json" \
  -d '{"answers":{"overthink_texts":"Yes","act_unbothered":"Sometimes","emotionally_available":"No","reply_fast":"Yes","main_character":"Sometimes","hard_to_read":"Yes","spiral_silently":"Sometimes"}}'
```
