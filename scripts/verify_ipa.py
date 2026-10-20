#!/usr/bin/env python3
import plistlib
import struct
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, 'Corrupt ZIP'
    names = archive.namelist()
    assert all(name.startswith('Payload/Scorpion.app/') and '..' not in name.split('/') for name in names), 'Unexpected IPA structure'
    prefix = 'Payload/Scorpion.app/'
    info = plistlib.loads(archive.read(prefix + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'de.cronix.scorpion'
    assert info['CFBundleShortVersionString'] == '1.0'
    assert info['CFBundleVersion'] == '1'
    assert not any('/_CodeSignature/' in name or name.endswith('embedded.mobileprovision') for name in names), 'Not unsigned'
    executable = archive.read(prefix + info['CFBundleExecutable'])
    # Device build explicitly requests a thin ARM64 binary.
    magic, cpu = struct.unpack('<II', executable[:8])
    assert magic == 0xFEEDFACF and cpu == 0x0100000C, 'Expected thin ARM64 Mach-O'
    assert prefix + 'scorpion.png' in names and prefix + 'Mascot.js' in names
print('IPA structure, identity, unsigned status and ARM64 header verified')
