import "dotenv/config";
import cors from "cors";
import express from "express";
import Anthropic from "@anthropic-ai/sdk";
import sgMail from "@sendgrid/mail";
import { welcomeEmail, signInEmail, reminderEmail } from "./emailTemplates.js";

const app = express();
app.use(cors());
app.use(express.json({ limit: "32kb" }));

const port = Number(process.env.PORT || 8787);
const anthropicKey = process.env.ANTHROPIC_API_KEY || "";
const model = process.env.ANTHROPIC_MODEL || "claude-haiku-4-5-20251001";
const sendgridKey = process.env.SENDGRID_API_KEY || "";
const emailFrom =
  process.env.EMAIL_FROM || "Remember My Birthday <hello@remembermybirthday.me>";

const anthropic = anthropicKey ? new Anthropic({ apiKey: anthropicKey }) : null;
const emailReady = Boolean(sendgridKey);

if (emailReady) {
  sgMail.setApiKey(sendgridKey);
}

app.get("/", (_req, res) => {
  res.type("text").send("Remember companion backend is running. Try GET /health");
});

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    companion: Boolean(anthropic),
    email: emailReady,
  });
});

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
  if (!emailReady) {
    return res.status(503).json({ error: "SENDGRID_API_KEY not configured on server." });
  }
  const email = String(req.body?.email || "").trim();
  const personName = String(req.body?.personName || "Someone").slice(0, 80);
  const daysUntil = Number(req.body?.daysUntil);
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Valid email required." });
  }

  const rawNote = req.body?.note ? String(req.body.note).slice(0, 200) : "";
  const note = rawNote.startsWith("Manual test") ? "" : rawNote;
  const template = reminderEmail({ personName, daysUntil, note: note || undefined });

  try {
    await sendMail({ to: email, ...template });
    return res.json({ ok: true });
  } catch (err) {
    console.error("reminder email error", err?.response?.body || err);
    return res.status(502).json({ error: "Failed to send email." });
  }
});

async function sendAccountEmail(req, res, kind) {
  if (!emailReady) {
    return res.status(503).json({ error: "SENDGRID_API_KEY not configured on server." });
  }
  const email = String(req.body?.email || "").trim();
  const name = String(req.body?.name || "there").slice(0, 80);
  if (!isValidEmail(email)) {
    return res.status(400).json({ error: "Valid email required." });
  }

  const template = kind === "welcome" ? welcomeEmail(name) : signInEmail(name);

  try {
    await sendMail({ to: email, ...template });
    return res.json({ ok: true });
  } catch (err) {
    console.error("account email error", err?.response?.body || err);
    return res.status(502).json({ error: "Failed to send email." });
  }
}

async function sendMail({ to, subject, text, html }) {
  await sgMail.send({
    to,
    from: emailFrom,
    subject,
    text,
    html,
  });
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

app.listen(port, "0.0.0.0", () => {
  console.log(`Remember companion backend on http://0.0.0.0:${port}`);
  console.log(`Companion: ${anthropic ? "ready" : "missing ANTHROPIC_API_KEY"}`);
  console.log(`Email: ${emailReady ? "ready (SendGrid)" : "missing SENDGRID_API_KEY"}`);
});
