#!/usr/bin/env python3
"""Verify original machine-code provenance and the copied Notes editor assets."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import subprocess

ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def text_section(data):
    count = struct.unpack_from('<I', data, 16)[0]
    offset = 32
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, offset)
        if command == 0x19:
            sections = struct.unpack_from('<I', data, offset + 64)[0]
            for index in range(sections):
                position = offset + 72 + index * 80
                name = data[position:position + 16].rstrip(b'\0')
                segment = data[position + 16:position + 32].rstrip(b'\0')
                if name == b'__text' and segment == b'__TEXT':
                    address, length, file_offset = struct.unpack_from('<QQI', data, position + 32)
                    return address, length, file_offset
        offset += size
    raise ValueError('Missing __TEXT,__text')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('/Applications/Raycast.app'))
    parser.add_argument('--app', type=Path, default=ROOT / 'dist' / 'RayNote.app')
    args = parser.parse_args()
    original = (args.source / 'Contents/MacOS/Raycast').read_bytes()
    core = (args.app / 'Contents/MacOS/NotesCore').read_bytes()
    manifest = json.loads((args.app / 'Contents/Resources/ExtractionManifest.json').read_text())
    assert sha(original) == manifest['source_sha256'], 'Original hash mismatch'
    assert sha(core) == manifest['module_sha256'], 'Extracted module hash mismatch'
    address, length, position = text_section(original)
    assert text_section(core) == (address, length, position)
    restored = bytearray(core[position:position + length])
    for patch in manifest['notes_patches']:
        relative = int(patch['address'], 16) - address
        before, after = bytes.fromhex(patch['before']), bytes.fromhex(patch['after'])
        assert 0 <= relative < length
        assert restored[relative:relative + len(after)] == after
        restored[relative:relative + len(before)] = before
    assert restored == original[position:position + length], 'Unexpected native code changes'
    resources = args.app / 'Contents/Resources'
    resource_manifest = json.loads((resources / 'ResourceManifest.json').read_text())
    for removed in resource_manifest['removed_resources']:
        assert not (resources / removed['path']).exists(), removed['path']
    assert (resources / 'Assets.car').stat().st_size == resource_manifest['catalog_after_bytes']
    catalog = json.loads(subprocess.check_output(['assetutil', '--info', resources / 'Assets.car']))
    expected_names = set(resource_manifest['retained_asset_names'])
    assert expected_names <= {entry.get('Name') for entry in catalog}
    original_catalog = json.loads(subprocess.check_output([
        'assetutil', '--info', args.source / 'Contents/Resources/Assets.car']))
    def glyph_records(entries):
        return {(entry['Name'], entry.get('RenditionName'), entry.get('Scale'), entry.get('SHA1Digest'))
                for entry in entries if entry.get('Name') in expected_names}
    assert glyph_records(original_catalog) == glyph_records(catalog), 'Retained glyph data changed'
    info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleName'] == info['CFBundleDisplayName'] == info['CFBundleExecutable'] == 'RayNote'
    assert (resources / 'RayNote.icns').is_file()
    resource = Path('Contents/Resources/RaycastWeb_RaycastWeb.bundle/Contents/Resources')
    assets = []
    for file in sorted((args.source / resource).rglob('*')):
        if file.is_file():
            relative = file.relative_to(args.source / resource)
            original_asset = file.read_bytes()
            assert original_asset == (args.app / resource / relative).read_bytes(), str(relative)
            assets.append({'path': str(relative), 'sha256': sha(original_asset)})
    subprocess.run(['codesign', '--verify', '--deep', '--strict', args.app], check=True)
    print(json.dumps({
        'passed': True,
        'original_sha256': sha(original),
        'module_sha256': sha(core),
        'native_text_bytes_verified': length,
        'documented_patches': len(manifest['notes_patches']),
        'native_text_matches_original_except_documented_patches': True,
        'original_editor_assets': assets,
        'ad_hoc_signature_verified': True,
        'display_name': info['CFBundleDisplayName'],
        'retained_glyphs_verified': len(expected_names),
        'retained_glyph_hashes_match_original': True,
        'catalog_bytes_before': resource_manifest['catalog_before_bytes'],
        'catalog_bytes_after': resource_manifest['catalog_after_bytes'],
        'removed_resource_entries_verified': len(resource_manifest['removed_resources']),
    }, indent=2))


if __name__ == '__main__':
    main()
