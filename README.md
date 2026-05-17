# AURA Social Reads

AURA Social Reads is an iOS social entertainment app for quick, shareable aura reads.

The repo contains:

- `SEEN/`: SwiftUI iOS app
- `site/`: Netlify static marketing site
- `netlify/functions/`: Netlify AI analysis endpoint
- `netlify/lib/`: Shared Netlify Function logic
- `netlify/tests/`: Netlify Function unit tests
- `functions/`: Firebase Functions prototype, kept for later Firebase migration

## iOS

Open `SEEN.xcworkspace` in Xcode and run the `SEEN` scheme.

The app reads its public API endpoint from:

```txt
SEEN/Aura.env
```

Do not put `AURA_RESULT_ENGINE_TOKEN` in `SEEN/Aura.env`.

## Netlify Site

Netlify uses:

```txt
Publish directory: site
Functions directory: netlify/functions
```

The short API route is:

```txt
/api/analyzeAura
```

Set these Netlify environment variables:

```txt
AURA_RESULT_ENGINE_TOKEN=your_openai_api_key
AURA_OPENAI_MODEL=gpt-5.4-mini
AURA_ALLOWED_ORIGINS=https://YOUR_SITE.netlify.app
```

Then set the iOS endpoint:

```txt
AURA_ANALYSIS_ENDPOINT=https://YOUR_SITE.netlify.app/api/analyzeAura
AURA_REQUEST_TIMEOUT=5
```

## Checks

```sh
npm test
npm run check
xcodebuild -workspace SEEN.xcworkspace -scheme SEEN -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' test -only-testing:SEENTests
```
