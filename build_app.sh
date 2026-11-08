#!/bin/bash
# Builds Snowmac.app (release build, ad-hoc signed) into ./dist and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="dist/Snowmac.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/flurry "$APP/Contents/MacOS/Snowmac"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Snowmac</string>
  <key>CFBundleDisplayName</key><string>Snowmac</string>
  <key>CFBundleIdentifier</key><string>com.ma67.snowmac</string>
  <key>CFBundleExecutable</key><string>Snowmac</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
mkdir -p "$HOME/Applications"; rm -rf "$HOME/Applications/Snowmac.app"; cp -R "$APP" "$HOME/Applications/Snowmac.app"
echo "Installed: $HOME/Applications/Snowmac.app"
