// BALLAL — création d’un paiement (Djomy ou GeniusPay : Orange Money, MTN MoMo, Wave, carte).
// Appelée par l'application avec le jeton de l'utilisateur. Le montant vient UNIQUEMENT des réglages serveur.
// Guinée → Djomy (GNF). Pays de app_settings.geniuspay_countries → GeniusPay (XOF).
// Secrets : DJOMY_CLIENT_ID, DJOMY_CLIENT_SECRET, DJOMY_BASE_URL · GENIUSPAY_API_KEY, GENIUSPAY_API_SECRET.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const supa = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
// Lecture tolérante des secrets (accepte une petite faute de nom : DJOMY/JOMI, SECRET/SECRETS…).
const ENV = Deno.env.toObject();
const envFind = (exact: string, re: RegExp) =>
  (Object.entries(ENV).find(([k, v]) => (k.trim() === exact || re.test(k.trim())) && v.trim())?.[1] ?? "").trim();
const CLIENT_ID = envFind("DJOMY_CLIENT_ID", /^D?J[OA]?M[IY]_?CLIENT_?ID$/i);
const BASE = (envFind("DJOMY_BASE_URL", /^D?J[OA]?M[IY]_?BASE_?URL$/i) || "https://sandbox-api.djomy.africa").replace(/\/+$/, "");
const CLIENT_SECRET = envFind("DJOMY_CLIENT_SECRET", /^D?J[OA]?M[IY]_?CLIENT_?SECRETS?$/i);
const GP_KEY = envFind("GENIUSPAY_API_KEY", /^GENIUS_?PAY_?API_?KEY$/i);
const GP_SECRET = envFind("GENIUSPAY_API_SECRET", /^GENIUS_?PAY_?API_?SECRETS?$/i);
const GP_BASE = "https://geniuspay.ci/api/v1/merchant";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });

