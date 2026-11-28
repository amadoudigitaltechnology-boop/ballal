// BALLAL — confirmations GeniusPay.
//  • POST : webhook GeniusPay. Signature X-Webhook-Signature = HMAC-SHA256(timestamp + "." + corps brut, whsec_…),
//    horodatage X-Webhook-Timestamp accepté à ±5 minutes.
//  • GET ?ref=… : retour du client après paiement, puis redirection vers l'application.
// Dans les deux cas, le statut est revérifié directement auprès de GeniusPay avant de valider.
// Secrets : GENIUSPAY_API_KEY, GENIUSPAY_API_SECRET, GENIUSPAY_WEBHOOK_SECRET.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const ENV = Deno.env.toObject();
const envFind = (exact: string, re: RegExp) =>
  (Object.entries(ENV).find(([k, v]) => (k.trim() === exact || re.test(k.trim())) && v.trim())?.[1] ?? "").trim();
const GP_KEY = envFind("GENIUSPAY_API_KEY", /^GENIUS_?PAY_?API_?KEY$/i);
const GP_SECRET = envFind("GENIUSPAY_API_SECRET", /^GENIUS_?PAY_?API_?SECRETS?$/i);
const WH_SECRET = envFind("GENIUSPAY_WEBHOOK_SECRET", /^GENIUS_?PAY_?WEBHOOK_?SECRETS?$/i);
const GP_BASE = "https://geniuspay.ci/api/v1/merchant";
const APP_RETURN = "com.amadoutechnology.ballal://payment-return";
const UUID = /^[0-9a-f-]{36}$/i;

async function hmacHex(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function sameText(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

async function gpStatus(reference: string): Promise<{ status: string; amount?: number; method?: string }> {
  const r = await fetch(`${GP_BASE}/payments/${encodeURIComponent(reference)}`, {
    headers: { Accept: "application/json", "X-API-Key": GP_KEY, "X-API-Secret": GP_SECRET },
  });
  const b = await r.json().catch(() => ({}));
  const d = b?.data ?? b;
  if (!r.ok) console.error("geniuspay status", r.status, JSON.stringify(b).slice(0, 200));
  return { status: String(d?.status ?? "").toLowerCase(), amount: Number(d?.amount) || undefined, method: d?.payment_method ?? d?.gateway };
}

async function settle(paymentId: string) {
  const { data: p } = await supa.from("payments").select("id, status, provider, provider_reference").eq("id", paymentId).maybeSingle();
  if (!p || p.provider !== "geniuspay") return "unknown";
  if (p.status !== "pending") return p.status;
  if (!p.provider_reference) return "pending";
  const s = await gpStatus(p.provider_reference);
  if (s.status === "completed" || s.status === "success") {
    await supa.rpc("payment_mark_success", { p_payment: p.id, p_tx: p.provider_reference, p_paid: s.amount ?? null, p_method: s.method ?? "geniuspay" });
    return "success";
  }
  if (["failed", "cancelled", "expired"].includes(s.status)) {
    await supa.from("payments").update({ status: s.status === "failed" ? "failed" : "cancelled", updated_at: new Date().toISOString() }).eq("id", p.id);
    return "failed";
  }
  return "pending";
}

const ok = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Retour du navigateur après paiement → on revérifie puis on rouvre l'application.
  if (req.method === "GET") {
    const ref = url.searchParams.get("ref") ?? "";
    let status = "pending";
    if (UUID.test(ref) && GP_KEY) {
      try {
        status = await settle(ref);
        if (status === "pending" && url.searchParams.get("cancel")) status = "cancelled";
      } catch (e) {
        console.error("return", String(e));
      }
    }
    return Response.redirect(`${APP_RETURN}?ref=${encodeURIComponent(ref)}&status=${status}`, 302);
  }

  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const raw = await req.text();
  const ts = (req.headers.get("x-webhook-timestamp") ?? "").trim();
  const header = (req.headers.get("x-webhook-signature") ?? "").trim();
  const provided = header.replace(/^(sha256=|v1=)/i, "");
  const fresh = /^\d+$/.test(ts) && Math.abs(Date.now() / 1000 - Number(ts)) <= 300;
  const expected = WH_SECRET && ts ? await hmacHex(`${ts}.${raw}`, WH_SECRET) : "";
  if (!expected || !provided || !fresh || !sameText(provided.toLowerCase(), expected)) {
    console.warn("BALLAL_SECURITY geniuspay_bad_signature", req.headers.get("x-forwarded-for") ?? "", fresh ? "" : "stale");
    return new Response("unauthorized", { status: 401 });
  }

  let event: Record<string, any> = {};
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("bad request", { status: 400 });
  }
  if (event?.event === "webhook.test") return ok({ received: true });

  const d = event?.data ?? {};
  const metaId: string | null = d?.metadata?.payment_id ?? null;
  let paymentId: string | null = metaId && UUID.test(metaId) ? metaId : null;
  if (!paymentId && d?.reference) {
    const { data } = await supa.from("payments").select("id").eq("provider", "geniuspay").eq("provider_reference", d.reference).maybeSingle();
    paymentId = data?.id ?? null;
  }
  if (!paymentId) return ok({ ignored: true });

  try {
    return ok({ status: await settle(paymentId) });
  } catch (e) {
    console.error("webhook", String(e));
    return new Response("retry", { status: 500 });
  }
});
