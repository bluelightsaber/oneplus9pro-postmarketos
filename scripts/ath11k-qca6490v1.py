import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "drivers/net/wireless/ath/ath11k/pci.c"; c = f.read_text()
if "QCA6490 v1" in c: print("already"); sys.exit(0)
a = "\t\tswitch (soc_hw_version_major) {\n\t\tcase 2:\n\t\t\tswitch (soc_hw_version_minor) {\n\t\t\tcase 0x00:\n\t\t\tcase 0x01:\n\t\t\t\tab->hw_rev = ATH11K_HW_WCN6855_HW20;"
assert a in c, "anchor"
c = c.replace(a, "\t\tif (soc_hw_version_major == 1)\n\t\t\tdev_warn(&pdev->dev, \"QCA6490 v1 (major 1, minor 0x%x): EXPERIMENTAL, treated as WCN6855 v2\\n\", soc_hw_version_minor);\n"
    "\t\tswitch (soc_hw_version_major) {\n\t\tcase 1: /* QCA6490 v1 (OnePlus 9 Pro): EXPERIMENTAL */\n\t\tcase 2:\n\t\t\tswitch (soc_hw_version_minor) {\n\t\t\tcase 0x00:\n\t\t\tcase 0x01:\n\t\t\t\tab->hw_rev = ATH11K_HW_WCN6855_HW20;", 1)
b = "\t\t\t\tath11k_dbg(ab, ATH11K_DBG_PCI, \"sub_version 0x%x\\n\",\n\t\t\t\t\t   sub_version);\n"
assert b in c, "anchor2"
c = c.replace(b, "\t\t\t\tdev_info(&pdev->dev, \"sub_version 0x%x\\n\", sub_version);\n", 1)
f.write_text(c); print("ok")
