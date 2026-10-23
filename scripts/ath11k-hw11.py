#!/usr/bin/env python3
# ath11k: WCN6851 = WCN6855 hw1.1 (SM8350 platforms, e.g. OnePlus 9 Pro; TCSR soc hw version 1.0x10), following
# Dmitry Baryshkov's "wifi: ath11k: enable support for WCN6851" (lkml 2026-06): copy of the hw2.0 params,
# fw dir WCN6855/hw1.1, num_vdevs 3 (4 crashes the original firmware), same MHI and MSI config as hw2.0.
import sys, pathlib, re
A = pathlib.Path(sys.argv[1]) / "drivers/net/wireless/ath/ath11k"
def edit(name, fn):
    p = A / name; t = p.read_text(); n = fn(t)
    if n == t: sys.exit(f"{name}: no change")
    p.write_text(n)
# core.h
edit("core.h", lambda t: t.replace("\tATH11K_HW_WCN6855_HW20,\n", "\tATH11K_HW_WCN6855_HW11,\n\tATH11K_HW_WCN6855_HW20,\n", 1))
# core.c: duplicate the hw2.0 entry
def core(t):
    s = t.index('\t\t.name = "wcn6855 hw2.0",')
    s = t.rindex("\t{\n", 0, s)
    e = t.index("\n\t},\n", s) + len("\n\t},\n")
    blk = t[s:e]
    nb = (blk.replace('"wcn6855 hw2.0"', '"wcn6855 hw1.1"')
             .replace("ATH11K_HW_WCN6855_HW20", "ATH11K_HW_WCN6855_HW11")
             .replace('"WCN6855/hw2.0"', '"WCN6855/hw1.1"'))
    nb, k = re.subn(r"\.num_vdevs = \d+,", ".num_vdevs = 3,", nb)
    assert k == 1 and nb != blk
    return t[:s] + nb + t[s:]
edit("core.c", core)
# mhi.c
edit("mhi.c", lambda t: t.replace("\tcase ATH11K_HW_WCN6855_HW20:\n", "\tcase ATH11K_HW_WCN6855_HW11:\n\tcase ATH11K_HW_WCN6855_HW20:\n", 1))
# pcic.c: duplicate the MSI config of hw2.0
def pcic(t):
    i = t.index("\t\t.hw_rev = ATH11K_HW_WCN6855_HW20,\n")
    s = t.rindex("\t{\n", 0, i)
    e = t.index("\t},\n", i) + len("\t},\n")
    blk = t[s:e]
    return t[:s] + blk.replace("ATH11K_HW_WCN6855_HW20", "ATH11K_HW_WCN6855_HW11") + t[s:]
edit("pcic.c", pcic)
# pci.c: major 1, minor 0x10 -> hw1.1
def pci(t):
    a = "\t\tath11k_pci_read_hw_version(ab, &soc_hw_version_major,\n\t\t\t\t\t   &soc_hw_version_minor);\n\t\tswitch (soc_hw_version_major) {\n\t\tcase 2:\n\t\t\tswitch (soc_hw_version_minor) {\n\t\t\tcase 0x00:\n\t\t\tcase 0x01:\n\t\t\t\tab->hw_rev = ATH11K_HW_WCN6855_HW20;"
    assert a in t, "pci anchor"
    return t.replace(a, a.replace("\t\tswitch (soc_hw_version_major) {\n\t\tcase 2:\n",
        "\t\tswitch (soc_hw_version_major) {\n\t\tcase 1:\n\t\t\tif (soc_hw_version_minor != 0x10)\n\t\t\t\tgoto unsupported_wcn6855_soc;\n\t\t\tab->hw_rev = ATH11K_HW_WCN6855_HW11;\n\t\t\tbreak;\n\t\tcase 2:\n"), 1)
edit("pci.c", pci)
print("ok")
