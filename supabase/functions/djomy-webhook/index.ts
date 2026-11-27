// BALLAL — confirmations Djomy.
//  • POST : webhook Djomy, signature X-Webhook-Signature (HMAC-SHA256 du corps brut avec le client secret) vérifiée.
//  • GET ?ref=… : retour du client après paiement, puis redirection vers l'application.
// Dans les deux cas, le statut est revérifié directement auprès de Djomy avant de valider.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const BASE = (Deno.env.get("DJOMY_BASE_URL") ?? "https://sandbox-api.djomy.africa").replace(/\/+$/, "");
const CLIENT_ID = Deno.env.get("DJOMY_CLIENT_ID") ?? "";
const CLIENT_SECRET = Deno.env.get("DJOMY_CLIENT_SECRET") ?? "";
const APP_RETURN = "com.amadoutechnology.ballal://payment-return";

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

async function djomyStatus(tx: string): Promise<{ status?: string; paidAmount?: number; method?: string }> {
  const h: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
    "X-API-KEY": `${CLIENT_ID}:${await hmacHex(CLIENT_ID, CLIENT_SECRET)}`,
  };
  const a = await fetch(`${BASE}/v1/auth`, { method: "POST", headers: h, body: "{}" });
  const ab = await a.json().catch(() => ({}));
  const token = ab?.access_token ?? ab?.token ?? ab?.data?.access_token ?? ab?.data?.accessToken ?? ab?.data?.token;
  if (token) h.Authorization = `Bearer ${token}`;
  const r = await fetch(`${BASE}/v1/payments/${encodeURIComponent(tx)}/status`, { headers: h });
  const b = await r.json().catch(() => ({}));
  const d = b?.data?.payment ?? b?.data ?? b;
  return { status: String(d?.status ?? "").toUpperCase(), paidAmount: Number(d?.paidAmount ?? d?.amount) || undefined, method: d?.paymentMethod ?? d?.method };
}

async function settle(paymentId: string, tx: string | null) {
  const { data: p } = await supa.from("payments").select("id, status, provider_tx_id").eq("id", paymentId).maybeSingle();
  if (!p || p.status !== "pending") return p?.status ?? "unknown";
  const t = tx ?? p.provider_tx_id;
  if (!t) return "pending";
  const s = await djomyStatus(t);
  if (s.status === "SUCCESS") {
    await supa.rpc("payment_mark_success", { p_payment: p.id, p_tx: t, p_paid: s.paidAmount ?? null, p_method: s.method ?? null });
    return "success";
  }
  if (["FAILED", "CANCELLED", "TIMEOUT", "EXPIRED"].includes(s.status ?? "")) {
    await supa.from("payments").update({ status: s.status === "FAILED" ? "failed" : "cancelled", provider_tx_id: t, updated_at: new Date().toISOString() }).eq("id", p.id);
    return "failed";
  }
  return "pending";
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Retour du navigateur après paiement → on revérifie puis on rouvre l'application.
  if (req.method === "GET") {
    const ref = url.searchParams.get("ref") ?? "";
    let status = "pending";
    if (/^[0-9a-f-]{36}$/i.test(ref) && CLIENT_ID) {
      try {
        status = url.searchParams.get("cancel") ? "cancelled" : await settle(ref, null);
      } catch (e) {
        console.error("return", String(e));
      }
    }
    return Response.redirect(`${APP_RETURN}?ref=${encodeURIComponent(ref)}&status=${status}`, 302);
  }

  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const raw = await req.text();
  const header = (req.headers.get("x-webhook-signature") ?? "").trim();
  const provided = header.includes(":") ? header.slice(header.indexOf(":") + 1) : header;
  const expected = CLIENT_SECRET ? await hmacHex(raw, CLIENT_SECRET) : "";
  if (!expected || !provided || !sameText(provided, expected)) {
    console.warn("BALLAL_SECURITY djomy_bad_signature", req.headers.get("x-forwarded-for") ?? "");
    return new Response("unauthorized", { status: 401 });
  }

  let event: Record<string, any> = {};
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("bad request", { status: 400 });
  }
  const pay = event?.data?.payment ?? event?.data ?? {};
  const tx: string | null = pay?.transactionId ?? null;
  const ref: string | null = pay?.merchantPaymentReference ?? event?.data?.metadata?.payment_id ?? pay?.metadata?.payment_id ?? null;

  let paymentId: string | null = null;
  if (ref && /^[0-9a-f-]{36}$/i.test(ref)) paymentId = ref;
  else if (tx) {
    const { data } = await supa.from("payments").select("id").eq("provider_tx_id", tx).maybeSingle();
    paymentId = data?.id ?? null;
  }
  if (!paymentId) return new Response(JSON.stringify({ ignored: true }), { headers: { "Content-Type": "application/json" } });

  try {
    const status = await settle(paymentId, tx);
    return new Response(JSON.stringify({ status }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    console.error("webhook", String(e));
    return new Response("retry", { status: 500 });
  }
});
