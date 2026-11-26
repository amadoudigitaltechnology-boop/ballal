#!/usr/bin/env python3
"""Ajoute les permissions Android / iOS nécessaires à BALLAL.

À lancer UNE fois après :  flutter create --org com.amadoutechnology --project-name ballal --platforms android,ios .
Usage : python3 tool/setup_platforms.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ─── Android ───
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")
permissions = """    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Position APPROXIMATIVE uniquement : suffisante pour trier par distance -->
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
"""
queries = """    <queries>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
    </queries>
"""
if "RECORD_AUDIO" not in m:
    m = m.replace("<application", permissions + "    <application", 1)
if "android.intent.action.DIAL" not in m:
    m = m.replace("</manifest>", queries + "</manifest>")
m = m.replace('android:label="ballal"', 'android:label="Ballal"')
# Sécurité : HTTPS obligatoire, pas de sauvegarde cloud des données de session.
if "usesCleartextTraffic" not in m:
    m = m.replace('android:label="Ballal"', 'android:label="Ballal"\n        android:usesCleartextTraffic="false"\n        android:allowBackup="false"', 1)
manifest.write_text(m, encoding="utf-8")
print("Android : permissions ajoutées")

# ─── iOS ───
plist = ROOT / "ios/Runner/Info.plist"
p = plist.read_text(encoding="utf-8") if plist.exists() else None
keys = {
    "NSLocationWhenInUseUsageDescription": "BALLAL utilise votre position approximative pour vous montrer les professionnels proches. Elle n'est jamais publiée.",
    "NSMicrophoneUsageDescription": "Le micro sert à envoyer des messages vocaux aux professionnels.",
    "NSCameraUsageDescription": "L'appareil photo sert à joindre des photos à vos demandes et messages.",
    "NSPhotoLibraryUsageDescription": "Vos photos servent à illustrer vos demandes, messages et réalisations.",
}
block = "" if p is None else "".join(f"\t<key>{k}</key>\n\t<string>{v}</string>\n" for k, v in keys.items() if k not in p)
if block:
    idx = p.rfind("</dict>")
    p = p[:idx] + block + p[idx:]
if p is not None:
    p = p.replace("<string>Ballal</string>", "<string>BALLAL</string>")
    plist.write_text(p, encoding="utf-8")
    print("iOS : descriptions de permissions ajoutées")

# ─── Test généré par « flutter create » (il référence MyApp, qui n'existe pas ici) ───
default_test = ROOT / "test/widget_test.dart"
if default_test.exists() and "MyApp" in default_test.read_text(encoding="utf-8"):
    default_test.unlink()
    print("test/widget_test.dart (modèle Flutter) supprimé")

# ─── Icône de l'application (le « B » BALLAL) ───
import shutil
icons = ROOT / "tool/icons"
res = ROOT / "android/app/src/main/res"
if res.exists():
    for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        target = res / f"mipmap-{d}"
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(icons / f"ic_launcher_{d}.png", target / "ic_launcher.png")
    print("Android : icône BALLAL installée")
appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
if appicon.exists():
    try:
        from PIL import Image  # facultatif
        src = Image.open(icons / "icon_512.png")
        for f in appicon.glob("*.png"):
            w, h = Image.open(f).size
            src.resize((w, h)).convert("RGB").save(f)
        print("iOS : icône BALLAL installée")
    except Exception as e:  # noqa: BLE001
        print(f"iOS : icône non remplacée ({e})")

# ─── Signature officielle (si signing/key.properties existe, créé par la CI depuis les secrets) ───
props = ROOT / "signing/key.properties"
gradle = ROOT / "android/app/build.gradle.kts"
if props.exists() and gradle.exists():
    g = gradle.read_text(encoding="utf-8")
    if "ballalSigning" not in g:
        header = """import java.util.Properties
import java.io.FileInputStream

val ballalSigning = Properties().apply {
    val f = rootProject.file("../signing/key.properties")
    if (f.exists()) load(FileInputStream(f))
}

"""
        g = header + g
        g = g.replace("    buildTypes {", """    signingConfigs {
        create("release") {
            keyAlias = ballalSigning.getProperty("keyAlias")
            keyPassword = ballalSigning.getProperty("keyPassword")
            storeFile = file(ballalSigning.getProperty("storeFile"))
            storePassword = ballalSigning.getProperty("storePassword")
        }
    }

    buildTypes {""", 1)
        g = g.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
        gradle.write_text(g, encoding="utf-8")
        print("Android : signature officielle configurée")

# ─── Firebase (notifications push) ───
gs = ROOT / "tool/firebase/google-services.json"
app_dir = ROOT / "android/app"
settings_gradle = ROOT / "android/settings.gradle.kts"
app_gradle = ROOT / "android/app/build.gradle.kts"
if gs.exists() and app_dir.exists():
    shutil.copyfile(gs, app_dir / "google-services.json")
    if settings_gradle.exists():
        sg = settings_gradle.read_text(encoding="utf-8")
        if "com.google.gms.google-services" not in sg:
            sg = sg.replace('id("com.android.application")',
                            'id("com.google.gms.google-services") version "4.4.2" apply false\n    id("com.android.application")', 1)
            settings_gradle.write_text(sg, encoding="utf-8")
    if app_gradle.exists():
        ag = app_gradle.read_text(encoding="utf-8")
        if "com.google.gms.google-services" not in ag:
            ag = ag.replace('id("com.android.application")', 'id("com.android.application")\n    id("com.google.gms.google-services")', 1)
            app_gradle.write_text(ag, encoding="utf-8")
    m = manifest.read_text(encoding="utf-8")
    if "POST_NOTIFICATIONS" not in m:
        m = m.replace("<application", '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application', 1)
    if "default_notification_color" not in m:
        m = m.replace("</application>", '''        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="activity"/>
    </application>''', 1)
    manifest.write_text(m, encoding="utf-8")
    print("Android : Firebase configuré")

# ─── Retour de la connexion Google (lien profond) ───
m = manifest.read_text(encoding="utf-8")
if "login-callback" not in m:
    m = m.replace("</activity>", '''    <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="com.amadoutechnology.ballal" android:host="login-callback"/>
            </intent-filter>
        </activity>''', 1)
    manifest.write_text(m, encoding="utf-8")
    print("Android : lien de retour Google configuré")
