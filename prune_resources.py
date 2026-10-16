"""Keep Notes/editor dependencies and shared UI glyphs, excluding unrelated media."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile

PACKAGES = {'RaycastWeb_RaycastWeb.bundle'}
GLYPHS = '''raycast-notes raycast-notes-create raycast-notes-save raycast-notes-search
floating-notes-export floating-notes-extension floating-notes-heading-dropdown
notes-status-item plus minus duplicate app-window-list magnifying-glass copy-clipboard
link upload arrow-up arrow-down text arrows-expand-height app-window
arrow-counter-clockwise plus-circle minus-circle video-disabled cog trash bold
italics underline strike-through code code-block quote-block number-list check-list
heading paragraph clear-formatting chevron-down chevron-up chevron-left chevron-right
chevron-down-small pin pin-disabled check check-circle xmark ellipsis blank-document
clock arrow-right arrow-left warning bullet-points keyboard undo question-mark-circle
brand-markdown checkmark x-mark-circle'''.split()


def size(path):
    if path.is_symlink():
        return 0
    if path.is_file():
        return path.stat().st_size
    return sum(f.stat().st_size for f in path.rglob('*') if f.is_file() and not f.is_symlink())


def prune(source, resources):
    source, resources = Path(source), Path(resources)
    resources.mkdir(parents=True)
    before = size(source)
    removed = []
    for path in source.iterdir():
        keep = path.name in PACKAGES or path.name in {'Assets.car', 'emoji.json'}
        if not keep:
            removed.append({'path': path.name, 'bytes': size(path)})
        elif path.name != 'Assets.car':
            if path.is_dir():
                shutil.copytree(path, resources / path.name, symlinks=True)
            else:
                shutil.copy2(path, resources / path.name)
    catalog = resources / 'Assets.car'
    original_catalog = source / 'Assets.car'
    metadata = json.loads(subprocess.check_output(['assetutil', '--info', original_catalog]))
    available = {item.get('Name') for item in metadata}
    names = sorted({name + '-16' for name in GLYPHS} | {'floating-notes-system-theme'})
    assert set(names) <= available, 'Required Notes glyph missing from source catalog'
    # This assetutil build silently truncates a preserve list around 1024 bytes.
    # Stay below that limit and verify every requested name in the resulting CAR.
    assert len(','.join(names).encode()) < 1000
    old_catalog_size = original_catalog.stat().st_size
    with tempfile.TemporaryDirectory(prefix='raynote-assets-') as folder:
        output = Path(folder) / 'Assets.car'
        subprocess.run(['assetutil', '--preserve-assets-named', ','.join(names),
                        '--output', output, original_catalog], check=True)
        shutil.copy2(output, catalog)
    retained = json.loads(subprocess.check_output(['assetutil', '--info', catalog]))
    actual_names = {item.get('Name') for item in retained}
    assert set(names) <= actual_names, 'Asset thinning lost a required glyph'
    subprocess.run(['assetutil', '--validate-file', catalog], check=True)
    return {
        'before_bytes': before,
        'after_bytes': size(resources),
        'removed_resources': removed,
        'catalog_before_bytes': old_catalog_size,
        'catalog_after_bytes': catalog.stat().st_size,
        'retained_asset_names': names,
        'retained_packages': sorted(PACKAGES),
    }
