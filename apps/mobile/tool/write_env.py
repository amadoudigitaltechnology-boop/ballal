"""Écrit le fichier de configuration de compilation à partir des variables d'environnement, après vérification.

Refuse : variable absente, URL non https, clé autre que la clé publique « anon ».
"""
import base64, json, os, re, sys

out = sys.argv[1]
url = os.environ.get("SUPABASE_URL", "").strip()
key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
if not url or not key:
    sys.exit("ERREUR : ajoutez les secrets GitHub SUPABASE_URL et SUPABASE_ANON_KEY (Settings > Secrets > Actions).")
if not re.fullmatch(r"https://[a-z0-9-]+\.supabase\.co", url):
    sys.exit("ERREUR : SUPABASE_URL doit être https://<projet>.supabase.co")
role = None
if key.startswith("sb_publishable_"):
    role = "anon"
else:
    try:
        part = key.split(".")[1]
        role = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))).get("role")
    except Exception:
        pass
if role != "anon":
    sys.exit("ERREUR : SUPABASE_ANON_KEY doit être la clé publique anon, jamais service_role.")
os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
with open(out, "w") as f:
    json.dump({"SUPABASE_URL": url, "SUPABASE_ANON_KEY": key, "TERMS_VERSION": "2026-11"}, f)
print("Configuration vérifiée")
