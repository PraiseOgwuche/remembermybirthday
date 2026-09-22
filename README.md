# Remember My Birthday

Birthday reminders for iPhone (Mac + Watch targets included).

**App Store name:** Remember My Birthday  
**Bundle ID:** `com.remembermybirthday.app`

## Run

```bash
xcodegen generate
open Remember.xcodeproj
```

Scheme **Remember** → Signing → your Team → `⌘R`.

## Landing

Static site in [`landing/`](landing/index.html) (privacy + terms included). Live at https://remembermybirthday.me.

## App Store

See **[APP_STORE.md](APP_STORE.md)** for the submission checklist.

## Apple setup

1. App ID `com.remembermybirthday.app`
2. Sign in with Apple
3. App Groups → `group.com.remembermybirthday.app` (app + widget)
4. iCloud → CloudKit container `iCloud.com.remembermybirthday.app` (optional)
5. Paste production backend HTTPS URL into `CompanionConfig.productionBackendURL` before archive
