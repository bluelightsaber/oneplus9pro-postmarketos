# Development log

Chronological notes from the bring-up (moved out of the README). Newest entries are at the end.

- **Modern kernel**: mainline 7.3 with the config inherited from 6.7 hangs within 2 s (before USB comes
  up), also with the 6.7 DTB → kernel/config problem, not DT. Next step: **postmarketOS generic
  kernels** (`linux-postmarketos-lts` 6.18, `-stable`, `-mainline`) with our DTB through U-Boot
  (`scripts/prep-lts.sh`): a kernel that gets updates without maintaining it yourself. Notes: `vmlinuz`
  is **EFI zboot** (extract the gzip `Image`); `mkinitfs` 2.11 only writes through `boot-deploy`
  (needs the DTB in `/boot/dtbs/qcom/` and `android-tools`); extra initramfs modules go **by name** in
  `/etc/mkinitfs/modules/`; these kernels **have no simplefb** (black screen, USB network only).
- **Result 2026-10-07:** the postmarketOS **generic LTS 6.18.55** kernel (official config, its own
  initramfs with UFS/btrfs/NCM, 6.7 DTB) **also hangs** with no USB activity → the problem is common to
  modern kernels on this phone (or to how they are started), not to a hand-made config. Leading
  hypotheses: (1) arm64 CPU features enabled by newer kernels that the Qualcomm hypervisor traps
  (`arm64.nopauth/nobti`, `kpti=0` already ruled out; SVE/SME/MTE not yet); (2) placement of the much
  larger kernel image (45–56 MB vs 27 MB) over a firmware-reserved memory region.
- **A black screen is not a clue:** the 7.3 and generic kernels had **no framebuffer driver**
  (`FB_SIMPLE`/`DRM_SIMPLEDRM` unset), so they cannot print anything; text seen early on was U-Boot's.
  Next diagnostic: `scripts/kernel-build-73-fbcon.sh` builds 7.3 with `FB_SIMPLE`, the large
  `FONT_TER16x32` font and `BOOT_PRINTK_DELAY`; boot it with
  `fbcon=font:TER16x32 boot_delay=120 panic=0` and photograph the last lines.
  Gotcha: `scripts/config` upper-cases symbol names (`FONT_TER16X32`); use `-k` (keep case).
- **Result (fbcon via bootm):** the screen showed U-Boot's "Starting kernel ..." for ~30 s (slowed by
  `boot_delay`) and then went black: the kernel was running, but died/blanked before fbcon could draw.
  Kernel placement ruled out: production 6.7 is loaded at the same address (`0x260610000`).
- **Key technique — EFI boot for an early on-screen console** (`scripts/uboot-efi.sh`): a U-Boot env
  variant that, instead of `bootm`, does `imxtract` of the FIT's `fdt` and `kernel` and starts the kernel
  with `bootefi`. U-Boot then exposes its framebuffer as an EFI GOP, so `earlycon=efifb keep_bootcon`
  prints from the first kernel instruction. (No initrd on this path yet.) A phone video, cropped and
  enlarged with `ffmpeg`, is enough to read the log.
- **ROOT CAUSE FOUND:** with `initcall_debug`, the last line is
  `calling disp_cc_sm8250_driver_init` — the **display clock controller** driver (`dispcc-sm8250.c` also
  serves sm8350). Probing it kills the display pipeline the bootloader left running (and with it the
  boot). With `initcall_blacklist=disp_cc_sm8250_driver_init` the 7.3 kernel boots completely:
  via EFI it reaches `VFS: Unable to mount root` (expected, no initrd; UFS partitions are listed), and via
  the normal `bootm` path with initramfs it reaches the **login prompt** on screen.
  Remaining issue: no USB network with the `-lemonadep-fb` build because its modules were not installed
  (`scripts/kernel-modules-73fb.sh` builds them). Proper fix to investigate: keep dispcc but describe the
  display handoff correctly in the DT (or `clk_ignore_unused`-style protection of the MDSS clocks/GDSC).
