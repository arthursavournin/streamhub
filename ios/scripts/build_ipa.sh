#!/bin/sh
# Fabrique ios/build/StreamHub.ipa, à installer (ou mettre à jour) sur l'iPhone avec SideStore :
# Mes apps → « + » → choisir le fichier dans Fichiers (iCloud Drive/streamhub/ios/build/).
# SideStore signe lui-même l'appli avec le compte Apple de l'utilisateur : la signature d'ici ne compte pas.
set -e
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
xcodebuild -project StreamHub.xcodeproj -scheme StreamHub -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$WORK/dd" \
  CODE_SIGNING_ALLOWED=NO build -quiet
mkdir -p "$WORK/Payload" build
cp -R "$WORK/dd/Build/Products/Release-iphoneos/StreamHub.app" "$WORK/Payload/"
rm -f build/StreamHub.ipa
(cd "$WORK" && zip -qry - Payload) > build/StreamHub.ipa
rm -rf "$WORK"
echo "build/StreamHub.ipa : $(du -h build/StreamHub.ipa | cut -f1)"
