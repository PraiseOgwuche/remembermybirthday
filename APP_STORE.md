# App Store checklist — Remember My Birthday

Ship **iPhone only** first (scheme **Remember** + widget). Skip Mac/Watch for v1.

## Before submit

1. Paid Apple Developer membership
2. Xcode → Remember → Signing & Capabilities → your **Team**
3. developer.apple.com Identifiers:
   - App ID `com.remembermybirthday.app` (Sign in with Apple, App Groups, Push if used, iCloud/CloudKit if kept)
   - App Group `group.com.remembermybirthday.app`
   - Widget ID `com.remembermybirthday.app.widget`
4. Deploy backend over HTTPS; set URL in `Shared/Services/CompanionConfig.swift` → `productionBackendURL`
5. Live site links:
   - Privacy: https://remembermybirthday.me/privacy.html
   - Terms: https://remembermybirthday.me/terms.html
   - Support: https://remembermybirthday.me/
6. App Store Connect → new app:
   - Name: **Remember My Birthday**
   - Bundle ID: `com.remembermybirthday.app`
   - Privacy Policy URL, Support URL
   - Category: Lifestyle / Productivity
   - Age rating + App Privacy labels (Contacts, Email, Name — app functionality, not tracking)
7. Screenshots (6.7" + 6.1" min) + description + keywords
8. Archive → Upload → Submit

## Backend (Render)

1. Web Service, root `backend`
2. Env: `ANTHROPIC_API_KEY`, `SENDGRID_API_KEY`, `EMAIL_FROM`
3. Set in app:

```swift
// Shared/Services/CompanionConfig.swift
static let productionBackendURL = "https://YOUR-SERVICE.onrender.com"
```

4. Rebuild. LAN `http://10.x.x.x` will not work for App Store users.

## In code

- `PrivacyInfo.xcprivacy`
- `ITSAppUsesNonExemptEncryption = false`
- Release: enhance via HTTPS backend only (no provider key field)
- Delete account & data on device
- `landing/privacy.html` + `landing/terms.html`

## Review notes

> Remember My Birthday imports birthdays from Contacts/Calendar with permission, schedules local notifications, and drafts Messages you send yourself (we cannot silently send iMessage). Optional companion tips run only when the user taps Enhance. Sign in with Apple is optional; Continue without account works offline. Demo: use Continue without account.

## After upload

TestFlight internal → fix issues → submit 1.0.
