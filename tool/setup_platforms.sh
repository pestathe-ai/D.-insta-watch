#!/usr/bin/env bash
# Genera le cartelle android/ e ios/ (non versionate) e applica le modifiche necessarie.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --project-name insta_watch --org dev.dinstawatch --platforms=android,ios .
rm -f test/widget_test.dart

MANIFEST=android/app/src/main/AndroidManifest.xml
# Permesso internet nella build di release (serve per chiamare Gemini).
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
# Nome visibile dell'app.
sed -i 's#android:label="[^"]*"#android:label="D. Insta Watch"#' "$MANIFEST"

# image_picker richiede minSdk 24.
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i -E 's/minSdk( = |Version )flutter\.minSdkVersion/minSdk\1 24/' "$f"
  sed -i -E 's/minSdk = flutter\.minSdkVersion/minSdk = 24/' "$f"
done

# iOS: descrizioni per foto e fotocamera (solo su macOS).
if [ "$(uname)" = "Darwin" ] && [ -f ios/Runner/Info.plist ]; then
  /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'Per scegliere le foto degli orologi.'" ios/Runner/Info.plist || true
  /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'Per fotografare gli orologi.'" ios/Runner/Info.plist || true
fi

echo "--- Manifest ---"; cat "$MANIFEST"
echo "--- minSdk ---"; grep -n minSdk android/app/build.gradle* || true

flutter pub get
