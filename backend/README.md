# Companion backend

Node server for:

1. `POST /v1/companion` — companion proxy (keys stay on the server)
2. Email via SendGrid — welcome, sign-in, birthday reminders

## Local

```bash
cd backend
cp .env.example .env
# set ANTHROPIC_API_KEY and SENDGRID_API_KEY
npm install
npm run dev
```

## SendGrid

1. Verify `remembermybirthday.me` in SendGrid.
2. Set `EMAIL_FROM=Remember My Birthday <hello@remembermybirthday.me>`.
3. API key with Mail Send permission.

## Deploy

Render (HTTPS). Env: `ANTHROPIC_API_KEY`, `SENDGRID_API_KEY`, `EMAIL_FROM`.

App: `Shared/Services/CompanionConfig.swift` → `productionBackendURL`
