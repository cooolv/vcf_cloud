"""يعدّل ملفات أندرويد المتولدة من `flutter create` وقت البناء:
- صلاحية الإنترنت
- فتح ملفات VCF من برّه التطبيق
- minSdk 23 (مطلوب لـ Firebase)
- توقيع ثابت لو الـ keystore موجود (عشان التحديثات تنزل فوق النسخة القديمة)
"""
import os, re, glob

manifest = "android/app/src/main/AndroidManifest.xml"
m = open(manifest, encoding="utf-8").read()

if "android.permission.INTERNET" not in m:
    m = m.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

filters = """
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="content"/>
                <data android:scheme="file"/>
                <data android:mimeType="text/x-vcard"/>
                <data android:mimeType="text/vcard"/>
                <data android:mimeType="text/directory"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/x-vcard"/>
                <data android:mimeType="text/vcard"/>
            </intent-filter>
"""
if "text/x-vcard" not in m:
    m = m.replace("</activity>", filters + "        </activity>", 1)

m = m.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')
m = re.sub(r'android:label="[^"]*"', 'android:label="VCF Cloud"', m, count=1)
open(manifest, "w", encoding="utf-8").write(m)

gradle = None
for p in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if os.path.exists(p):
        gradle = p
        break
g = open(gradle, encoding="utf-8").read()
g = g.replace("flutter.minSdkVersion", "23")
g = re.sub(r"compileSdk(?:Version)?\s*=?\s*flutter\.compileSdkVersion", "compileSdk = 37", g)

with open("android/gradle.properties", "a", encoding="utf-8") as gp:
    gp.write("\nandroid.suppressUnsupportedCompileSdk=37\n")
    
if os.environ.get("KS_PASS") and gradle.endswith(".kts"):
    signing = '''
    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = System.getenv("KS_PASS")
            keyAlias = System.getenv("KS_ALIAS")
            keyPassword = System.getenv("KS_KEY_PASS")
        }
    }
'''
    g = g.replace("android {", "android {" + signing, 1)
    g = g.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
    print("release signing enabled")
else:
    print("no keystore: APK will be debug-signed")
open(gradle, "w", encoding="utf-8").write(g)
print("android patched")
