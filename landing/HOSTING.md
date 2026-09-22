# Hosting the landing site (privacy + terms)

App Store Connect needs live URLs. Point **remembermybirthday.me** at the `landing/` folder.

## Option A — Cloudflare Pages (fits your DNS)

Cloudflare’s Git UI may say “Worker project” — that’s normal in the new dashboard.

1. **Workers & Pages** → **Create application** → connect GitHub → `remembermybirthday`
2. On **Set up your application**:
   - **Project name:** `remembermybirthday`
   - **Build command:** leave **empty**
   - **Deploy command:** `npx wrangler pages deploy landing`  
     (or keep `npx wrangler deploy` if `wrangler.toml` is on `main` with `pages_build_output_dir = "landing"`)
3. **Deploy**
4. Project → **Custom domains** → add `remembermybirthday.me` (and `www` if you want)
5. Confirm:
   - https://remembermybirthday.me/privacy.html
   - https://remembermybirthday.me/terms.html

## Option B — GitHub Pages

1. Repo Settings → Pages → Deploy from branch `main` / folder `/landing` (or use Actions)
2. Add custom domain `remembermybirthday.me` and the DNS records GitHub shows

Until the domain serves these pages, App Store privacy/support links will 404.
