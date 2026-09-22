# Hosting the landing site (privacy + terms)

App Store Connect needs live URLs. Point **remembermybirthday.me** at the `landing/` folder.

## Option A — Cloudflare Pages (fits your DNS)

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages**
2. Connect the GitHub repo `PraiseOgwuche/remembermybirthday`
3. Build settings:
   - Framework preset: **None**
   - Build command: leave empty
   - Build output directory: `landing`
4. After deploy, **Custom domains** → add `remembermybirthday.me` and `www.remembermybirthday.me`
5. Confirm:
   - https://remembermybirthday.me/privacy.html
   - https://remembermybirthday.me/terms.html

## Option B — GitHub Pages

1. Repo Settings → Pages → Deploy from branch `main` / folder `/landing` (or use Actions)
2. Add custom domain `remembermybirthday.me` and the DNS records GitHub shows

Until the domain serves these pages, App Store privacy/support links will 404.
