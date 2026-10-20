#!/usr/bin/env python3
"""Capture real simulator evidence; this is not a website functionality test."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

BUNDLE_ID = 'de.cronix.scorpion'
TARGETS = {
    'small-iphone': ['iPhone SE (2nd generation)', 'iPhone SE (3rd generation)'],
    'large-iphone': ['iPhone 17 Pro Max', 'iPhone 16 Pro Max', 'iPhone 15 Pro Max'],
}

def command(*arguments, timeout=60):
    result = subprocess.run(['xcrun', 'simctl', *arguments], text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'simctl {" ".join(arguments)} failed: {result.stdout}\n{result.stderr}')
    return result.stdout

def runtime_version(runtime):
    return tuple(int(part) for part in runtime.get('version', '0').split('.'))

def candidates(inventory, preferred_names):
    """Prefer the requested device model, then the newest usable iOS runtime."""
    types = {item['name']: item for item in inventory.get('devicetypes', [])}
    runtimes = sorted((item for item in inventory.get('runtimes', [])
                       if item.get('isAvailable') and '.iOS-' in item['identifier']),
                      key=runtime_version, reverse=True)
    for name in preferred_names:
        device_type = types.get(name)
        if not device_type:
            continue
        for runtime in runtimes:
            existing = next((device for device in inventory.get('devices', {}).get(runtime['identifier'], [])
                             if device.get('isAvailable') and device.get('deviceTypeIdentifier') == device_type['identifier']), None)
            supported = runtime.get('supportedDeviceTypes')
            if supported is not None and not any(item['identifier'] == device_type['identifier'] for item in supported):
                continue
            yield device_type, runtime, existing

def process_is_alive(output, pid):
    # launchctl's first column is PID, followed by status and the job label.
    return any(len(parts := line.split()) >= 3 and parts[0] == str(pid) and BUNDLE_ID in parts[-1]
               for line in output.splitlines())

def smoke_target(inventory, label, preferred_names, app, output, wait):
    report = {'target': label, 'requested_model': preferred_names[0], 'success': False,
              'scope': 'Launch survival and screenshot only; live website content requires visual review.'}
    booted_here = False
    udid = None
    attempts = []
    try:
        selected = None
        for device_type, runtime, existing in candidates(inventory, preferred_names):
            if existing:
                udid = existing['udid']
                selected = device_type, runtime, existing
                break
            try:
                udid = command('create', 'Scorpion smoke ' + label, device_type['identifier'], runtime['identifier']).strip()
                selected = device_type, runtime, {'udid': udid, 'state': 'Shutdown', 'created_for_smoke': True}
                break
            except (RuntimeError, subprocess.TimeoutExpired) as error:
                attempts.append(str(error))
        if selected is None:
            raise RuntimeError('No available runtime supports the requested device or listed fallback models.')
        device_type, runtime, device = selected
        report.update({'selected_model': device_type['name'], 'device_type_identifier': device_type['identifier'],
                       'runtime': runtime, 'udid': udid, 'device_before_boot': device,
                       'fallback': device_type['name'] != preferred_names[0], 'creation_attempt_errors': attempts})
        if report['fallback']:
            print(f"FALLBACK: {label} requested {preferred_names[0]}; using {device_type['name']}.", flush=True)
        else:
            print(f"Selected {device_type['name']} on {runtime['name']} ({udid}).", flush=True)
        if device.get('state') != 'Booted':
            command('boot', udid, timeout=90)
            booted_here = True
        command('bootstatus', udid, '-b', timeout=180)
        command('install', udid, str(app), timeout=90)
        launch = command('launch', '--terminate-running-process', udid, BUNDLE_ID, timeout=60)
        report['launch_output'] = launch
        match = re.search(re.escape(BUNDLE_ID) + r':\s*(\d+)', launch)
        if not match:
            raise RuntimeError('simctl did not report an application PID.')
        pid = int(match.group(1))
        report['pid'] = pid
        report['network_wait_seconds'] = wait
        time.sleep(wait)
        screenshot = output / (label + '.png')
        command('io', udid, 'screenshot', str(screenshot), timeout=60)
        report['screenshot'] = screenshot.name
        jobs = command('spawn', udid, 'launchctl', 'list', timeout=30)
        (output / (label + '-processes.txt')).write_text(jobs, encoding='utf-8')
        if not process_is_alive(jobs, pid):
            raise RuntimeError('The launched application PID is absent from simulator launchctl jobs after the loading wait.')
        report['launch_survived_wait'] = True
        report['success'] = True
        print(f"Captured {screenshot.name}; PID {pid} is still alive. Website appearance awaits visual review.", flush=True)
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        report['error'] = str(error)
        print(f'SMOKE FAILURE: {label}: {error}', flush=True)
    finally:
        if booted_here and udid:
            try:
                command('shutdown', udid, timeout=45)
            except (RuntimeError, subprocess.TimeoutExpired) as error:
                report['shutdown_error'] = str(error)
        (output / (label + '.json')).write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report['success']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=Path('build/simulator/Build/Products/Debug-iphonesimulator/Scorpion.app'))
    parser.add_argument('--output', type=Path, default=Path('build/screenshots'))
    parser.add_argument('--wait', type=int, default=15)
    args = parser.parse_args()
    if not 0 <= args.wait <= 60:
        parser.error('--wait must be between 0 and 60 seconds')
    args.output.mkdir(parents=True, exist_ok=True)
    if not (args.app / 'Scorpion').is_file():
        parser.error('The real compiled simulator Scorpion.app is missing')
    inventory = json.loads(command('list', '-j', timeout=60))
    (args.output / 'simctl-inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
    results = [smoke_target(inventory, label, names, args.app.resolve(), args.output.resolve(), args.wait)
               for label, names in TARGETS.items()]
    raise SystemExit(0 if all(results) else 1)

if __name__ == '__main__':
    main()
