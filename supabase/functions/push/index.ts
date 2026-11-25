// BALLAL — envoi des notifications push (Firebase Cloud Messaging, API HTTP v1).
// Appelée par la base à chaque notification créée : { notification_id }.
// Sécurité : seul l'appel de la base (en-tête secret x-ballal-hook) est accepté ; la fonction relit
// la notification en base (clé service) et ne l'envoie qu'une fois, si elle a moins de 10 minutes.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supa = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

type ServiceAccount = { client_email: string; private_key: string; project_id: string };

let cachedToken: { value: string; exp: number } | null = null;

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const jwt = `${header}.${claims}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}: ${await res.text()}`);
  const json = await res.json();
  cachedToken = { value: json.access_token, exp: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

// Écran à ouvrir quand on touche la notification.
function routeFor(n: { type: string; entity_type: string | null; entity_id: string | null }): string {
  if (n.entity_type === "conversation" && n.entity_id) return `/chat/${n.entity_id}`;
  if (n.entity_type === "service_request" && n.entity_id) return `/requests/${n.entity_id}`;
  if (n.entity_type === "professional" && n.entity_id) return `/pro-dashboard`;
  return "/notifications";
}

let hookSecret: { value: string; at: number } | null = null;
async function expectedSecret(): Promise<string | null> {
  if (hookSecret && Date.now() - hookSecret.at < 5 * 60 * 1000) return hookSecret.value;
  const { data } = await supa.from("app_settings").select("value").eq("key", "push_hook_secret").maybeSingle();
  const v = typeof data?.value === "string" ? data.value : null;
  if (v) hookSecret = { value: v, at: Date.now() };
  return v;
}

/** Comparaison à temps constant (pas d'indice sur le secret par la durée de réponse). */
function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "X-Content-Type-Options": "nosniff", "Cache-Control": "no-store" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const expected = await expectedSecret();
  const given = req.headers.get("x-ballal-hook") ?? "";
  if (!expected || !sameSecret(given, expected)) {
    console.warn("BALLAL_SECURITY push_forbidden", req.headers.get("x-forwarded-for") ?? "");
    return json(401, { error: "unauthorized" });
  }
  let id: string | undefined;
  try {
    id = (await req.json())?.notification_id;
  } catch { /* corps invalide */ }
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) return new Response("bad request", { status: 400 });

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) return new Response("push non configuré", { status: 503 });
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(raw);
  } catch {
    return new Response("FCM_SERVICE_ACCOUNT invalide", { status: 500 });
  }

  // Réserve la notification (une seule fois, moins de 10 minutes).
  const { data: n } = await supa
    .from("notifications")
    .update({ pushed_at: new Date().toISOString() })
    .eq("id", id)
    .is("pushed_at", null)
    .gt("created_at", new Date(Date.now() - 10 * 60 * 1000).toISOString())
    .select("id, user_id, type, title, body, entity_type, entity_id")
    .maybeSingle();
  if (!n) return new Response(JSON.stringify({ skipped: true }), { headers: { "Content-Type": "application/json" } });

  const { data: tokens } = await supa.from("device_tokens").select("token").eq("user_id", n.user_id);
  if (!tokens?.length) return new Response(JSON.stringify({ sent: 0 }), { headers: { "Content-Type": "application/json" } });

  const { count: unread } = await supa
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("user_id", n.user_id)
    .is("read_at", null);

  const bearer = await accessToken(sa);
  let sent = 0;
  const dead: string[] = [];
  await Promise.all(tokens.map(async ({ token }) => {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: n.title, body: n.body ?? "" },
          data: { route: routeFor(n), type: n.type, notification_id: n.id },
          android: {
            priority: "HIGH",
            notification: {
              channel_id: n.type === "new_message" ? "messages" : "activity",
              color: "#1A56DB",
              notification_count: unread ?? 1,
              tag: n.entity_id ?? n.id,
            },
          },
          apns: { payload: { aps: { sound: "default", badge: unread ?? 1 } } },
        },
      }),
    });
    if (res.ok) {
      sent++;
    } else {
      const text = await res.text();
      if (res.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) dead.push(token);
      console.error("FCM", res.status, text.slice(0, 300));
    }
  }));
  if (dead.length) await supa.from("device_tokens").delete().in("token", dead);
  return new Response(JSON.stringify({ sent, removed: dead.length }), { headers: { "Content-Type": "application/json" } });
});
