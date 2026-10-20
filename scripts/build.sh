#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-device}"
python3 scripts/generate_project.py
python3 scripts/check_sources.py
python3 -m unittest discover -s tests -p 'test_*.py'
node tests/mascot.test.cjs
mkdir -p build
swiftc Scorpion/DownloadFiles.swift Scorpion/NavigationRules.swift tests/main.swift -o build/core-tests
build/core-tests
if [[ "$mode" == "simulator" ]]; then
  xcodebuild -project Scorpion.xcodeproj -scheme Scorpion -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/simulator CODE_SIGNING_ALLOWED=NO build
elif [[ "$mode" == "device" ]]; then
  xcodebuild -project Scorpion.xcodeproj -scheme Scorpion -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
  python3 scripts/package_ipa.py build/device/Build/Products/Release-iphoneos/Scorpion.app build/Scorpion-unsigned.ipa
  xcrun lipo build/device/Build/Products/Release-iphoneos/Scorpion.app/Scorpion -verify_arch arm64
  python3 scripts/verify_ipa.py build/Scorpion-unsigned.ipa
else
  echo 'Usage: bash scripts/build.sh [device|simulator]' >&2
  exit 2
fi
