# Remember My Birthday

Native birthday reminders for iPhone (Mac + Watch targets included).

**App Store name:** Remember My Birthday  
**Home screen:** RMB  
**Bundle ID:** `com.remembermybirthday.app`

## Run

```bash
xcodegen generate
open Remember.xcodeproj
```

Scheme **Remember** → select your Team under Signing → `⌘R`.

## Landing page

Static site in [`landing/`](landing/index.html). Host with GitHub Pages or any static host.

## Capabilities to enable (Apple Developer)

1. App ID `com.remembermybirthday.app`
2. Sign in with Apple
3. App Groups → `group.com.remembermybirthday.app` (app + widget)
4. iCloud → CloudKit container `iCloud.com.remembermybirthday.app` (optional sync)
5. App Store Connect record named **Remember My Birthday**
