# Scorpion

An original UIKit shell for the live https://cobalt.meowing.de/ website. The service remains remote, including its navigation, settings, backend requests and processing. Only mascot image elements are changed locally to the supplied scorpion. Site attribution and article text stay on the website.

Requires iOS 15 or later. Bundle ID `de.cronix.scorpion`, version 1.0, build 1. Designed with safe areas for the iPhone SE 2 and larger iPhones. iOS 26 and iOS 27 operation has not been verified.

## Build on macOS

Use Xcode with an iOS SDK, its command-line tools, Python 3 and Node.js. No Homebrew packages or third-party iOS libraries are required.

```sh
bash scripts/build.sh simulator
bash scripts/build.sh device
```

The device build creates `build/Scorpion-unsigned.ipa` only after Xcode compiles the app. Packaging verifies the expected Payload folder, identity, bundled resources, absence of signing artifacts and thin ARM64 Mach-O header. `lipo` additionally checks ARM64. This unsigned IPA needs separate signing and installation tooling before an iPhone can run it.

The checked-in project is generated with `python3 scripts/generate_project.py`, using only the Python standard library. Open `Scorpion.xcodeproj` to run with your own signing team on a real iPhone. The GitHub workflow uses macos-26, prints the actual Xcode/SDK versions, builds simulator and device targets and uploads the unsigned IPA. Nothing is uploaded until a user publishes this repository and runs CI.

After simulator compilation, CI runs `python3 scripts/simulator_smoke.py`. It selects actual available simulator inventory, prefers iPhone SE 2 (explicitly labeling an SE 3 fallback) and iPhone 17 Pro Max (explicitly labeling an older Pro Max fallback). Each target installs the real compiled app, launches it, waits 15 seconds for network loading, captures a screenshot and checks that its process remains alive. Screenshots, runtime/device metadata and process evidence are uploaded even if a target fails. Missing suitable simulators fail the smoke step. These screenshots require visual review and do not prove downloads, service behavior or physical-device compatibility.

## Downloads and sharing

Downloads use WKDownload for explicit download actions, attachment responses, non-displayable responses and external media responses. HTTP(S) pages are inspected before external pages open in Safari's in-app browser. New-window actions stay in the current web view until response routing decides their destination. Custom schemes and local URLs are blocked. No TLS exceptions or native file-byte bridge are installed.

Active downloads are retained separately from navigation. Each writes to a unique cache directory. A file moves into Documents/Downloads only on successful completion. Failed files are removed and failures are shown. Finished files appear under the folder button and can be exported with the native share sheet. Downloads are not promised to keep running in the background; interrupted cache files are removed on the next launch.

The same-origin script preserves an existing `navigator.share`. If absent, sharing 1 to 16 actual File objects starts local blob-anchor downloads. Blob URLs are retained for ten minutes. The fallback deliberately rejects with an explicit message directing the user to Downloads, because starting a download is not proof of a completed share. URL-only sharing reports unsupported with Safari/copy instructions. The fallback does not implement `navigator.canShare` or transfer file bytes into native messages. Native blob handling still requires actual WKWebView validation.

## Validation status

Windows can run:

```sh
python scripts/generate_project.py
python scripts/check_sources.py
python -m unittest discover -s tests -p 'test_*.py'
node tests/mascot.test.cjs
```

The standalone Swift tests run as part of both macOS build commands. They exercise traversal, control characters, UTF-8 filename length, real duplicate files, original preservation, origin/response routing and blocked URL schemes. JavaScript tests exercise dynamic insertion, changed sources, observer termination, foreign documents/images, native-share preservation, fallback blobs and malformed input. Python verifier tests use temporary synthetic fixtures to test rejection of bad package structures, signatures, identities and architectures. Those fixtures are not builds. Source consistency checks are not a Swift compiler.

The initial implementation session ran on Windows. A subsequent macOS [Actions run](https://github.com/Kh1zSn0w/scorpion-ios/actions/runs/39403318767) passed simulator/device compilation and standalone Swift core tests, then failed on a `lipo` argument-order error corrected in this follow-up. Full IPA verification, runtime launch and screenshots have not yet been verified in this record; see VALIDATION.md. Service-specific save flows, upload/remux, website settings, HTTP authentication, redirects, cookies, persistent login, media playback and browser APIs require device validation. The remote site can change independently.

## Device acceptance checklist

1. On iPhone SE 2 and iPhone 17 Pro Max, verify safe areas in portrait and landscape, back/forward state, settings retention after relaunch and live site navigation.
2. Verify original mascot substitution after SPA route changes and source changes. Confirm article photos and foreign pages are unchanged.
3. Save real small and large files from supported services. Exercise HTTP attachment, external displayable media, blob downloads, duplicate names and fallback Web Share. Confirm file content and export in Files.
4. Interrupt network access during initial load and during a download. Verify Retry works, failures are visible and partial files never enter the completed list. Relaunch during a download to inspect cleanup.
5. Exercise target=_blank for site pages, external HTML and download URLs, JavaScript alert/confirm/prompt and blocked file/custom-scheme links.
6. Test remux with realistic inputs, memory pressure and screen locking. Record actual iOS versions, service URLs, file sizes and results. Test iOS 27 separately when a usable SDK/device exists.
