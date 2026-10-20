# Validation record

Performed on Windows on 2026-10-20:

* `python scripts/generate_project.py`: passed. Generated project and shared scheme.
* `python scripts/check_sources.py`: passed. Project/resource/plist/scene manifest/icon/source consistency only.
* `node tests/mascot.test.cjs`: 27 checks passed.
* `python -m unittest discover -s tests -p 'test_*.py'`: 6 verifier tests passed, using temporary synthetic ZIP fixtures.

Not performed: Swift compilation or standalone Swift tests, xcodebuild, simulator execution, device execution, real download/remux/export, real IPA packaging, signing or installation. This machine does not have Xcode. No installable or unsigned IPA has been produced by this implementation session.

The macOS workflow is prepared to compile both simulator and device, run the Swift fixtures, package the actual built app and verify the unsigned ARM64 IPA. That workflow has not run yet. Device acceptance cases are listed in README.md.
