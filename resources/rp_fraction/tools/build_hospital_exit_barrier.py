"""Build a small untextured wall and a solid box collision for the open hospital exit."""
from pathlib import Path
import math
import struct

ROOT = Path(__file__).resolve().parents[1]
VERSION = 0x1803FFFF
SIZE = (6.4, 0.4, 4.2)


def chunk(kind, data):
    return struct.pack('<III', kind, len(data), VERSION) + data


def build():
    x, y, z = (v / 2 for v in SIZE)
    # Each quad has its own vertices so the six box faces have sharp normals.
    quads = [
        ((0, -1, 0), [(-x,-y,-z),(x,-y,-z),(x,-y,z),(-x,-y,z)]),
        ((0, 1, 0), [(x,y,-z),(-x,y,-z),(-x,y,z),(x,y,z)]),
        ((-1, 0, 0), [(-x,y,-z),(-x,-y,-z),(-x,-y,z),(-x,y,z)]),
        ((1, 0, 0), [(x,-y,-z),(x,y,-z),(x,y,z),(x,-y,z)]),
        ((0, 0, 1), [(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]),
        ((0, 0, -1), [(-x,y,-z),(x,y,-z),(x,-y,-z),(-x,-y,-z)]),
    ]
    vertices, normals, faces = [], [], []
    for normal, corners in quads:
        start = len(vertices)
        vertices.extend(corners);normals.extend([normal] * 4)
        faces.extend([(start,start+1,start+2),(start,start+2,start+3)])
    raw = struct.pack('<HBBIII', 0x7A, 0, 0, len(faces), len(vertices), 1)
    raw += bytes((255,255,255,255)) * len(vertices)
    raw += b''.join(struct.pack('<HHHH', b,a,0,c) for a,b,c in faces)
    raw += struct.pack('<4fII', 0,0,0,math.sqrt(x*x+y*y+z*z),1,1)
    raw += b''.join(struct.pack('<3f', *v) for v in vertices)
    raw += b''.join(struct.pack('<3f', *v) for v in normals)
    material = chunk(7, chunk(1, struct.pack('<I4BII3f', 0,166,163,148,255,0,0,1,0,1)) + chunk(3,b''))
    materials = chunk(8, chunk(1, struct.pack('<Ii',1,-1)) + material)
    indices = [i for f in faces for i in f]
    bin_mesh = struct.pack('<IIIII',0,1,len(indices),len(indices),0) + struct.pack('<%dI' % len(indices),*indices)
    geometry = chunk(15, chunk(1,raw) + materials + chunk(3,chunk(0x50E,bin_mesh)))
    matrix = struct.pack('<I12fii',1,1,0,0,0,1,0,0,0,1,0,0,0,-1,0)
    frames = chunk(14,chunk(1,matrix) + chunk(3,chunk(0x253F2FE,b'hospital_exit_wall\0'.ljust(20,b'\0'))))
    atomic = chunk(20,chunk(1,struct.pack('<IIII',0,0,5,0)) + chunk(3,b''))
    dff = chunk(16,chunk(1,struct.pack('<III',1,0,0)) + frames + chunk(26,chunk(1,struct.pack('<I',1)) + geometry) + atomic + chunk(3,b''))
    # COL3 offsets are relative to the size field at byte 4, just like the uploaded COL.
    bounds = struct.pack('<10f',-x,-y,-z,x,y,z,0,0,0,math.sqrt(x*x+y*y+z*z))
    header = b'hospital_exit_wall'.ljust(22,b'\0') + struct.pack('<H',0) + bounds
    header += struct.pack('<HHII',0,1,0,2)
    header += struct.pack('<9I',0,116,0,0,0,0,0,0,0)
    box = struct.pack('<6f4B',-x,-y,-z,x,y,z,0,0,255,255)
    payload = header + box
    col = b'COL3' + struct.pack('<I',len(payload)) + payload
    assert len(col)==148
    return dff,col


if __name__ == '__main__':
    dff,col = build()
    (ROOT / 'interior/exit_barrier.dff').write_bytes(dff)
    (ROOT / 'interior/exit_barrier.col').write_bytes(col)
    print('Hospital exit barrier: 6.4 x 0.4 x 4.2 m solid wall built')
