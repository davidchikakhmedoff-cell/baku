"""Prepare ELS material masks; original uploads remain untouched. Requires Pillow."""
from pathlib import Path
from io import BytesIO
import hashlib
import struct
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
CONTAINERS = {3, 6, 7, 8, 14, 15, 16, 20, 26}
MODELS = {596: ('ford_explorer', 'copcarla'), 597: ('ford_taurus', 'copcarsf'), 598: ('dodge_charger', 'copcarvg')}


def chunks(data):
    offset = 0
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError('Truncated RenderWare header')
        kind, size, version = struct.unpack_from('<III', data, offset)
        end = offset + 12 + size
        if end > len(data):
            raise ValueError('Truncated RenderWare chunk')
        yield kind, version, data[offset + 12:end]
        offset = end


def chunk(kind, version, data):
    return struct.pack('<III', kind, len(data), version) + data


def rw_string(value):
    value = value.encode('ascii') + b'\0'
    return value + b'\0' * (-len(value) % 4)


def texture_image(native):
    fields = list(chunks(native))
    raw = fields[0][2]
    platform = struct.unpack_from('<I', raw)[0]
    raster, fmt, width, height, depth, levels, kind, flags = struct.unpack_from('<IIHHBBBB', raw, 72)
    assert platform == 9, 'Expected GTA SA D3D9 texture'
    size = struct.unpack_from('<I', raw, 88)[0]
    pixels = raw[92:92 + size]
    if fmt in (21, 22) and depth == 32:
        image = Image.frombytes('RGBA', (width, height), pixels, 'raw', 'BGRA')
        if fmt == 22:
            image.putalpha(255)
        return image
    if fmt in (0x31545844, 0x33545844, 0x35545844):
        header = [124, 0x81007, height, width, size, 0, 1] + [0] * 11
        header += [32, 4, fmt, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0]
        return Image.open(BytesIO(b'DDS ' + struct.pack('<31I', *header) + pixels)).convert('RGBA')
    raise ValueError(f'Unsupported lamp raster: {fmt:x}, {depth} bits')


def mask_native(name, lamp_id, image, version):
    red, green, blue, alpha = image.split()
    intensity = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    # ID is stored in a sampled texture channel, independent of GTA vehicle lighting.
    encoded = Image.merge('RGBA', (Image.new('L', image.size, lamp_id), intensity, Image.new('L', image.size, 255), alpha))
    pixels = encoded.tobytes('raw', 'BGRA')
    raw = struct.pack('<II', 9, 0x1102) + name.encode().ljust(32, b'\0') + b'\0' * 32
    raw += struct.pack('<IIHHBBBBI', 0x500, 21, image.width, image.height, 32, 1, 4, 1, len(pixels)) + pixels
    return chunk(0x15, version, chunk(1, version, raw) + chunk(3, version, b''))


def prepare(model, folder, basename):
    source = ROOT / 'cars' / folder
    txd_chunks = list(chunks((source / (basename + '.txd')).read_bytes()))
    assert txd_chunks[0][0] == 22
    _, version, dictionary = txd_chunks[0]
    entries = list(chunks(dictionary))
    natives = {}
    for kind, ver, payload in entries:
        if kind == 0x15:
            raw = next(chunks(payload))[2]
            name = raw[8:40].split(b'\0')[0].decode('latin1').lower()
            natives[name] = payload
    aliases, images = {}, {}

    def patch(data):
        output = []
        for kind, ver, payload in chunks(data):
            if kind == 7:
                children = list(chunks(payload))
                index = next(i for i, c in enumerate(children) if c[0] == 1)
                raw = bytearray(children[index][2])
                lamp_id, g, b, a = raw[4:8]
                if 1 <= lamp_id <= 63 and g == 255 and b == 255:
                    texture_index = next((i for i, c in enumerate(children) if c[0] == 6), None)
                    if texture_index is None:
                        raise ValueError(f'{folder}: lamp {lamp_id} has no texture')
                    texture = list(chunks(children[texture_index][2]))
                    name_index = next(i for i, c in enumerate(texture) if c[0] == 2)
                    original = texture[name_index][2].split(b'\0')[0].decode('latin1').lower()
                    key = (lamp_id, original)
                    alias = f'rp_pd_els_{model}_{lamp_id}_{hashlib.sha1(original.encode()).hexdigest()[:5]}'
                    if key not in aliases:
                        if original not in images:
                            resolved = original
                            if resolved not in natives and resolved.endswith('.png'):
                                resolved = resolved[:-4]
                            if resolved not in natives and resolved == 'sirenlight128':
                                resolved = 'sirenlights128'
                            if resolved not in natives:
                                raise ValueError(f'{folder}: missing lamp texture {original}')
                            images[original] = texture_image(natives[resolved])
                        aliases[key] = mask_native(alias, lamp_id, images[original], version)
                    texture[name_index] = (2, ver, rw_string(alias))
                    children[texture_index] = (6, ver, b''.join(chunk(*c) for c in texture))
                    raw[4:8] = bytes((255, 255, 255, 255))
                    children[index] = (1, ver, bytes(raw))
                    payload = b''.join(chunk(*c) for c in children)
            elif kind in CONTAINERS:
                payload = patch(payload)
            output.append(chunk(kind, ver, payload))
        return b''.join(output)

    dff = patch((source / (basename + '.dff')).read_bytes())
    updated = []
    inserted = False
    for kind, ver, payload in entries:
        if kind == 1:
            raw = bytearray(payload)
            count = sum(1 for c in entries if c[0] == 0x15) + len(aliases)
            struct.pack_into('<H', raw, 0, count)
            payload = bytes(raw)
        if kind == 3 and not inserted:
            updated.extend(aliases.values())
            inserted = True
        updated.append(chunk(kind, ver, payload))
    if not inserted:
        updated.extend(aliases.values())
    txd = chunk(22, version, b''.join(updated))
    output = ROOT / 'cars' / 'prepared'
    output.mkdir(exist_ok=True)
    (output / f'{model}.dff').write_bytes(dff)
    (output / f'{model}.txd').write_bytes(txd)
    print(f'{model}: {len(aliases)} lamp masks, DFF {len(dff)}, TXD {len(txd)} bytes')


if __name__ == '__main__':
    for model, (folder, basename) in MODELS.items():
        prepare(model, folder, basename)
