import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "drivers/net/wireless/ath/ath11k/pci.c"; c = f.read_text()
if "WLAON_QFPROM_PWR_CTRL" in c: print("already"); sys.exit(0)
b = "\tret = ath11k_mhi_start(ab_pci);\n"
assert b in c
c = c.replace(b, '''\t/* EXPERIMENTAL: vendor cnss2 clears VDD4BLOW_SW_EN (0x4) and SHUTDOWN_EN (0x1) in
\t * WLAON_QFPROM_PWR_CTRL_REG (0x1F8031C) before starting MHI (cnss_pci_set_wlaon_pwr_ctrl). */
\t{
\t\tu32 v = ath11k_pcic_read32(ab, 0x1F8031C);

\t\tath11k_pcic_write32(ab, 0x1F8031C, v & ~0x5);
\t\tath11k_warn(ab, "WLAON_QFPROM_PWR_CTRL 0x%08x -> 0x%08x\\n", v, ath11k_pcic_read32(ab, 0x1F8031C));
\t}
''' + b, 1)
f.write_text(c); print("ok")
