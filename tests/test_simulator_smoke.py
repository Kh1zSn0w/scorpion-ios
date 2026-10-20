"""Unit tests use inventory fixtures and do not claim simulator execution."""
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('simulator_smoke', Path(__file__).resolve().parent.parent / 'scripts/simulator_smoke.py')
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)

class SimulatorSelectionTests(unittest.TestCase):
    def inventory(self):
        return {
            'devicetypes': [{'name': name, 'identifier': name} for name in ['iPhone SE (2nd generation)', 'iPhone SE (3rd generation)', 'iPhone 17 Pro Max']],
            'runtimes': [
                {'identifier': 'runtime.iOS-26', 'version': '26.0', 'isAvailable': True},
                {'identifier': 'runtime.iOS-27', 'version': '27.0', 'isAvailable': False},
                {'identifier': 'runtime.iOS-18', 'version': '18.0', 'isAvailable': True},
            ],
            'devices': {'runtime.iOS-26': [{'udid': 'fixture-only', 'deviceTypeIdentifier': 'iPhone 17 Pro Max', 'isAvailable': True}]},
        }

    def test_requested_model_precedes_fallback(self):
        entries = list(smoke.candidates(self.inventory(), smoke.TARGETS['small-iphone']))
        self.assertEqual(entries[0][0]['name'], 'iPhone SE (2nd generation)')
        self.assertEqual(entries[0][1]['version'], '26.0')
        self.assertFalse(any(runtime['version'] == '27.0' for _, runtime, _ in entries))

    def test_supported_device_types_respected(self):
        inventory = self.inventory()
        inventory['runtimes'][0]['supportedDeviceTypes'] = [{'identifier': 'iPhone 17 Pro Max'}]
        entries = list(smoke.candidates(inventory, smoke.TARGETS['small-iphone']))
        self.assertEqual(entries[0][1]['version'], '18.0')

    def test_existing_available_device_used(self):
        entries = list(smoke.candidates(self.inventory(), smoke.TARGETS['large-iphone']))
        self.assertEqual(entries[0][2]['udid'], 'fixture-only')

    def test_absence_is_not_fabricated(self):
        self.assertEqual(list(smoke.candidates({'runtimes': [], 'devicetypes': []}, smoke.TARGETS['small-iphone'])), [])

    def test_process_evidence_requires_live_pid_and_bundle(self):
        self.assertTrue(smoke.process_is_alive('1234 0 UIKitApplication:de.cronix.scorpion[abc]', 1234))
        self.assertFalse(smoke.process_is_alive('- 0 UIKitApplication:de.cronix.scorpion[abc]', 1234))
        self.assertFalse(smoke.process_is_alive('1234 0 another.app', 1234))

if __name__ == '__main__':
    unittest.main()
