# AURA

AURA is an iOS social entertainment app for quick, shareable aura reads.

The repo contains:

- `SEEN/`: SwiftUI iOS app
- `site/`: Netlify static marketing site
- `netlify/functions/`: Netlify AI analysis endpoint
- `functions/`: Firebase Functions prototype, kept for later Firebase migration

## iOS

Open `SEEN.xcworkspace` in Xcode and run the `SEEN` scheme.

The app reads its public API endpoint from:

```txt
SEEN/Aura.env
```

Do not put `OPENAI_API_KEY` in `SEEN/Aura.env`.

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
OPENAI_API_KEY=your_openai_api_key
AURA_OPENAI_MODEL=gpt-4.1-mini
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
