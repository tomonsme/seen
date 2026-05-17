# AURA Social Reads App Store Connect Pack

This folder contains App Store Connect draft metadata, review notes, privacy
notes, and generated image assets.

## Current App Settings

- App Store name: AURA Social Reads
- Home screen name: AURA Social
- Bundle ID: `com.tomoya.aura`
- Version: `1.0`
- Build: `1`
- Platform: iOS
- Device family: iPhone
- Minimum iOS: 17.0

## Before Submission

1. Put the deployed Netlify endpoint into `SEEN/Aura.env`.
2. Confirm `/api/analyzeAura` returns a valid JSON result.
3. Archive in Xcode and upload to App Store Connect.
4. Use the metadata drafts in `appstore/metadata/`.
5. Upload screenshots from `appstore/generated/iphone-6-9/`.
6. Use marketing images from `appstore/generated/ads/` for external promotion.

## Required External URLs

Replace these before final App Store submission:

- Privacy Policy URL: `https://YOUR_SITE.netlify.app/privacy.html`
- Terms URL: `https://YOUR_SITE.netlify.app/terms.html`
- Support URL: `https://YOUR_SITE.netlify.app/`
- Marketing URL: `https://YOUR_SITE.netlify.app/`