- **USB on 7.3 — two more blockers found:**
  1. Config: the USB gadget stack (`USB_CONFIGFS`, `USB_LIBCOMPOSITE`, `USB_F_NCM`) and
     `PHY_QCOM_QMP_COMBO` ended up as modules (the PHY because `DRM=m`; it must match DRM). The initramfs
     cannot load them, so they must be built-in like on 6.7 (`scripts/kernel-build-73-fb2.sh`).
  2. DT: the mainline DTS wires `usb@a600000` (`dr_mode = "otg"`) to the pmic_glink USB-C connector,
     which should report the data role. This OnePlus firmware has no UCSI, so the role never arrives and
     the controller never enumerates. Test fix: `dr_mode = "peripheral"` (hook `DTB_CMDS` in
     `scripts/fit-7.3.sh`).
  3. Config (the real blocker): `PHY_QCOM_USB_SNPS_FEMTO_V2` (the USB 2.0 PHY) was `=m`. It only loaded
     after the rootfs was mounted, so dwc3 bound too late: the initramfs found no UDC and skipped the
     gadget. Diagnosed with the snapshot below (`dwc3` bound at 90 s, `devices_deferred` empty, the PHY in
     `lsmod`). Built-in (plus `PHY_QCOM_QUSB2`, `PHY_QCOM_USB_HS`, as on 6.7).
- **MILESTONE 2026-10-07: mainline 7.3.0-rc6 boots to userspace with SSH over USB** (`scripts/cycle-73.sh`:
  incremental rebuild → modules to the phone → periph-DTB image → RAM test). Boot args needed:
  `initcall_blacklist=disp_cc_sm8250_driver_init`. ADSP/CDSP/SLPI/modem all start; the Type-C port
  partner is visible (`/sys/class/typec/port0-partner`). Still to do on 7.3: port the battmgr patches
  (`qcom-battmgr-bat` reports capacity 0), enable `NF_TABLES` and `ZRAM` (lost in olddefconfig),
  a proper dispcc fix, then move the same fixes to the pmOS generic kernel (which very likely failed for
  the same dispcc reason).
- **Safety net for unattended RAM tests** (`scripts/experiment-fallback-install.sh`): a systemd service
  on the rootfs that, when the running kernel is not the production one, reboots after 15 min (the ABL
  then boots `boot_a`) unless `/run/keep-experiment` exists. After 90 s it also saves a diagnostic
  snapshot (dmesg, devices_deferred, USB sysfs, clk_summary, lsmod, remoteprocs) to
  `/var/log/experiments/<kernel>-<date>/`, readable later from production; the systemd journal is
  persistent too (`journalctl -b -1`).
- **Wi-Fi/BT**: fix `vddaonwl-supply` and the QCA6490 enable; on mainline use `pwrseq-qcom-wcn`.
- **USB-C hub with Ethernet**: test pending (procedure: `usb-host-try 600` on the phone, move the cable to the hub, `scripts/find-phone.sh` on the host).
- Ubuntu Touch / Debian (Mobian) only on top of the modern kernel.
- **7.3 config parity and battery (2026-10-07):** `scripts/config-73-parity.sh` restores every option
  that was enabled on 6.7 and got lost in the 7.3 `olddefconfig` (nftables, NAT, RMI4 touch, ...; legacy
  iptables tables now also need `NETFILTER_XTABLES_LEGACY`), plus Docker/Tailscale/zram needs (tun,
  veth, bridge, overlay, cgroups, namespaces). On 7.3 the ADSP firmware *does* announce `charger_pd`
  via PDR, so the 6.7 `skip_pdr` hack is not needed; battmgr and UCSI work out of the box. Patch
  `patches/linux-7.3-0001-*` adds `charge_behaviour` (auto / inhibit-charge) for SM8350 using
  `BAT_PROPERTY_SET`/`BATT_CHG_CTRL_EN`; on 7.3 the desc also needs `.charge_behaviours`. Verified:
  writes accepted, nftables/zram/tun/veth/bridge/overlay load.
