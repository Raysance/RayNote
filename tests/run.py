#!/usr/bin/env python3
"""Run credential persistence and fail-closed recovery tests in temporary folders."""
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='native-notes-credential-tests-') as folder:
        folder = Path(folder)
        executable = folder / 'credential-tests'
        subprocess.run([
            'clang', '-fobjc-arc', '-DNATIVE_CREDENTIALS_TEST', '-I', str(ROOT),
            str(ROOT / 'credentials.m'), str(ROOT / 'tests/credential_tests.m'),
            '-framework', 'Foundation', '-framework', 'Security', '-o', str(executable)
        ], check=True)

        def run(root, mode):
            subprocess.run([str(executable), str(root), mode], check=True)

        normal = folder / 'normal'
        run(normal, 'write')
        results.append({'test': 'generated local key is persisted with 0600 permissions', 'passed': True})
        run(normal, 'read')
        results.append({'test': 'key is readable after a separate process restart', 'passed': True})
        run(normal, 'read-branded')
        results.append({'test': 'RayNote display rename reuses the existing key without regeneration', 'passed': True})
        corrupt = folder / 'corrupt'
        corrupt.mkdir()
        keyfile = corrupt / 'PrivateCredentials.plist'
        keyfile.write_bytes(b'deliberately corrupt test fixture')
        before = keyfile.read_bytes()
        run(corrupt, 'reject')
        assert keyfile.read_bytes() == before
        results.append({'test': 'corrupt key store is rejected without overwrite', 'passed': True})
        missing = folder / 'missing'
        database = missing / 'ApplicationSupport/local.notes.native-extracted/raycast-enc.sqlite'
        database.parent.mkdir(parents=True)
        database.write_bytes(b'existing encrypted database test fixture')
        run(missing, 'reject')
        assert not (missing / 'PrivateCredentials.plist').exists()
        results.append({'test': 'missing keys beside an existing database are rejected', 'passed': True})
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
