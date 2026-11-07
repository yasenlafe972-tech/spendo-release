---
trigger: always_on
description: Always provide direct download links for Android APK or iOS IPA builds in the exact GitHub release asset format
---

# Direct Build Download Links Rule

Whenever the user requests a build link (for iOS `.ipa` or Android `.apk`) or when providing release links:
1. Always provide only the direct file download URL in the exact format:
   - iOS IPA: `https://github.com/yasenlafe972-tech/spendo-release/releases/download/v1.0.<run_number>/Spendo.ipa`
   - Android APK (when applicable): direct `.apk` download link.
2. Do not clutter the response with unnecessary intermediate pages when the user asks for the build link—give the direct `.ipa` or `.apk` URL cleanly.
