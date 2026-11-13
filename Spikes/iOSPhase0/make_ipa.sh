#!/bin/bash
# Builds an unsigned SwingSpike.ipa for SideStore, which re-signs it with your Apple ID.
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate
xcodebuild -project SwingSpike.xcodeproj -scheme SwingSpike -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
rm -rf Payload SwingSpike.ipa
mkdir Payload
cp -R build/Build/Products/Release-iphoneos/SwingSpike.app Payload/
zip -qr SwingSpike.ipa Payload
rm -rf Payload
echo "Built $(pwd)/SwingSpike.ipa — AirDrop it to the phone and open it in SideStore."
