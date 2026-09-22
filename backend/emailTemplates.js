const SITE = "https://remembermybirthday.me";
const SUPPORT = "hello@remembermybirthday.me";

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function layout({ preheader, title, bodyHtml }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;padding:0;background:#eef6fb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#0c1b2a;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#eef6fb;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 28px rgba(12,27,42,0.08);">
          <tr>
            <td style="background:linear-gradient(180deg,#6eb6e8 0%,#2f7fbf 100%);padding:28px 28px 24px;text-align:center;">
              <div style="font-size:28px;line-height:1;">🎁</div>
              <div style="margin-top:10px;font-size:18px;font-weight:700;letter-spacing:-0.02em;color:#ffffff;">Remember My Birthday</div>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 28px 8px;font-size:16px;line-height:1.55;color:#0c1b2a;">
              ${bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 28px;">
              <a href="${SITE}" style="display:inline-block;background:#1f6fad;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;padding:12px 18px;border-radius:10px;">Open Remember My Birthday</a>
            </td>
          </tr>
          <tr>
            <td style="padding:0 28px 28px;font-size:12px;line-height:1.5;color:#4a6070;border-top:1px solid #e6eef4;">
              <p style="margin:16px 0 0;">You’re receiving this because you use Remember My Birthday and email notifications are on. Manage or turn off emails in the app under Settings → Email notifications.</p>
              <p style="margin:10px 0 0;">
                <a href="${SITE}/privacy.html" style="color:#1f6fad;">Privacy</a> ·
                <a href="${SITE}/terms.html" style="color:#1f6fad;">Terms</a> ·
                <a href="mailto:${SUPPORT}" style="color:#1f6fad;">${SUPPORT}</a>
              </p>
              <p style="margin:10px 0 0;">Remember My Birthday · Online service · ${SUPPORT}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export function welcomeEmail(name) {
  const safeName = escapeHtml(name || "there");
  const subject = "Welcome to Remember My Birthday";
  const text = [
    `Hi ${name || "there"},`,
    "",
    "You’re in. Add people once, get reminders when it matters, and draft birthday messages in one tap.",
    "",
    `Open the app: ${SITE}`,
    "",
    "Manage email preferences anytime in Settings → Email notifications.",
    `Privacy: ${SITE}/privacy.html`,
    `Terms: ${SITE}/terms.html`,
    "",
    "— Remember My Birthday",
    SUPPORT,
  ].join("\n");

  const html = layout({
    preheader: "You’re in — reminders and drafts when it matters.",
    title: subject,
    bodyHtml: `
      <p style="margin:0 0 14px;font-size:22px;font-weight:700;letter-spacing:-0.02em;">Welcome, ${safeName}</p>
      <p style="margin:0 0 12px;">You’re in. Add the people who matter once, get timely reminders, and open Messages with a draft ready.</p>
      <p style="margin:0;">Private by default — birthdays stay on your iPhone unless you turn on iCloud sync.</p>
    `,
  });

  return { subject, text, html };
}

export function signInEmail(name) {
  const safeName = escapeHtml(name || "there");
  const subject = "You’re signed in to Remember My Birthday";
  const text = [
    `Hi ${name || "there"},`,
    "",
    "Just confirming you’re signed in on a device. If this wasn’t you, sign out in the app Settings.",
    "",
    `Manage email preferences in Settings → Email notifications.`,
    `Privacy: ${SITE}/privacy.html`,
    "",
    "— Remember My Birthday",
    SUPPORT,
  ].join("\n");

  const html = layout({
    preheader: "Sign-in confirmation for your Remember My Birthday account.",
    title: subject,
    bodyHtml: `
      <p style="margin:0 0 14px;font-size:22px;font-weight:700;letter-spacing:-0.02em;">Hi ${safeName}</p>
      <p style="margin:0 0 12px;">Just confirming you’re signed in on a device.</p>
      <p style="margin:0;">If this wasn’t you, open the app and sign out under Settings → Account.</p>
    `,
  });

  return { subject, text, html };
}

export function reminderEmail({ personName, daysUntil, note }) {
  const name = personName || "Someone";
  const safeName = escapeHtml(name);
  const when =
    daysUntil === 0
      ? "today"
      : daysUntil === 1
        ? "tomorrow"
        : `in ${daysUntil} days`;
  const subject = `${name}'s birthday is ${when}`;
  const textLines = [
    `Hey — ${name}'s birthday is ${when}.`,
    "",
    "Open Remember My Birthday to call, draft a message, or schedule a send.",
  ];
  if (note) textLines.push("", `Note: ${note}`);
  textLines.push(
    "",
    `App: ${SITE}`,
    "Manage email preferences in Settings → Email notifications.",
    "",
    "— Remember My Birthday",
    SUPPORT
  );

  const noteHtml = note
    ? `<p style="margin:14px 0 0;padding:12px 14px;background:#eef6fb;border-radius:10px;color:#4a6070;font-size:14px;"><strong>Note:</strong> ${escapeHtml(note)}</p>`
    : "";

  const html = layout({
    preheader: `${name}'s birthday is ${when}.`,
    title: subject,
    bodyHtml: `
      <p style="margin:0 0 14px;font-size:22px;font-weight:700;letter-spacing:-0.02em;">${safeName}'s birthday is ${escapeHtml(when)}</p>
      <p style="margin:0;">Open Remember My Birthday to call, draft a message, or schedule a send so you’re ready.</p>
      ${noteHtml}
    `,
  });

  return { subject, text: textLines.join("\n"), html };
}
