#!/usr/bin/env python3
"""Portable consistency checks. These do not compile or type-check Swift."""
import json
import plistlib
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parent.parent
plist = plistlib.loads((root / 'Scorpion/Info.plist').read_bytes())
assert plist['CFBundleDisplayName'] == 'Scorpion'
assert plist['CFBundleIdentifier'] == '$(PRODUCT_BUNDLE_IDENTIFIER)'
assert 'NSAppTransportSecurity' not in plist, 'No broad transport-security bypass'
scene = plist['UIApplicationSceneManifest']['UISceneConfigurations']['UIWindowSceneSessionRoleApplication'][0]
assert scene['UISceneDelegateClassName'] == '$(PRODUCT_MODULE_NAME).SceneDelegate'
assert 'UIWindow(windowScene: scene)' in (root / 'Scorpion/SceneDelegate.swift').read_text()
project = (root / 'Scorpion.xcodeproj/project.pbxproj').read_text()
for source in (root / 'Scorpion').glob('*.swift'):
    assert source.relative_to(root).as_posix() in project, f'Missing {source}'
for resource in ('Mascot.js', 'scorpion.png', 'Assets.xcassets'):
    assert 'Scorpion/' + resource in project
ET.parse(root / 'Scorpion.xcodeproj/xcshareddata/xcschemes/Scorpion.xcscheme')
icons = root / 'Scorpion/Assets.xcassets/AppIcon.appiconset'
catalog = json.loads((icons / 'Contents.json').read_text())
for entry in catalog['images']:
    data = (icons / entry['filename']).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', data[16:24]) == (1024, 1024)
browser = (root / 'Scorpion/BrowserViewController.swift').read_text()
assert '.default()' in browser and 'safeAreaLayoutGuide' in browser
assert browser.count('didBecome download: WKDownload') == 2
assert 'response.canShowMIMEType' in browser and 'Content-Disposition' in browser
assert '.moveItem(at: partial, to: destination)' in browser
assert 'UIActivityViewController' in (root / 'Scorpion/FilesViewController.swift').read_text()
assert 'URLSession' not in browser and 'evaluateJavaScript' not in browser
assert 'CODE_SIGNING_ALLOWED=NO' in (root / 'scripts/build.sh').read_text()
print('Passed project, resource, plist, icon and source consistency checks (not a Swift compile)')
