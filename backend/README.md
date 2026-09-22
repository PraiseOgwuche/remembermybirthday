# Remember companion backend

Tiny Node server for:

1. **Companion proxy** (`POST /v1/companion`) — keeps provider keys off the phone  
2. **Email** via SendGrid — welcome, sign-in, birthday reminders

## Setup (local)

```bash
cd backend
cp .env.example .env
# edit .env with ANTHROPIC_API_KEY and SENDGRID_API_KEY
npm install
npm run dev
```

## SendGrid domain

1. Verify `remembermybirthday.me` in SendGrid (DNS CNAMEs + DMARC).
2. Set `EMAIL_FROM=Remember My Birthday <hello@remembermybirthday.me>`.
3. Create an API key with **Mail Send** permission.

## App Store / Render

Deploy this folder to Render (HTTPS). Env vars: `ANTHROPIC_API_KEY`, `SENDGRID_API_KEY`, `EMAIL_FROM`.

App URL: `Shared/Services/CompanionConfig.swift` → `productionBackendURL`