async function hmacHex(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function djomyHeaders(withToken: boolean): Promise<Record<string, string>> {
  const h: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
    "X-API-KEY": `${CLIENT_ID}:${await hmacHex(CLIENT_ID, CLIENT_SECRET)}`,
  };
  if (withToken) {
    const res = await fetch(`${BASE}/v1/auth`, { method: "POST", headers: h, body: "{}" });
    const body = await res.json().catch(() => ({}));
    const token = body?.access_token ?? body?.token ?? body?.data?.access_token ?? body?.data?.accessToken ?? body?.data?.token;
    if (!res.ok || !token) {
      console.error("djomy auth", res.status, JSON.stringify(body).slice(0, 300));
      throw new Error(`djomy_auth_${res.status}`);
    }
    h.Authorization = `Bearer ${token}`;
  }
  return h;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  // Utilisateur authentifié (jeton Supabase vérifié par le serveur).
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth } = await supa.auth.getUser(jwt);
  const user = auth?.user;
  if (!user) return json(401, { error: "unauthorized" });

  // Choix du prestataire selon le pays : Guinée → Djomy, autres pays listés → GeniusPay.
  const { data: prof } = await supa.from("profiles").select("country_code").eq("id", user.id).maybeSingle();
  const country = (prof?.country_code as string | null) ?? "GN";
  let provider: "djomy" | "geniuspay";
  if (country === "GN") provider = "djomy";
  else {
    const { data: gc } = await supa.from("app_settings").select("value").eq("key", "geniuspay_countries").maybeSingle();
    if (!(Array.isArray(gc?.value) && gc!.value.includes(country))) return json(403, { error: "country_not_supported" });
    provider = "geniuspay";
  }
  if (provider === "djomy" && (!CLIENT_ID || !CLIENT_SECRET)) {
    console.warn("DJOMY secrets introuvables. Noms vus :", Object.entries(ENV).filter(([k]) => /OMY|OMI|CLIENT/i.test(k)).map(([k, v]) => `[${k}]=${v.trim() ? "rempli" : "VIDE"}`).join(", ") || "aucun");
    return json(503, { error: "payment_not_configured" });
  }
  if (provider === "geniuspay" && (!GP_KEY || !GP_SECRET)) {
    console.warn("GENIUSPAY secrets introuvables. Noms vus :", Object.entries(ENV).filter(([k]) => /GENIUS/i.test(k)).map(([k, v]) => `[${k}]=${v.trim() ? "rempli" : "VIDE"}`).join(", ") || "aucun");
    return json(503, { error: "payment_not_configured" });
  }

  let input: { verification_id?: string; purpose?: string; days?: number } = {};
  try {
    input = (await req.json()) ?? {};
  } catch { /* corps invalide */ }

  // Plafond : 10 tentatives de paiement par heure.
  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count } = await supa.from("payments").select("id", { count: "exact", head: true }).eq("user_id", user.id).gt("created_at", since);
  if ((count ?? 0) >= 10) {
    console.warn("BALLAL_SECURITY payment_rate_limited", user.id);
    return json(429, { error: "rate_limited" });
  }

  let row: Record<string, unknown>;
  let amount: number;
  let description: string;

  if (input.purpose === "boost") {
    // Sponsorisation : réservée aux pros ; le prix vient de la grille « boost_plans » des réglages.
    const { data: pro } = await supa.from("professional_profiles").select("user_id").eq("user_id", user.id).maybeSingle();
    if (!pro) return json(403, { error: "not_professional" });
    const { data: plans } = await supa.from("app_settings").select("value").eq("key", "boost_plans").maybeSingle();
    const plan = (Array.isArray(plans?.value) ? plans!.value : []).find((p: { days: number }) => p.days === Number(input.days));
    if (!plan || !(Number(plan.price_gnf) > 0)) return json(400, { error: "bad_plan" });
    amount = Number(plan.price_gnf);
    description = `Sponsorisation Ballal ${plan.days} jours`;
    row = { user_id: user.id, purpose: "boost", boost_days: plan.days, amount_gnf: amount };
  } else {
    const verificationId = input.verification_id;
    if (!verificationId || !/^[0-9a-f-]{36}$/i.test(verificationId)) return json(400, { error: "bad_request" });
    // La demande de vérification doit appartenir à l'utilisateur, être en attente et non payée.
    const { data: doc } = await supa
      .from("verification_documents")
      .select("id, user_id, status, payment_reference")
      .eq("id", verificationId)
      .maybeSingle();
    if (!doc || doc.user_id !== user.id || doc.status !== "pending") return json(404, { error: "verification_not_found" });
    if (doc.payment_reference) return json(409, { error: "already_paid" });
    const { data: fee } = await supa.from("app_settings").select("value").eq("key", "verification_fee_gnf").maybeSingle();
    amount = Number(fee?.value);
    if (!Number.isFinite(amount) || amount <= 0) return json(503, { error: "fee_not_configured" });
    description = "Vérification du compte Ballal";
    row = { user_id: user.id, purpose: "verification", verification_id: verificationId, amount_gnf: amount };
  }

  // Montant facturé : GNF pour Djomy, converti en XOF (arrondi à la centaine, minimum 200) pour GeniusPay.
  let currency = "GNF";
  let charged = amount;
  if (provider === "geniuspay") {
    const { data: r } = await supa.from("app_settings").select("value").eq("key", "gnf_per_xof").maybeSingle();
    const rate = Number(r?.value) > 0 ? Number(r!.value) : 15;
    currency = "XOF";
    charged = Math.max(200, Math.ceil(amount / rate / 100) * 100);
  }
  row = { ...row, provider, currency, amount_charged: charged };

  const { data: pay, error: insErr } = await supa.from("payments").insert(row).select("id").single();
  if (insErr || !pay) {
    console.error("payment insert", insErr?.message);
    return json(500, { error: "payment_create_failed" });
  }

  if (provider === "geniuspay") {
    try {
      const back = `${SUPABASE_URL}/functions/v1/geniuspay-webhook?ref=${pay.id}`;
      const { data: u } = await supa.from("profiles").select("full_name").eq("id", user.id).maybeSingle();
      const res = await fetch(`${GP_BASE}/payments`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-API-Key": GP_KEY, "X-API-Secret": GP_SECRET },
        body: JSON.stringify({
          amount: charged,
          currency: "XOF",
          description,
          customer: { name: (u?.full_name as string | null) ?? undefined, email: user.email ?? undefined, country },
          success_url: back,
          error_url: `${back}&cancel=1`,
          metadata: { payment_id: pay.id, user_id: user.id },
        }),
      });
      const body = await res.json().catch(() => ({}));
      const d = body?.data ?? body;
      const redirectUrl: string | undefined = d?.checkout_url ?? d?.payment_url;
      const reference: string | undefined = d?.reference;
      if (!res.ok || !redirectUrl || !reference) {
        console.error("geniuspay create", res.status, JSON.stringify(body).slice(0, 300));
        await supa.from("payments").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", pay.id);
        return json(502, { error: "gateway_error" });
      }
      await supa.from("payments").update({ redirect_url: redirectUrl, provider_reference: reference, updated_at: new Date().toISOString() }).eq("id", pay.id);
      return json(200, { payment_id: pay.id, redirect_url: redirectUrl, amount: charged, currency });
    } catch (e) {
      console.error("geniuspay", String(e));
      await supa.from("payments").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", pay.id);
      return json(502, { error: "gateway_error" });
    }
  }

  try {
    const back = `${SUPABASE_URL}/functions/v1/djomy-webhook?ref=${pay.id}`;
    const res = await fetch(`${BASE}/v1/payments/gateway`, {
      method: "POST",
      headers: await djomyHeaders(true),
      body: JSON.stringify({
        amount,
        countryCode: "GN",
        description,
        merchantPaymentReference: pay.id,
        returnUrl: back,
        cancelUrl: `${back}&cancel=1`,
        allowedPaymentMethods: ["OM", "MOMO", "CARD"],
        metadata: { payment_id: pay.id, user_id: user.id },
      }),
    });
    const body = await res.json().catch(() => ({}));
    const d = body?.data ?? body;
    const redirectUrl: string | undefined = d?.redirectUrl ?? d?.paymentUrl ?? d?.url;
    const tx: string | undefined = d?.transactionId ?? d?.id;
    if (!res.ok || !redirectUrl) {
      console.error("djomy gateway", res.status, JSON.stringify(body).slice(0, 300));
      await supa.from("payments").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", pay.id);
      return json(502, { error: "gateway_error" });
    }
    await supa.from("payments").update({ redirect_url: redirectUrl, provider_tx_id: tx ?? null, updated_at: new Date().toISOString() }).eq("id", pay.id);
    return json(200, { payment_id: pay.id, redirect_url: redirectUrl, amount: charged, currency });
  } catch (e) {
    console.error("djomy", String(e));
    await supa.from("payments").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", pay.id);
    return json(502, { error: "gateway_error" });
  }
});
