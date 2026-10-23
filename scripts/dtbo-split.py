import struct, sys, os
img, out = sys.argv[1], sys.argv[2]
d = open(img, 'rb').read()
magic, total, hsz, esz, cnt, off, pg, ver = struct.unpack('>8I', d[:32])
assert magic == 0xd7b7ab1e, hex(magic)
os.makedirs(out, exist_ok=True)
for i in range(cnt):
    e = struct.unpack('>8I', d[off + i*esz: off + i*esz + 32])
    sz, o, id_, rev = e[0], e[1], e[2], e[3]
    open(f'{out}/ov{i}.dtb', 'wb').write(d[o:o+sz])
    print(i, hex(o), sz, 'id', hex(id_), 'rev', hex(rev), 'custom', [hex(x) for x in e[4:]])
