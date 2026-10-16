"""Isolate two non-Notes frameworks while preserving all library ordinals."""
import struct

TARGET_FRAMEWORKS = {'SplineRuntime', 'SoulverCore'}
DYLIB_COMMANDS = {0xC, 0x80000018, 0x8000001F, 0x80000023}


def load_commands(data):
    offset = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, length = struct.unpack_from('<II', data, offset)
        yield offset, command, length
        offset += length


def import_table(data):
    for offset, command, _ in load_commands(data):
        if command == 0x80000034:
            fixups = struct.unpack_from('<I', data, offset + 8)[0]
            relative, _, count, fmt = struct.unpack_from('<IIII', data, fixups + 8)
            if fmt != 1:
                raise ValueError('Unsupported chained import format; expected pinned format 1')
            return fixups + relative, count
    raise ValueError('Missing chained import table')


def libraries(data):
    ordinal = 0
    for offset, command, length in load_commands(data):
        if command in DYLIB_COMMANDS:
            ordinal += 1
            relative = struct.unpack_from('<I', data, offset + 8)[0]
            name = bytes(data[offset + relative:offset + length]).split(b'\0', 1)[0].decode()
            yield ordinal, name, offset, command


def isolate_frameworks(data):
    records = []
    for ordinal, name, offset, command in libraries(data):
        if any(framework + '.framework/' in name for framework in TARGET_FRAMEWORKS):
            assert command == 0xC, 'Unexpected original framework load command'
            struct.pack_into('<I', data, offset, 0x80000018)
            records.append({'path': name, 'ordinal': ordinal, 'weak_imports': 0})
    assert len(records) == len(TARGET_FRAMEWORKS)
    by_ordinal = {item['ordinal']: item for item in records}
    start, count = import_table(data)
    for index in range(count):
        offset = start + index * 4
        raw = struct.unpack_from('<I', data, offset)[0]
        record = by_ordinal.get(raw & 255)
        if record is not None:
            struct.pack_into('<I', data, offset, raw | (1 << 8))
            record['weak_imports'] += 1
    assert all(item['weak_imports'] for item in records)
    return {'libraries': records, 'total_imports': count,
            'isolated_imports': sum(item['weak_imports'] for item in records),
            'method': 'Keep original ordinals; mark only these libraries and imports optional'}


def verify_isolation(original, extracted):
    old = list(libraries(original))
    new = list(libraries(extracted))
    assert len(old) == len(new)
    isolated = set()
    for (ordinal, name, _, command), (new_ordinal, new_name, _, new_command) in zip(old, new):
        assert (ordinal, name) == (new_ordinal, new_name), 'Library ordinals changed'
        target = any(framework + '.framework/' in name for framework in TARGET_FRAMEWORKS)
        assert new_command == (0x80000018 if target else command), name
        if target:
            isolated.add(ordinal)
    old_start, count = import_table(original)
    new_start, new_count = import_table(extracted)
    assert count == new_count
    changed = 0
    for index in range(count):
        before = struct.unpack_from('<I', original, old_start + index * 4)[0]
        after = struct.unpack_from('<I', extracted, new_start + index * 4)[0]
        expected = before | (1 << 8) if (before & 255) in isolated else before
        assert after == expected, 'Unrelated import data changed'
        changed += before != after
    return {'libraries_verified': len(isolated), 'import_records_verified': count,
            'weak_import_flags_changed': changed, 'other_imports_unchanged': True}
