import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "drivers/net/wireless/ath/ath11k/pci.c"; c = f.read_text()
if "ath11k_pci_dump_bl_logs" in c: print("already"); sys.exit(0)
helper = r'''
/* EXPERIMENTAL debug (OnePlus 9 Pro QCA6490 v1): dump PBL/SBL boot logs from the chip SRAM when MHI
 * power-up fails, like the vendor cnss2 driver does (register addresses from cnss2/reg.h). */
static void ath11k_pci_dump_bl_logs(struct ath11k_base *ab)
{
	u32 sbl_start, sbl_size, i, n;
	u32 *buf;

	ath11k_warn(ab, "bl: pbl_log_reg 0x%08x boot_cfg 0x%08x bootstrap 0x%08x errdbg2 0x%08x errdbg3 0x%08x\n",
		    ath11k_pcic_read32(ab, 0x01B000F8), ath11k_pcic_read32(ab, 0x01E22B34),
		    ath11k_pcic_read32(ab, 0x01910008), ath11k_pcic_read32(ab, 0x01E0E238),
		    ath11k_pcic_read32(ab, 0x01E0E23C));

	buf = kzalloc(4096, GFP_KERNEL);
	if (!buf)
		return;

	for (i = 0; i < 160 / 4; i++)
		buf[i] = ath11k_pcic_read32(ab, 0x01403DA0 + i * 4);
	print_hex_dump(KERN_WARNING, "ath11k pbl log: ", DUMP_PREFIX_OFFSET, 16, 4, buf, 160, true);

	sbl_start = ath11k_pcic_read32(ab, 0x01E0E238);
	sbl_size = ath11k_pcic_read32(ab, 0x01E0E23C);
	if (sbl_start >= 0x01400000 && sbl_start < 0x017ff000) {
		n = 4096;
		for (i = 0; i < n / 4; i++)
			buf[i] = ath11k_pcic_read32(ab, sbl_start + i * 4);
		ath11k_warn(ab, "bl: sbl log @0x%08x (errdbg3 0x%x), first %u bytes:\n", sbl_start, sbl_size, n);
		print_hex_dump(KERN_WARNING, "ath11k sbl log: ", DUMP_PREFIX_OFFSET, 32, 4, buf, n, true);
	}
	kfree(buf);
}
'''
a = "static int ath11k_pci_power_up(struct ath11k_base *ab)"
assert a in c
c = c.replace(a, helper + "\n" + a, 1)
b = "\tret = ath11k_mhi_start(ab_pci);\n\tif (ret) {\n"
assert b in c, "mhi_start anchor"
c = c.replace(b, b + "\t\tath11k_pci_dump_bl_logs(ab);\n", 1)
f.write_text(c); print("ok")
