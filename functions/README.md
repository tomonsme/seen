# AURA Firebase Cloud Functions Prototype

This directory contains the Firebase version of the AI analysis endpoint. The
current low-cost path uses Netlify Functions instead. Keep this only if Firebase
Functions is needed later.

## Setup

Install dependencies:

```sh
cd functions
npm install
```

Set the OpenAI API key as a Firebase Secret:

```sh
firebase functions:secrets:set AURA_RESULT_ENGINE_TOKEN
```

Optional local runtime config in `functions/.env`:

```sh
AURA_OPENAI_MODEL=gpt-5.4-mini
AURA_RESULT_ENGINE_TOKEN=your_openai_api_key
AURA_ALLOWED_ORIGINS=https://your-netlify-site.netlify.app
```

Put those values in `functions/.env` for local emulator runs. During deploy,
Firebase will prompt for missing parameterized config values if they are not
already set for the project.

If this project does not have a Firebase project file yet, copy the example:

```sh
cp .firebaserc.example .firebaserc
```

This repo is currently configured for Firebase project `seen-a3c5b`.

Deploy:

```sh
firebase deploy --only functions:aura-api
```

The endpoint will be:

```txt
https://us-central1-seen-a3c5b.cloudfunctions.net/analyzeAura
```

If Firebase is used later, put that URL into the iOS app config:

```env
AURA_ANALYSIS_ENDPOINT=https://us-central1-seen-a3c5b.cloudfunctions.net/analyzeAura
AURA_REQUEST_TIMEOUT=5
```

## Request

```json
{
  "answers": {
    "overthink_texts": "Yes",
    "act_unbothered": "Sometimes",
    "emotionally_available": "No",
    "reply_fast": "Yes",
    "main_character": "Sometimes",
    "hard_to_read": "Yes",
    "spiral_silently": "Sometimes"
  }
}
```

## Response

The response matches `RemoteAuraPayload` in the iOS app.
