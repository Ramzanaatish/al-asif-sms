# Al-Asif SMS — Android app (Capacitor 6)

Al-Asif Public Middle School, Basti Shaikhan, Tehsil Liaquatpur.
Ye v7 HTML app (`www/index.html`) ka Android wrapper hai — school ke Windows
software se sync hota hai (students, fees/challans, hazri, marks, staff,
kharchay). App ID: `com.alasif.sms`.

## APK kaise banayein (GitHub Actions — sab se aasan)

1. Is folder ki files ko GitHub repo main push karein (branch `main`).
2. GitHub par repo ke **Actions** tab main jayein — "Build APK" workflow
   khud chal pare ga.
3. Workflow khatam hone par **app-debug** artifact download karein —
   us main `app-debug.apk` hoti hai. Phone par install karein
   ("Install unknown apps" Allow karein).

## Apne PC par build karna ho to

- JDK 17 + Android SDK 34 (platform-tools, platforms;android-34,
  build-tools;34.0.0) chahiye.
- `npm ci` phir `npm run build` — APK yahan mile gi:
  `android/app/build/outputs/apk/debug/app-debug.apk`

## Sync kaise karein

- Phone aur PC **same Wi-Fi** par hon, ya **Tailscale** se kahin se bhi.
- APK main: Settings → Server Sync → Server URL = school PC ki IP
  (software ki title bar main likhi hoti hai, masalan
  `http://192.168.1.5:8000`, ya Tailscale wali `http://100.64.x.x:8000`)
  → username/password → Connect & Sync Now.
- PC ka software sync ke waqt **khula** hona chahiye.
