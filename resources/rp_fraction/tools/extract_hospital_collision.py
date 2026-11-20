"""Extract only the hospital COL from the supplied archive; leave other map models alone."""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def extract(data, name='laehospital1'):
    offset = 0
    found = []
    while offset < len(data):
        if offset + 32 > len(data):
            raise ValueError('Truncated COL header')
        magic = data[offset:offset + 4]
        size = struct.unpack_from('<I', data, offset + 4)[0]
        end = offset + size + 8
        if magic not in (b'COLL', b'COL2', b'COL3', b'COL4') or size < 24 or end > len(data):
            raise ValueError('Invalid COL entry')
        model = data[offset + 8:offset + 30].split(b'\0')[0].decode('ascii')
        if model.lower() == name.lower():
            found.append(data[offset:end])
        offset = end
    if len(found) != 1:
        raise ValueError('Expected exactly one hospital collision model')
    return found[0]


if __name__ == '__main__':
    source = ROOT / 'interior/lae_5.col'
    output = ROOT / 'interior/laehospital1.col'
    output.write_bytes(extract(source.read_bytes()))
    print(f'Extracted {output.name}: {output.stat().st_size} bytes')
