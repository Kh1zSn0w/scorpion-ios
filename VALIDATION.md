# Validation record

Performed on Windows on 2026-10-20:

* `python scripts/generate_project.py`: passed. Generated project and shared scheme.
* `python scripts/check_sources.py`: passed. Project/resource/plist/scene manifest/icon/source consistency only.
* `node tests/mascot.test.cjs`: 27 checks passed.
* `python -m unittest discover -s tests -p 'test_*.py'`: 6 verifier tests passed, using temporary synthetic ZIP fixtures.

Not performed: Swift compilation or standalone Swift tests, xcodebuild, simulator execution, device execution, real download/remux/export, real IPA packaging, signing or installation. This machine does not have Xcode. No installable or unsigned IPA has been produced by this implementation session.

Subsequent macOS evidence: GitHub Actions run [39403318767](https://github.com/Kh1zSn0w/scorpion-ios/actions/runs/39403318767) passed simulator and device compilation and the standalone Swift core tests. The pipeline then failed because the `lipo -verify_arch` command placed its input after the variadic architecture argument. The command now places the binary input first. That correction has not yet run on macOS. Full IPA verification/upload, simulator launch and visual correctness remain pending.

The follow-up smoke script has 5 additional local Python fixture tests, for 11 Python tests in total. Those passed on Windows. Actual simulator screenshots and process-survival evidence have not yet been collected. The script and workflow will attempt that on a subsequent approved push. Device acceptance cases are listed in README.md.
