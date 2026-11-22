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
