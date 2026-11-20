"""Check uploaded hospital assets and actual indoor marker positions against both meshes."""
from pathlib import Path
import importlib.util
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('extract_hospital_collision', ROOT / 'tools/extract_hospital_collision.py')
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)


def chunks(data):
    offset = 0
    while offset + 12 <= len(data):
        kind, size, version = struct.unpack_from('<III', data, offset)
        end = offset + 12 + size
        if end > len(data):
            raise ValueError('Truncated RenderWare chunk')
        yield kind, data[offset + 12:end]
        offset = end


def collision_triangles(data):
    count = struct.unpack_from('<I', data, 76)[0]
    vertex_offset = struct.unpack_from('<I', data, 96)[0] + 4
    face_offset = struct.unpack_from('<I', data, 100)[0] + 4
    faces = list(struct.iter_unpack('<HHHBB', data[face_offset:face_offset + count * 8]))
    count_vertices = max(max(face[:3]) for face in faces) + 1
    vertices = [tuple(c / 128 for c in v) for v in struct.iter_unpack('<hhh', data[vertex_offset:vertex_offset + count_vertices * 6])]
    return [tuple(vertices[i] for i in face[:3]) for face in faces]


def visual_triangles(data):
    clump = next(chunks(data))[1]
    geometry_list = next(p for k, p in chunks(clump) if k == 26)
    geometry = next(p for k, p in chunks(geometry_list) if k == 15)
    raw = next(chunks(geometry))[1]
    flags, uvs, native, nt, nv, nm = struct.unpack_from('<HBBIII', raw)
    assert native == 0 and nm == 1
    uv_count = uvs or (1 if flags & 4 else 0)
    offset = 16 + (nv * 4 if flags & 8 else 0) + nv * 8 * uv_count
    faces = list(struct.iter_unpack('<HHHH', raw[offset:offset + nt * 8]))
    offset += nt * 8 + 24
    vertices = list(struct.iter_unpack('<fff', raw[offset:offset + nv * 12]))
    return [tuple(vertices[i] for i in (face[1], face[0], face[3])) for face in faces]


def ray_heights(triangles, x, y):
    for a, b, c in triangles:
        ux, uy = b[0] - a[0], b[1] - a[1]
        vx, vy = c[0] - a[0], c[1] - a[1]
        px, py = x - a[0], y - a[1]
        det = ux * vy - vx * uy
        if abs(det) < 1e-8:
            continue
        u, v = (px * vy - vx * py) / det, (ux * py - px * uy) / det
        if u >= -1e-6 and v >= -1e-6 and u + v <= 1.000001:
            yield a[2] + u * (b[2] - a[2]) + v * (c[2] - a[2])


