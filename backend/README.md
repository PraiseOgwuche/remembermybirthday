# Remember companion backend

Tiny Node server for:

1. **Companion proxy** (`POST /v1/companion`) — keeps provider keys off the phone  
2. **Email** via Resend — welcome, sign-in, birthday reminders

## Setup (local)

```bash
cd backend
cp .env.example .env
# edit .env with ANTHROPIC_API_KEY and RESEND_API_KEY
npm install
npm run dev
```

## App Store / Render

Deploy this folder to Render (HTTPS). Then set that URL in the iOS app:

`Shared/Services/CompanionConfig.swift` → `productionBackendURL`

The app only calls `/v1/companion` when the user taps **Enhance tip**, and caches the result for 2 weeks.
