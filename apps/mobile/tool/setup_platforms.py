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
m = m.replace('android:label="ballal"', 'android:label="BALLAL"')
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
