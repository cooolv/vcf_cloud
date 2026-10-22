# VCF Cloud — مدير جهات اتصال VCF مع مزامنة سحابية

تطبيق Flutter يشتغل على **ويندوز** و**أندرويد**:

- فتح واستيراد ملفات `.vcf` (حتى العربي والـ Quoted-Printable)، مع تخطي المكرر
- بحث بالاسم والرقم (بيتجاهل التشكيل والفروق بين أ/ا وى/ي)
- إضافة / تعديل / حذف / تحديد وحذف جماعي
- تصدير الكل أو المحدد لملف `.vcf`
- مزامنة فورية على Firebase Firestore، **كل مستخدم يشوف جهاته هو بس**
- كله مجاني (Firebase Spark + GitHub Actions للمشاريع العامة)

## للتحميل فقط
روح على **Releases** في الريبو ونزّل:
- `VCF-Cloud-Android.apk` (فعّل "تثبيت من مصادر غير معروفة")
- `VCF-Cloud-Windows.zip` (فكّه وشغّل `vcf_cloud.exe`)

> لو فتحت التطبيق وطلع "إعدادات Firebase ناقصة" يبقى الريبو اتبنى من غير Secrets، كمّل الخطوات تحت.

---

## الإعداد (مرة واحدة)

### 1) Firebase (مجاني، من غير كارت)
1. [console.firebase.google.com](https://console.firebase.google.com) ← Create project.
2. **Authentication** ← Sign-in method ← فعّل **Email/Password**.
3. **Firestore Database** ← Create database (Production mode) ← تبويب **Rules** ← الصق محتوى [`firestore.rules`](firestore.rules) ← Publish.
4. **Project settings ← Your apps**:
   - ضيف تطبيق **Android** باسم الحزمة `com.vcfcloud.vcf_cloud`.
   - ضيف تطبيق **Web** (ده اللي بيستخدمه ويندوز).

### 2) GitHub Secrets
في الريبو: **Settings ← Secrets and variables ← Actions ← New repository secret**

| Secret | من فين تجيبه |
|---|---|
| `FIREBASE_PROJECT_ID` | Project settings ← Project ID |
| `FIREBASE_SENDER_ID` | Project settings ← Cloud Messaging ← Sender ID (أو أول رقم في appId) |
| `FIREBASE_ANDROID_API_KEY` | `current_key` في ملف google-services.json لتطبيق Android |
| `FIREBASE_ANDROID_APP_ID` | Mobile SDK App ID لتطبيق Android (`1:...:android:...`) |
| `FIREBASE_WEB_API_KEY` | `apiKey` في إعدادات تطبيق الويب |
| `FIREBASE_WEB_APP_ID` | `appId` في إعدادات تطبيق الويب (`1:...:web:...`) |

**اختياري (توقيع ثابت لأندرويد عشان التحديثات تنزل فوق النسخة القديمة):**

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vcf
base64 -w0 release.jks     # على ويندوز: [Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks"))
```

| Secret | القيمة |
|---|---|
| `KEYSTORE_B64` | ناتج الـ base64 |
| `KS_PASS` | باسورد الـ keystore |
| `KS_ALIAS` | `vcf` |
| `KS_KEY_PASS` | باسورد المفتاح |

> من غير دول التطبيق هيتبني ويشتغل عادي، بس كل نسخة هتتوقّع بمفتاح مختلف وهتضطر تمسح القديمة قبل ما تثبّت الجديدة.

### 3) البناء
```bash
git tag v1.0.0
git push origin v1.0.0
```
أو من تبويب **Actions ← Build & Release ← Run workflow**. بعد ~10-15 دقيقة تلاقي الملفات في **Releases**.

---

## إيه السري وإيه مش سري؟ (مهم لأن الريبو عام)

**مش سر (آمن يتشاف):** مفاتيح Firebase (`apiKey`, `appId`, `projectId`). دي معرّفات بتتحط في أي تطبيق وبتظهر لأي حد يفك الـ APK. الحماية الحقيقية هي **قواعد Firestore** (`firestore.rules`) اللي بتخلي كل مستخدم يوصل لـ `users/{uid}` بتاعه بس. للأمان الإضافي في Google Cloud Console ← Credentials ← قيّد الـ API key على Android package لمفتاح الأندرويد.

**سري فعلاً (ممنوع يتحط في الكود أو يتشال في الريبو):**
- `release.jks` وباسوردات التوقيع ← الأربع Secrets الاختيارية فوق
- أي Service Account / Admin SDK key (التطبيق ده مش محتاجه)

الـ `.gitignore` بيمنع رفع `env.json` و`*.jks` و`key.properties` و`google-services.json`. مع ذلك المفاتيح في GitHub Secrets مش في الكود، فالريبو العام نضيف.

> لو حد فتح الريبو وبنى بمشروع Firebase بتاعه، بياناتك مش هتتأثر لأن مشروعك غير مشروعه.

## التشغيل محلياً (للمطورين)
```bash
cp env.example.json env.json   # املا القيم
flutter create --platforms=android,windows --org com.vcfcloud --project-name vcf_cloud .
python3 scripts/patch_android.py
flutter run --dart-define-from-file=env.json
```

## فتح ملفات VCF بالدبل كليك على ويندوز
كليك يمين على أي ملف `.vcf` ← Open with ← اختار `vcf_cloud.exe` ← Always. التطبيق بيستقبل المسار تلقائياً.
على أندرويد: افتح أو شارك ملف VCF واختار **VCF Cloud**.

## ملاحظات
- الحصة المجانية لـ Firestore: 20 ألف كتابة و50 ألف قراءة يومياً، تكفي للاستخدام الشخصي.
- التطبيق بيحفظ نسخة أوفلاين وبيزامن لما الإنترنت يرجع.
- الرخصة: MIT.
