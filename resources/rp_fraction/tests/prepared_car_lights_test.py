"""Verify prepared assets against the real uploaded DFF/TXD, not mock models."""
from pathlib import Path
import importlib.util
import struct
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare_lights', ROOT / 'tools/prepare_car_lights.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def materials_and_geometry(data):
    materials, geometry = [], []

    def walk(data, parent=0):
        for kind, version, raw in builder.chunks(data):
            if kind == 1 and parent in (14, 15, 20):
                geometry.append(raw)
            if kind == 7:
                children = list(builder.chunks(raw))
                body = next(c[2] for c in children if c[0] == 1)
                tex = next((c[2] for c in children if c[0] == 6), None)
                name = next((c[2].split(b'\0')[0].decode('latin1') for c in builder.chunks(tex) if c[0] == 2), '') if tex else ''
                materials.append((body, name))
            if kind in builder.CONTAINERS:
                walk(raw, kind)
    walk(data)
    return materials, geometry


class PreparedLights(unittest.TestCase):
    def check_model(self, model):
        folder, basename = builder.MODELS[model]
        original = (ROOT / 'cars' / folder / (basename + '.dff')).read_bytes()
        prepared = (ROOT / 'cars/prepared' / (str(model) + '.dff')).read_bytes()
        before, original_geometry = materials_and_geometry(original)
        after, prepared_geometry = materials_and_geometry(prepared)
        self.assertEqual(original_geometry, prepared_geometry, 'vertex/triangle/frame/atomic data must remain unchanged')
        self.assertEqual(len(before), len(after))
        dictionary = next(builder.chunks((ROOT / 'cars/prepared' / (str(model) + '.txd')).read_bytes()))[2]
        textures = {}
        declared_count = None
        for kind, version, raw in builder.chunks(dictionary):
            if kind == 1:
                declared_count = struct.unpack_from('<H', raw)[0]
            if kind == 0x15:
                body = next(builder.chunks(raw))[2]
                name = body[8:40].split(b'\0')[0].decode('latin1')
                textures[name] = raw
        self.assertEqual(declared_count, sum(1 for c in builder.chunks(dictionary) if c[0] == 0x15))
        lamps = 0
        for (old, old_name), (new, new_name) in zip(before, after):
            lamp, green, blue, alpha = old[4:8]
            if 1 <= lamp <= 63 and green == blue == 255:
                lamps += 1
                self.assertEqual(new[4:8], bytes((255, 255, 255, 255)), 'cyan ID material must be neutralized')
                self.assertEqual(old[:4] + old[8:], new[:4] + new[8:], 'only material color may change')
                self.assertTrue(new_name.startswith(f'rp_pd_els_{model}_{lamp}_'))
                self.assertIn(new_name, textures, 'every lamp reference must resolve, including broken .png/typo inputs')
                image = builder.texture_image(textures[new_name])
                self.assertEqual(image.getchannel('R').getextrema(), (lamp, lamp), 'sampled lamp ID is independent of GTA lighting')
                self.assertEqual(image.getchannel('B').getextrema(), (255, 255))
                self.assertGreater(image.getchannel('G').getextrema()[1], 0, 'light texture must contain a visible intensity mask')
                self.assertGreater(image.getchannel('A').getextrema()[1], 0)
            else:
                self.assertEqual((old, old_name), (new, new_name), 'normal headlights, body and windows must stay untouched')
        self.assertGreater(lamps, 20)

    def test_explorer(self): self.check_model(596)
    def test_taurus(self): self.check_model(597)
    def test_charger(self): self.check_model(598)


if __name__ == '__main__':
    unittest.main()