- **dispcc root cause:** since ~6.11, `clk_rcg2_shared_ops` parks the RCG on XO at registration, which
  cuts the MDP/AHB/rot/vsync clocks of the display the bootloader left running. Patch
  `patches/linux-7.3-0002-*` switches them to `clk_rcg2_shared_no_init_park_ops` (as dispcc-sc8280xp).
  It is **not enough on its own** (without the `initcall_blacklist` the kernel still resets early);
  next step is an EFI-earlycon run of that image to see the next culprit.
- **pmOS generic LTS 6.18.55** (`scripts/prep-lts2.sh` + `scripts/lts2-test.sh`): with the USB PHY
  modules in its initramfs (`phy-qcom-snps-femto-v2`, `phy-qcom-qmp-combo`), the 7.3 DTB in peripheral
  mode and the dispcc blacklist it reaches userspace and sets up the USB gadget, but resets ~0.5 s after
  `remote processor modem is now up`. With the modem disabled in the DTB
  (`/soc@0/remoteproc@4080000 status = "disabled"`; a server doesn't need it) it boots to **SSH**, but
  died again within a minute (cause not captured yet).
- **DANGER — shared btrfs rootfs and newer kernels:** a test kernel that crashes can leave a btrfs
  *log tree* (written by every `fsync`) that the production 6.7 btrfs cannot replay
  (`btrfs_replay_log ... Failed to recover log tree`) → production stops in the initramfs debug shell
  ("unable to mount root partition"). Recovery used: telnet to the debug shell (port 23), check the data
  with `mount -o ro,nologreplay`, then `btrfs rescue zero-log /dev/loop0p2` (drops only the last seconds
  of the crashed session) and `pmos_continue_boot`; a `btrfs scrub` afterwards found no errors.
  Prevention: all experimental images now mount the rootfs with **`notreelog`** (added to
  `pmos_rootfsopts` by the variant scripts), and nothing fsyncs in a loop on the rootfs.
- **OnePlus crash handling:** a hard reset during a hung shutdown can land in **XBL RamDump** ("phoenix",
  USB `05c6:900e QUSB_BULK`). Way out: hold Power+Vol-Up ~10–15 s; Power+Vol-Down then gives fastboot,
  from where production can be RAM-booted to inspect (`journalctl -b -1`). Note that a long press on the
  power key is a clean poweroff request for systemd-logind.
- **Production robustness:** one sporadic hang of 6.7 at boot while powering up the ADSP (2.6 s); a
  5-reboot soak right after was 5/5 OK. Worth a hardware watchdog later.
- **pmOS generic `linux-postmarketos-mainline` 7.3-rc5 WORKS (2026-10-07):** same recipe as above
  (`scripts/lts2-test.sh linux-postmarketos-mainline`): USB PHY modules in the initramfs, 7.3 DTB with
  `dr_mode = "peripheral"` and the modem disabled, `initcall_blacklist=disp_cc_sm8250_driver_init`,
  `notreelog`. SSH, ADSP/SLPI/CDSP, charging, nftables, zram, tun/veth/bridge/overlay all OK, and a
  16-minute RAM soak (`scripts/soak-ram.sh`) was stable (~40 °C, load ~0.1). Missing vs production:
  `charge_behaviour` (needs the battmgr patch as an out-of-tree module per kernel version), `rmtfs`
  fails (harmless, modem disabled), and USB host mode needs a DT rework (`dr_mode = "otg"` +
  `usb-role-switch` without the pmic_glink connector graph). The LTS (6.18) was much less stable.
- **Production candidate: our own build of the pmOS `linux-postmarketos-mainline` package.** The pmOS
  generic kernel is built with clang (kCFI + shadow call stack) and runs with
  `LOCK_DOWN_KERNEL_FORCE_INTEGRITY`: only modules signed with the build's ephemeral key load
  (an out-of-tree `qcom_battmgr.ko`, even with a matching vermagic, gets `EPERM`). The SM8350 battmgr
  exposes no native charge thresholds and the USB input current is not writable, so the charge limit
  needs the kernel patch. Solution: build the official APKBUILD with pmbootstrap plus one patch
  (`0100-qcom_battmgr-charge-behaviour-sm8350.patch`, `pkgrel=100+N` so it wins over the official
  package). `scripts/update-pmos-kernel.sh` automates the cycle: new upstream pkgver in pmaports →
  regenerate the patch against the new tag (anchored script, fails loudly if the driver changed) →
  `pmbootstrap build --lax` → `scripts/build-pmos-image.sh` (initramfs with the USB PHYs, production
  DTB, U-Boot env with the dispcc blacklist and `notreelog`, modules to the phone) →
  `scripts/test-pmos.sh` (SSH, `charge_behaviour`, USB role, reboot to fastboot from Linux) → 15-min RAM
  soak → `--promote` writes `boot_a` (with backup).
- **Production DTB for the new kernel** (`build-pmos-image.sh`): raw lemonadep DTB from our tree, modem
  disabled, USB `dr_mode = "otg"` + `usb-role-switch` + `role-switch-default-mode = "peripheral"`. On 7.3
  UCSI works, so the role follows the USB-C connection (`/sys/class/usb_role/a600000.usb-role-switch/role`
  = `device` on the host PC). `usb-mode` now uses `usb_role` when it has a `role` file, debugfs on 6.7.
- **pmbootstrap gotcha:** `pmbootstrap build` zaps the buildroots in strict mode and fails if something
  is bind-mounted inside a chroot (our `home/pmos/src`): unmount it, `pmbootstrap shutdown`, build with
  `--lax`.
- **PROMOTED 2026-10-08: production now runs our build of pmOS `linux-postmarketos-mainline`
  7.3_rc5-r100** from `boot_a` (6.7 backup: `backups/boot_a-1008-0809.img`). Post-promotion: `rmtfs`
  masked and `modem-off` disabled (modem disabled in the DTB), `PRODUCTION_KERNEL=7.3.0-rc5` in
  `/etc/experiment-fallback.conf`. Verified: `systemctl is-system-running` = running (no failed units),
  zram swap works, rootfs mounted with `notreelog`, charge-limit drives `charge_behaviour`
  (inhibit above 65 %), USB role `device`, reboot to fastboot from Linux, 3-reboot soak with `boot_a`
  `successful=1`. Rollback: fastboot → RAM-boot the 6.7 backup → `scripts/promote-boot.sh` it back.
  Updates: `scripts/update-pmos-kernel.sh [--promote]`.


## 2026-10-27/28 — 7.3 final, zstd initramfs, USB host investigation

- **7.3 final in production** (upstream bumped from 7.3-rc6). The update cycle needed one fix:
  postmarketOS now builds a **zstd-compressed initramfs** (was gzip), and `prep-lts.sh` used `zcat`
  on it. It now uses `zstdcat || zcat`. The kernel has `CONFIG_RD_ZSTD=y` and the U-Boot FIT passes
  the ramdisk through unchanged, so nothing else had to change.
- **Builds run at the lowest priority** (`nice 19` + `ionice` idle): the build host also runs other
  services. The main build scripts renice themselves.
- **Reboot loop after a manual promote:** `experiment-fallback` (reboots to production if an
  experimental kernel is left running) compares `uname -r` with `PRODUCTION_KERNEL` in
  `/etc/experiment-fallback.conf`. A promote with `promote-boot.sh` did not update it, so the new
  production kernel was rebooted every 15 min (cleanly, always back to the same kernel).
  `promote-boot.sh` now writes `PRODUCTION_KERNEL` itself.
- **USB host mode does not work yet**, contrary to what an earlier version of the README said (it
  had only been switched, never tested with a device). Details in `docs/usb-host.md`.
- **Oplus charger firmware properties** (2026-10-28): patch 0100 adds `oplus_usb_prop` (raw access to
  the Oplus-specific USB properties of the ADSP firmware). Reading them showed the port is already
  dual-role; the missing pieces for OTG are the boot-time `USB_OTG_AP_ENABLE`/`USB_OTG_SWITCH`
  writes and the external VBUS boost. See `docs/usb-host.md`.
