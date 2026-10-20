#!/usr/bin/env python3
import sys
import zipfile
from pathlib import Path

app, output = map(Path, sys.argv[1:])
if not (app / 'Scorpion').is_file() or not (app / 'Info.plist').is_file():
    raise SystemExit('A real Xcode-built Scorpion.app is required')
if (app / '_CodeSignature').exists():
    raise SystemExit('Expected an unsigned application')
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_file():
            archive.write(file, 'Payload/Scorpion.app/' + file.relative_to(app).as_posix())
print(output)
