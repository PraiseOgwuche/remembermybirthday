# App Store submission checklist — Remember My Birthday

Ship **iPhone only** first (scheme **Remember** + widget). Skip Mac/Watch for v1.

## A. You must do in Apple / hosting (blocks submission)

1. **Paid Apple Developer** membership active  
2. Xcode → Remember target → **Signing & Capabilities** → select your **Team**  
3. developer.apple.com → Identifiers:
   - App ID `com.remembermybirthday.app` with Sign in with Apple, App Groups, Push (if used), iCloud/CloudKit if you keep sync
   - App Group `group.com.remembermybirthday.app`
   - Widget ID `com.remembermybirthday.app.widget`
4. **Deploy backend** (HTTPS) — see below — then set URL in `Shared/Services/CompanionConfig.swift` → `productionBackendURL`
5. Host **landing + privacy**:
   - Enable GitHub Pages for this repo (`/landing` or `/docs`)
   - Confirm URLs match `CompanionConfig.privacyPolicyURL` / `supportURL`
6. App Store Connect → new app:
   - Name: **Remember My Birthday**
   - Bundle ID: `com.remembermybirthday.app`
   - Privacy Policy URL (required)
   - Support URL
   - Category: Lifestyle / Productivity
   - Age rating questionnaire
   - **App Privacy** nutrition labels (Contacts, Email, Name — for app functionality, not tracking)
7. Screenshots (6.7" + 6.1" minimum) + description + keywords  
8. Archive → Upload → Submit for review  

## B. Deploy companion backend (Render)

```bash
# From repo root, or connect the GitHub repo in Render and use backend/render.yaml
```

1. Create a Web Service from this repo, root `backend`  
2. Set env vars: `ANTHROPIC_API_KEY`, `SENDGRID_API_KEY`, `EMAIL_FROM`  
3. Copy the `https://….onrender.com` URL into:

```swift
// Shared/Services/CompanionConfig.swift
static let productionBackendURL = "https://YOUR-SERVICE.onrender.com"
```

4. Rebuild the app  

Local LAN `http://10.x.x.x` will **not** work for App Store users.

## C. Already done in code for this pass

- Privacy manifest (`PrivacyInfo.xcprivacy`)
- Export compliance flag `ITSAppUsesNonExemptEncryption = false`
- Release builds: no provider API key field; enhance goes through HTTPS backend only
- Delete account & data on device (App Review account-deletion)
- Send test email button
- `landing/privacy.html`

## D. Review notes to paste in App Store Connect

> Remember My Birthday imports birthdays from Contacts/Calendar with permission, schedules local notifications, and drafts Messages you send yourself (we cannot silently send iMessage). Optional companion tips run only when the user taps Enhance. Sign in with Apple is optional; Continue without account works offline. Demo account: use Continue without account.

## E. After upload

- TestFlight internal → you + 1 friend  
- Fix crash/rejection  
- Submit 1.0 for App Review  