class HospitalAssets(unittest.TestCase):
    def test_extract_only_hospital(self):
        archive = (ROOT / 'interior/lae_5.col').read_bytes()
        result = extractor.extract(archive)
        self.assertEqual(result, (ROOT / 'interior/laehospital1.col').read_bytes())
        self.assertEqual(len(result), 301100)
        self.assertEqual(result[:4], b'COL3')
        self.assertEqual(result[8:30].split(b'\0')[0], b'laehospital1')
        self.assertLess(len(result), len(archive))

    def test_invalid_archives_rejected(self):
        data = (ROOT / 'interior/laehospital1.col').read_bytes()
        for bad in (data[:-1], data + data, data[:80], b'bad'):
            with self.assertRaises(ValueError):
                extractor.extract(bad)

    def test_all_model_textures_exist(self):
        dictionary = next(chunks((ROOT / 'interior/hospital_lae.txd').read_bytes()))[1]
        textures = set()
        for kind, payload in chunks(dictionary):
            if kind == 0x15:
                raw = next(chunks(payload))[1]
                textures.add(raw[8:40].split(b'\0')[0].decode('latin1').lower())
        referenced = set()

        def visit(data):
            for kind, payload in chunks(data):
                if kind == 6:
                    names = [raw for k, raw in chunks(payload) if k == 2]
                    if names:
                        referenced.add(names[0].split(b'\0')[0].decode('latin1').lower())
                elif kind in {3, 7, 8, 14, 15, 16, 20, 26}:
                    visit(payload)

        visit((ROOT / 'interior/laehospital1.dff').read_bytes())
        self.assertEqual(len(referenced), 13)
        self.assertFalse(referenced - textures, 'model references missing textures')

    def test_exit_barrier_assets_match_generator(self):
        spec = importlib.util.spec_from_file_location('build_barrier', ROOT / 'tools/build_hospital_exit_barrier.py')
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        dff, col = builder.build()
        self.assertEqual(dff, (ROOT / 'interior/exit_barrier.dff').read_bytes())
        self.assertEqual(col, (ROOT / 'interior/exit_barrier.col').read_bytes())
        self.assertEqual(struct.unpack_from('<HHI', col, 72), (0, 1, 0))
        self.assertEqual(struct.unpack_from('<I', col, 88)[0] + 4, 120)
        box = struct.unpack_from('<6f', col, 120)
        self.assertAlmostEqual(box[3] - box[0], 6.4, places=5)
        self.assertAlmostEqual(box[4] - box[1], 0.4, places=5)
        self.assertAlmostEqual(box[5] - box[2], 4.2, places=5)
        vertices = [v for face in visual_triangles(dff) for v in face]
        for axis in range(3):
            self.assertAlmostEqual(min(v[axis] for v in vertices), box[axis], places=5)
            self.assertAlmostEqual(max(v[axis] for v in vertices), box[axis + 3], places=5)

    def test_exit_barrier_blocks_opening_but_keeps_marker_accessible(self):
        config = (ROOT / 'interior/config.lua').read_text()
        origin = tuple(map(float, re.search(r'origin=\{x=([\d.-]+),y=([\d.-]+),z=([\d.-]+)', config).groups()))
        offset = tuple(map(float, re.search(r'offset=\{x=([\d.-]+),y=([\d.-]+),z=([\d.-]+)', config).groups()))
        box = struct.unpack_from('<6f', (ROOT / 'interior/exit_barrier.col').read_bytes(), 120)
        lower = [box[i] + offset[i] for i in range(3)]
        upper = [box[i+3] + offset[i] for i in range(3)]
        self.assertLess(lower[0], -23.5)
        self.assertGreater(upper[0], -18.0)
        self.assertGreater(lower[1], 0)
        self.assertLess(upper[1], 3)
        self.assertLess(lower[2], -17.5)
        self.assertGreater(upper[2], -13.45)
        location = (ROOT / 'fleet_config.lua').read_text().split('    -- Los Santos Hospital\n', 1)[1].split('    -- Los Santos Police Department\n', 1)[0]
        marker = tuple(map(float, re.search(r'exit=\{x=([\d.-]+),y=([\d.-]+),z=([\d.-]+)', location).groups()))
        self.assertGreater(marker[1] - origin[1] - upper[1], 0.75, 'exit marker remains on lobby side with walking space')

    def test_spawn_and_interactions_have_visible_matching_floor(self):
        collision = collision_triangles((ROOT / 'interior/laehospital1.col').read_bytes())
        visual = visual_triangles((ROOT / 'interior/laehospital1.dff').read_bytes())
        text = (ROOT / 'fleet_config.lua').read_text().split('    -- Los Santos Hospital\n', 1)[1].split('    -- Los Santos Police Department\n', 1)[0]
        coords = re.findall(r'(inside|exit|keysPoint|dutyPoint|returnSpawn)=\{x=([\d.-]+),y=([\d.-]+),z=([\d.-]+)', text)
        self.assertEqual(len(coords), 6)  # spawn, exit, keys, shift, roof inside, roof return
        config = (ROOT / 'interior/config.lua').read_text()
        origin = tuple(map(float, re.search(r'origin=\{x=([\d.-]+),y=([\d.-]+),z=([\d.-]+)', config).groups()))
        for name, xx, yy, zz in coords:
            # Exterior roof points do not occur in this field subset.
            x, y, z = float(xx) - origin[0], float(yy) - origin[1], float(zz) - origin[2]
            floors = list(ray_heights(collision, x, y))
            below = max(h for h in floors if h < z)
            ceiling = min(h for h in floors if h > z)
            self.assertGreater(z - below, 0.75 if name in ('inside', 'returnSpawn') else 0.3, name)
            self.assertLess(z - below, 1.2, name)
            self.assertGreater(ceiling - z, 2.3, name)
            visual_floor = max(h for h in ray_heights(visual, x, y) if h < z)
            self.assertAlmostEqual(below, visual_floor, delta=0.04, msg=name)


if __name__ == '__main__':
    unittest.main()
