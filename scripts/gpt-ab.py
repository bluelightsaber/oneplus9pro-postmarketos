"""Lee una cabecera GPT + entradas (volcado de un disco del móvil) y muestra los atributos A/B
de Qualcomm de las particiones boot_a/boot_b: prioridad, activo, reintentos, correcto, no arrancable."""
import struct, sys
data = open(sys.argv[1], "rb").read()
ss = int(sys.argv[2]) if len(sys.argv) > 2 else 4096
hdr = data[ss:ss + 92]
assert hdr[:8] == b"EFI PART", hdr[:8]
ent_lba, n_ent, ent_size = struct.unpack_from("<QII", hdr, 72)
for i in range(n_ent):
    e = data[ent_lba * ss + i * ent_size: ent_lba * ss + (i + 1) * ent_size]
    if len(e) < 128 or e[:16] == b"\0" * 16:
        continue
    name = e[56:128].decode("utf-16-le").rstrip("\0")
    if name in ("boot_a", "boot_b"):
        a = struct.unpack_from("<Q", e, 48)[0]
        print(f"{name:7s} attr=0x{a:016x} prio={(a>>48)&3} active={(a>>50)&1} "
              f"retry={(a>>51)&7} successful={(a>>54)&1} unbootable={(a>>55)&1}")
