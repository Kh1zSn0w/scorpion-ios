"""Exercise verifier rejection paths with temporary synthetic fixtures, not builds."""
import plistlib
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

class VerifierTests(unittest.TestCase):
    def verify(self, mutation=None):
        prefix = 'Payload/Scorpion.app/'
        files = {
            prefix + 'Info.plist': plistlib.dumps({'CFBundleIdentifier': 'de.cronix.scorpion', 'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '1', 'CFBundleExecutable': 'Scorpion'}),
            prefix + 'Scorpion': struct.pack('<II', 0xFEEDFACF, 0x0100000C),
            prefix + 'scorpion.png': b'fixture',
            prefix + 'Mascot.js': b'fixture',
        }
        if mutation:
            mutation(files, prefix)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'synthetic-fixture.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                for name, data in files.items():
                    archive.writestr(name, data)
            return subprocess.run([sys.executable, str(ROOT / 'scripts/verify_ipa.py'), str(path)], capture_output=True).returncode

    def test_expected_structure(self):
        self.assertEqual(self.verify(), 0)

    def test_missing_mascot(self):
        self.assertNotEqual(self.verify(lambda files, prefix: files.pop(prefix + 'scorpion.png')), 0)

    def test_wrong_architecture(self):
        self.assertNotEqual(self.verify(lambda files, prefix: files.update({prefix + 'Scorpion': struct.pack('<II', 0xFEEDFACF, 0x01000007)})), 0)

    def test_signature_rejected(self):
        self.assertNotEqual(self.verify(lambda files, prefix: files.update({prefix + '_CodeSignature/CodeResources': b'fixture'})), 0)

    def test_traversal_rejected(self):
        self.assertNotEqual(self.verify(lambda files, prefix: files.update({prefix + '../escape': b'fixture'})), 0)

    def test_wrong_identity(self):
        self.assertNotEqual(self.verify(lambda files, prefix: files.update({prefix + 'Info.plist': plistlib.dumps({'CFBundleIdentifier': 'wrong'})})), 0)

if __name__ == '__main__':
    unittest.main()
