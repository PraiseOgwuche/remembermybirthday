import "dotenv/config";
import cors from "cors";
import express from "express";
import Anthropic from "@anthropic-ai/sdk";
import { Resend } from "resend";

const app = express();
app.use(cors());
app.use(express.json({ limit: "32kb" }));

const port = Number(process.env.PORT || 8787);
const anthropicKey = process.env.ANTHROPIC_API_KEY || "";
const model = process.env.ANTHROPIC_MODEL || "claude-haiku-4-5-20251001";
const resendKey = process.env.RESEND_API_KEY || "";
const emailFrom = process.env.EMAIL_FROM || "Remember My Birthday <onboarding@resend.dev>";

const anthropic = anthropicKey ? new Anthropic({ apiKey: anthropicKey }) : null;
const resend = resendKey ? new Resend(resendKey) : null;

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    anthropic: Boolean(anthropic),
    email: Boolean(resend),
  });
});

/** Companion enhance proxy — keeps the provider API key off the device. */
app.post("/v1/companion", async (req, res) => {
  if (!anthropic) {
    return res.status(503).json({ error: "ANTHROPIC_API_KEY not configured on server." });
  }

  const {
    personName = "Someone",
    relationship = "",
    notes = "",
    daysUntil = 0,
    hasPhone = false,
    localAction = "message",
  } = req.body || {};

  const prompt = `Birthday companion. Reply ONLY compact JSON keys:
action (call|message|giftAndMessage), primaryTitle, reason, whenLabel, wantsGift (bool), draft (string), gifts (array of 2 short gift strings).
Person: ${String(personName).slice(0, 80)}. Relationship: ${String(relationship).slice(0, 40) || "unknown"}. Notes: ${String(notes).slice(0, 160) || "none"}. Days until: ${Number(daysUntil) || 0}. Has phone: ${Boolean(hasPhone)}. Local hint action: ${String(localAction)}.
Keep draft under 220 chars. No preamble.`;

  try {
    const message = await anthropic.messages.create({
      model,
      max_tokens: 280,
      messages: [{ role: "user", content: prompt }],
    });

    const text = message.content?.find((b) => b.type === "text")?.text || "";
    const parsed = parseModelJSON(text);
    return res.json(parsed);
  } catch (err) {
    console.error("companion error", err);
    return res.status(502).json({ error: "Companion request failed." });
  }
});

app.post("/v1/email/welcome", async (req, res) => {
  return sendAccountEmail(req, res, "welcome");
});

app.post("/v1/email/signIn", async (req, res) => {
  return sendAccountEmail(req, res, "signIn");
});

app.post("/v1/email/reminder", async (req, res) => {
  if (!resend) {
    return res.status(503).json({ error: "RESEND_API_KEY not configured on server." });
  }
  const email = String(req.body?.email || "").trim();
  const personName = String(req.body?.personName || "Someone").slice(0, 80);
  const daysUntil = Number(req.body?.daysUntil);
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Valid email required." });
  }

  const when =
    daysUntil === 0
      ? "today"
      : daysUntil === 1
        ? "tomorrow"
        : `in ${daysUntil} days`;

  try {
    await resend.emails.send({
      from: emailFrom,
      to: email,
      subject: `${personName}'s birthday is ${when}`,
      text: [
        `Hey — ${personName}'s birthday is ${when}.`,
        "",
        "Open Remember My Birthday to call, draft a message, or schedule a send.",
        req.body?.note ? `\nNote: ${String(req.body.note).slice(0, 200)}` : "",
      ]
        .filter(Boolean)
        .join("\n"),
    });
    return res.json({ ok: true });
  } catch (err) {
    console.error("reminder email error", err);
    return res.status(502).json({ error: "Failed to send email." });
  }
});

async function sendAccountEmail(req, res, kind) {
  if (!resend) {
    return res.status(503).json({ error: "RESEND_API_KEY not configured on server." });
  }
  const email = String(req.body?.email || "").trim();
  const name = String(req.body?.name || "there").slice(0, 80);
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Valid email required." });
  }

  const isWelcome = kind === "welcome";
  const subject = isWelcome
    ? "Welcome to Remember My Birthday"
    : "You’re signed in to Remember My Birthday";
  const text = isWelcome
    ? `Hi ${name},\n\nYou’re in. Add people once, get reminders when it matters, and draft birthday messages in one tap.\n\n— Remember My Birthday`
    : `Hi ${name},\n\nJust confirming you’re signed in on a device. If this wasn’t you, sign out in the app Settings.\n\n— Remember My Birthday`;

  try {
    await resend.emails.send({ from: emailFrom, to: email, subject, text });
    return res.json({ ok: true });
  } catch (err) {
    console.error("account email error", err);
    return res.status(502).json({ error: "Failed to send email." });
  }
}

function isValidEmail(value) {
  return typeof value === "string" && value.includes("@") && value.includes(".") && value.length >= 5;
}

function parseModelJSON(text) {
  const cleaned = String(text)
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();
  let json;
  try {
    json = JSON.parse(cleaned);
  } catch {
    json = {};
  }
  return {
    action: json.action || "message",
    primaryTitle: json.primaryTitle || "Draft a message",
    reason: json.reason || "A short note keeps it personal.",
    whenLabel: json.whenLabel || "Act when your reminder lands.",
    wantsGift: Boolean(json.wantsGift),
    source: "anthropic",
    draftSuggestion: json.draft || null,
    giftTitles: Array.isArray(json.gifts) ? json.gifts.slice(0, 3).map(String) : [],
  };
}

app.listen(port, () => {
  console.log(`Remember companion backend on http://localhost:${port}`);
  console.log(`Companion: ${anthropic ? "ready" : "missing ANTHROPIC_API_KEY"}`);
  console.log(`Email: ${resend ? "ready" : "missing RESEND_API_KEY"}`);
});
