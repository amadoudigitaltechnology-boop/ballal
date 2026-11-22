// BALLAL — suppression définitive d'un compte (appelée par l'app après le RPC delete_my_account).
// La clé service reste côté serveur (variable d'environnement Supabase), jamais dans l'app.
import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return json({ error: "unauthorized" }, 401);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Sécurité : l'utilisateur doit d'abord avoir confirmé la suppression (statut "deleted").
  const { data: profile } = await admin.from("profiles").select("status").eq("id", user.id).single();
  if (profile?.status !== "deleted") return json({ error: "confirm_first" }, 409);

  // Fichiers publics de l'utilisateur (avatar, logo, portfolio…)
  for (const bucket of ["avatars", "pro-media", "verification-docs"]) {
    for (const folder of ["", "avatar", "logo", "cover", "portfolio"]) {
      const prefix = folder ? `${user.id}/${folder}` : user.id;
      const { data: files } = await admin.storage.from(bucket).list(prefix, { limit: 1000 });
      const paths = (files ?? []).filter((f) => f.id).map((f) => `${prefix}/${f.name}`);
      if (paths.length) await admin.storage.from(bucket).remove(paths);
    }
  }

  // Supprime auth.users → cascade sur toutes les tables liées (profil, demandes, messages…)
  const { error: delError } = await admin.auth.admin.deleteUser(user.id);
  if (delError) return json({ error: "delete_failed" }, 500);

  await admin.from("audit_logs").insert({ actor_id: null, action: "account.deleted", target_type: "user", target_id: user.id });
  return json({ ok: true });
});
