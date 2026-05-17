# App Review Notes

## Suggested Notes

AURA Social Reads is a social entertainment app that generates playful personality-style reads.

The app does not require account creation for the core scan flow. Scan results are not saved to an account. The AI endpoint is called through a server-side Netlify Function; API keys are not embedded in the iOS app.

Core flows to test:

1. Open AURA Social.
2. Tap `Reveal`.
3. Complete the Aura Scan.
4. View the result screen.
5. Tap `Share Card` to open the iOS share sheet.
6. Return home and try `Friends` for local group voting.
7. Try `Daily` for the daily drop.

If the network endpoint is unavailable, the app falls back to a local entertainment result instead of crashing.

## Login

No login is required for the MVP core experience.

## Demo Account

Not applicable.

## Contact

Replace before submission:

- Name: Tomoya Miyake
- Email: YOUR_SUPPORT_EMAIL
