# App Privacy Notes

Use this as a working note when filling App Store Connect privacy questions.
Confirm final answers against actual production behavior before submission.

## Data Collection

Current MVP design:

- Scan results are not saved to an account.
- The app can send prompt answers to the Netlify AI endpoint to generate a result.
- The marketing site waitlist collects email addresses through Netlify Forms.
- The iOS app itself should not collect email unless a future in-app waitlist/login is added.

## App Privacy Draft

Likely disclosures for the iOS app:

- User Content: prompt answers may be processed by the server to generate an entertainment result.
- Diagnostics: only if App Store Connect/Xcode/Future analytics SDK is enabled.
- Identifiers: only if Firebase Analytics/Auth/Push is added later.

Do not declare data types that are not collected by the iOS app.

## Tracking

Do not enable third-party tracking unless App Tracking Transparency is implemented and the privacy labels are updated.

## AI Disclaimer

Results are entertainment only and are not medical, psychological, school, hiring, or financial advice.

