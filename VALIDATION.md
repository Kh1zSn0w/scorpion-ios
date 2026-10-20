# Validation record

## Verified build and delivery, 2026-10-20

GitHub Actions run https://github.com/Kh1zSn0w/scorpion-ios/actions/runs/39403773571 compiled the simulator and ARM64 iOS device targets with Xcode 26.6, passed 36 Swift filesystem/navigation checks, and produced an unsigned IPA that passed the package and architecture verifier. Compiled source commit: 7d1df4eea9c8731ac1e359d0b6954c19380f3fca.

The downloaded IPA was independently checked on Windows: ZIP CRC, bundle identity, version/build 1.0/1, ARM64 Mach-O executable, iOS device platform (not simulator), minimum iOS 15.0, SDK 26.5, scene lifecycle, resources and absence of provisioning/signature files. It is 871,014 bytes, SHA-256 cc381c4a6f51d3ae12205b63d635d6ad22ba2da3b81ecd7dddd0d186d979aa27.

The iPhone 17 Pro Max simulator on iOS 26.5 launched the app, remained alive after the loading wait, and produced a screenshot. Visual inspection confirmed the live site and scorpion substitution. The iPhone SE 2 simulator timed out during boot before app installation, so its runtime appearance is unverified. This environment timeout caused the overall workflow result to be failure despite successful compilation, IPA verification, artifact upload and large-iPhone launch. Do not describe the entire workflow as passing.

The actual IPA was copied to the user's Desktop as Scorpion.ipa; its checksum matched the independently verified output. It is unsigned and needs signing before installation. No physical device installation, iOS 27 run, service download/export or remux test was performed.

## Historical implementation checks

Performed on Windows on 2026-10-20:

* `python scripts/generate_project.py`: passed. Generated project and shared scheme.
* `python scripts/check_sources.py`: passed. Project/resource/plist/scene manifest/icon/source consistency only.
* `node tests/mascot.test.cjs`: 27 checks passed.
* `python -m unittest discover -s tests -p 'test_*.py'`: 6 verifier tests passed, using temporary synthetic ZIP fixtures.

Not performed: Swift compilation or standalone Swift tests, xcodebuild, simulator execution, device execution, real download/remux/export, real IPA packaging, signing or installation. This machine does not have Xcode. No installable or unsigned IPA has been produced by this implementation session.

Subsequent macOS evidence: GitHub Actions run [39403318767](https://github.com/Kh1zSn0w/scorpion-ios/actions/runs/39403318767) passed simulator and device compilation and the standalone Swift core tests. The pipeline then failed because the `lipo -verify_arch` command placed its input after the variadic architecture argument. The command now places the binary input first. That correction has not yet run on macOS. Full IPA verification/upload, simulator launch and visual correctness remain pending.

The follow-up smoke script has 5 additional local Python fixture tests, for 11 Python tests in total. Those passed on Windows. Actual simulator screenshots and process-survival evidence have not yet been collected. The script and workflow will attempt that on a subsequent approved push. Device acceptance cases are listed in README.md.
