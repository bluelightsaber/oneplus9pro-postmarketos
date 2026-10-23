# OnePlus 9 Pro (lemonadep) as a Linux server with postmarketOS and a mainline kernel

> **Status:** work in progress (last update: 2026-10-10). The phone runs as a headless home server with
> postmarketOS edge and our own build of the postmarketOS `linux-postmarketos-mainline` kernel (7.3-rc6)
> with a handful of patches: real display panel driver, Wi-Fi, Bluetooth, GPU, Docker and Tailscale work.
>
> **AI disclosure:** this work (patches, scripts and this guide) was done with the help of an AI assistant
> (Claude). postmarketOS/Nura **forbids** contributions created fully or partly with generative AI, so
> **do not submit any of this to their repositories**. Use at your own risk.
>
> **Risk:** unlocking the bootloader wipes the phone; flashing partitions can leave it unbootable
> (the bootloader's fastboot mode always remains available). Read everything before starting.

---

## 1. What works and what doesn't

| Feature | Status | Notes |
|---|---|---|
| Booting from internal storage | ✅ | ABL → U-Boot → Linux 6.7 (see §3) |
| SSH over USB networking (172.16.42.1) | ✅ | postmarketOS NCM gadget |
| UFS storage, btrfs rootfs | ✅ | NOCOW on `/var/log` and `/var/tmp`, `noatime` |
| Battery charging | ✅ | requires the ADSP remote processor to run |
| Charge limit (45–65 % hysteresis) | ✅ | `qcom_battmgr` patch + service |
| Reboot to fastboot from Linux | ✅ | `nvmem-reboot-mode` (module) |
| A/B slots stable across many reboots | ✅ | `qbootctl -m` on every boot (**mandatory**) |
| USB host mode (OTG) | ✅ manual | via dwc3 debugfs; no automatic detection (firmware has no UCSI) |
| Modem off | ✅ | stopped at boot |
| Display | ✅ | real panel driver (Samsung AMB670YF01, DSC 10 bpc) in production: kernel console (TER16x32, rotated to landscape), brightness, blank/unblank; `btop` on the console, blanked after 1 h idle, woken by any key (`config/screen-idle/`) |
| Wi-Fi (QCA6490 = WCN6851 = WCN6855 hw1.1) | ✅ production | ath11k hw1.1 patch (as Baryshkov's sm8350-hdk series), vendor fw from the phone's own `modem_a` + `persist` (`scripts/qca6490-fw-install.sh`), real MAC from persist; connected to the home LAN |
| Bluetooth (same chip, UART18) | ✅ production | `qcom,wcn6855-bt`, 4-pin uart18 + serial1 alias; BTFM.HSP.1.0.0-00978; bluez |
| Modern mainline kernel (7.x) | ✅ | production: our build of pmOS `linux-postmarketos-mainline` 7.3-rc6 (r104, patches `patches/pmos-package/0100`–`0104`), updated with `scripts/update-pmos-kernel.sh` |
| GPU (Adreno 660) | ✅ | in production since 2026-10-08: Vulkan 1.3 (`Turnip Adreno (TM) 660`) + GL (`FD660`); DTB `gpu@3d00000` okay + zap shader `qcom/sm8350/OnePlus/lemonade/a660_zap.mbn`, bootarg `msm.separate_gpu_kms=1` (display left off) |
| Docker / Tailscale / NTP | ✅ | Docker 29 (data-root /opt/docker on the 102 GB data disk), Tailscale, systemd-timesyncd |
| Storage | ✅ | rootfs 9.9 GB in `super`; `userdata` 102 GB = btrfs data disk (`/data`, `/opt/docker`, `/var/lib/containerd`) |
| Touch, audio, camera | ❌ | touch (Synaptics S3908 on I2C4): driver probes, but the bus is held low — under investigation (`docs/touchscreen.md`); audio/camera not addressed |

---

## 2. Versions used

| Component | Version |
|---|---|
| Phone | OnePlus 9 Pro **LE2123** (EU/global), codename `lemonadep`, SoC SM8350 |
| Android firmware | OxygenOS **14.0.0.1902 (EX01)** (OOS 14 bootloader/ABL) |
| LineageOS images (dtbo/vendor_boot/vbmeta/boot only) | LineageOS **23.2 nightly 2026-10-05** for `lemonadep` |
| postmarketOS / Nura | **edge**, systemd, `console` UI (October 2026) |
| pmbootstrap | 3.11.1 |
| Kernel | production: pmOS `linux-postmarketos-mainline` **7.3-rc6** rebuilt with our patches (pkgrel 104); first port used `linux-postmarketos-qcom-sm8350` 6.7 (archived fork `sm8350-mainline/linux` @ `ffb1b0db`) |
| U-Boot | **v2026.10** (mainline) plus one patch |
| Host | Ubuntu Server 26.04 (laptop), adb/fastboot from platform-tools 37 |

---

## 3. Boot architecture (the most important part)

The OnePlus bootloader with OOS 14 firmware (**ABL**) **will not boot any image with a custom `dtbo`**:
with any `dtbo` that isn't an "official" one (signed/structured like LineageOS's) it returns
`Failed to load/authenticate boot image: Load Error`. We tried empty overlays, overlays with fragments,
with `__fixups__`, signed with the AOSP test key, an empty table and a zeroed partition: all fail.

The solution is to **keep the ABL happy with LineageOS's pieces** and put **U-Boot** in between:

```
ABL (OOS 14)
 ├─ dtbo_a        = LineageOS dtbo.img             (accepted by the ABL)
 ├─ vendor_boot_a = LineageOS vendor_boot.img      ("downstream" DTB that the ABL selects)
 ├─ vbmeta_a      = LineageOS vbmeta.img with --disable-verity --disable-verification
 └─ boot_a        = boot.img v3:
        kernel  = gzip(u-boot-nodtb.bin + mainline 9 Pro DTB)        ← U-Boot uses ITS internal DTB
        ramdisk = FIT(pmOS ramdisk, DTB, Linux Image) + 112–128 MB of zeros
            └─ U-Boot finds the FIT inside the ramdisk the ABL loaded, copies it to an aligned
               buffer and runs bootm → Linux with our mainline DTB
```

Why each detail matters:
- **The ABL concatenates** its vendor ramdisk (LineageOS, ~24 MB lz4) and ours, and places the whole
  thing **against the top** of a region ending at `0xb0000000`.
- **U-Boot relocates itself** to the top of RAM and **overwrites the end of that ramdisk** → hence the
  zero padding at the end: what gets overwritten is padding, not the FIT.
- The FIT ends up only **4-byte aligned** and libfdt requires **8** → U-Boot copies it (`cp.b`) to
  `${ramdisk_addr_r}` before `bootm`. The copy size must cover the whole FIT (we use `0x6000000`).
- Inside the FIT the **kernel goes last** (`kernel_noload`): U-Boot moves it forward to align it to
  2 MB, so it doesn't overwrite the ramdisk or the DTB.

### U-Boot patch (`patches/u-boot-0001-…`)
In `arch/arm/mach-snapdragon/board.c`:
1. In `board_fdt_blob_setup()` (before relocation) read `linux,initrd-start/end` from `/chosen` in the
   ABL's DTB and store them in `.data` variables, **using `get_unaligned_be64()`**: an unaligned 64-bit
   access with the MMU off hangs U-Boot without printing anything.
2. In `board_late_init()` export `prevbl_initrd_start/end` to the environment and **reserve** that
   region in LMB.
3. **Do not** clamp `board_get_usable_ram_top()` below the ramdisk: it makes U-Boot overwrite the ABL's DTB.

Environment (`patches/pmos-lemonadep.env`): `bootcmd` looks for the FIT at `prevbl_initrd_start + {0,
vendor ramdisk size, that size 4K-aligned}`, copies it and runs `bootm`; `pmos_bootargs` holds the
kernel command line (rootfs UUIDs, etc.).

---

## 4. Step-by-step procedure

> Example paths: the host is called `buildhost`; all work lives in `/srv/oneplus9pro-pmos` (`$P`).
> The scripts mentioned are in `scripts/`.

### 4.0 Host
- **adb/fastboot**: Google's official platform-tools in the home directory (no `apt` needed).
- **udev** (`/etc/udev/rules.d/51-android.rules`), `plugdev` group, for vendor IDs `18d1` (fastboot),
  `2a70` (OnePlus), **`22d9` (OPPO: OOS 12+ shows up as this)** and `05c6`.
- **TLP / USB autosuspend!** If the host is a laptop with TLP, USB autosuspend (2 s) **hangs the OnePlus
  ABL's USB stack** (seemingly random disconnects in fastboot). Exclude the phone's IDs:
  `/etc/tlp.d/90-oneplus-pmos.conf` with
  `USB_DENYLIST="18d1:d00d 18d1:4ee0 22d9:2765 22d9:2769 2a70:9011 18d1:d001 0525:a4a2"`.
- If the host lacks `flex`/`bison`, build **inside pmbootstrap's native chroot**, bind-mounting the
  sources with `mount --bind`.

### 4.1 Unlocking
Developer options → USB debugging + OEM unlocking; `adb reboot bootloader`; `fastboot flashing unlock`
and confirm with the buttons (**wipes the phone**). The LE2123 needs no unlock token.

### 4.2 pmbootstrap
`pmbootstrap init`: **edge** channel, vendor `oneplus`, device **`lemonadep`** (it's archived; accepted
with a warning), `console` UI, systemd. The kernel and firmware are built locally (archived packages
have no binaries).
- `firmware-oneplus-lemonade` puts **`modem.mbn` (83 MB) into the initramfs** → the `boot.img` doesn't
  fit → patch `patches/pmaports-0001-…` (drop `modem.mbn` and `ipa_fws.mbn` from
  `10-remoteproc-firmware.files`; they stay in the rootfs).
- `pmbootstrap install --filesystem btrfs`.
- Post-install rootfs tweaks (`scripts/ajustes-rootfs.sh`): the image is **Android sparse** →
  `simg2img`; mount with **`losetup -b 4096`** (the deviceinfo uses 4096-byte sectors; with 512 the GPT
  isn't found); recreate `/var/log` and `/var/tmp` with `chattr +C`; `noatime` in fstab; `tmpfs /tmp`;
  then `img2simg` back.

### 4.3 LineageOS partitions
Download from download.lineageos.org (`lemonadep`) `dtbo.img`, `vendor_boot.img`, `vbmeta.img` (and
`boot.img` to get Lineage Recovery as a known-good baseline) and verify their SHA-256. Flash to slot a:
```
fastboot flash dtbo_a dtbo.img
fastboot flash vendor_boot_a vendor_boot.img
fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
```
With Lineage's `boot.img` in `boot_a`, `fastboot reboot recovery` should boot Lineage Recovery: this
confirms the ABL is happy.

### 4.4 U-Boot + FIT
`scripts/uboot-build.sh` (inside the native chroot, `CROSS_COMPILE=aarch64-alpine-linux-musl-`):
`qcom_defconfig qcom-phone.config pmos-lemonadep.config`, patch applied; then
`u-boot-int.bin = u-boot-nodtb.bin + DTB`, `gzip`, `mkimage -f pmos.its`, 128 MB of padding and
`mkbootimg --header_version 3 --kernel u-boot-int.bin.gz --ramdisk pmos-padded.itb`.
The `boot.img` must not exceed **192 MiB** (size of `boot`).

### 4.5 RAM test and flashing
`fastboot boot boot-uboot.img` (writes nothing). If it boots: `pmbootstrap flasher flash_rootfs`
(→ `super`, **wipes Android**) and `fastboot flash boot_a boot-uboot.img`.

### 4.6 Mandatory post-install steps
- **A/B slots — `qbootctl -m` on every boot.** postmarketOS doesn't mark the boot as successful; the ABL
  uses up slot a's retries (6), marks it unbootable, tries slot b and **ends up in fastboot with "Load
  Error" on every boot**. Install `qbootctl` and a `mark-boot-successful.service`
  (`ExecStart=/usr/bin/qbootctl -m`). Check the attributes with `scripts/gpt-ab.py` on a dump of
  `/dev/sde` (GPT with 4096-byte sectors). If it already happened: `fastboot flash boot_a …` resets the
  counter.
- **Don't use `reboot=warm`**: it makes the ABL stay in fastboot after a normal reboot.
- **Clock**: without a network the clock drifts; set it (`date -s` + `hwclock -w`) until NTP is available.

### 4.7 Charging, charge limit and reboot to fastboot (modules for 6.7)
Built against the exact 6.7 tree (`scripts/k67-prepare.sh`, `scripts/k67-modules.sh`) with
`KBUILD_MODPOST_WARN=1` (the kernel uses neither MODVERSIONS nor module signing; only the vermagic
`6.7.0 SMP preempt mod_unload aarch64` has to match). **Never turn into a module anything the kernel
already has built in** (e.g. `TYPEC=y`).
- **ADSP**: don't blacklist `adsp_driver_init`. Charging is handled by the ADSP firmware.
- **`pmic_glink`** (`patches/linux-6.7-0001-…`): the OnePlus firmware **never announces `charger_pd`
  over PDR** → `skip_pdr=1` parameter (`/etc/modprobe.d/pmic_glink.conf`); notify clients that register
  late; create the UCSI client on sm8350.
- **`qcom_battmgr`** (`patches/linux-6.7-0002-…`): the firmware **doesn't support** the charge-limit
  opcode `0x48` (it times out), but it **does** accept `BAT_PROPERTY_SET` of `BATT_CHG_CTRL_EN` →
  `charge_behaviour` (`auto`/`inhibit-charge`). The `charge-limit` service implements the hysteresis
  (`/etc/charge-limit.conf`) and **re-asserts** the mode every minute (the ADSP re-enables charging
  when it restarts).
- **`nvmem-reboot-mode` + `nvmem_qcom-spmi-sdam`** → `systemctl reboot --reboot-argument=bootloader`.
- **Modem**: `modem-off.service` (script in `/usr/local/sbin/modem-off`; don't put the logic inside
  `ExecStart`, systemd expands the `$` itself).

### 4.8 USB host mode (OTG)
- The DTB must have **`usb-role-switch;`** in the dwc3 node (`/soc@0/usb@a6f8800/usb@a600000`);
  without it dwc3 is forced to device mode ("Configuration mismatch. dr_mode forced to gadget").
- The role switch doesn't allow userspace control on 6.7 → use
  `/sys/kernel/debug/usb/a600000.usb/mode` (`host`/`device`). `scripts/usb-mode-install.sh` installs
  `usb-mode`, `/etc/usb-mode.conf` and an **automatic fallback to `device`** if there is no LAN
  network within 5 minutes.

---

## 5. Lessons learned (symptom → cause → fix)

| Symptom | Cause | Fix |
|---|---|---|
| "Random" disconnects in fastboot | TLP USB autosuspend on the host | `USB_DENYLIST` in TLP |
| adb doesn't see the phone | vendor ID `22d9` (OPPO) missing from udev | add it to the rule |
| `fastboot boot`: "Requested download size is more than max allowed" | 77 MB initramfs because of `modem.mbn` | keep modem firmware out of the initramfs |
| "Booting OKAY" but stays in fastboot / "Load Error" | the OOS 14 ABL rejects custom DTB/dtbo | LineageOS dtbo/vendor_boot/vbmeta + U-Boot |
| `qcom,msm-id` | the ABL uses **415** (`0x19f`), not mainline's 439 | (only relevant without U-Boot) |
| U-Boot: "Unknown image format" with the FIT present | FIT overwritten by relocation / only 4-byte aligned | zero padding + `cp.b` to an aligned buffer |
| U-Boot shows nothing at all | unaligned 64-bit read before the MMU is on | `get_unaligned_be64()` |
| "Bad FIT image" | fixed copy size smaller than the FIT | increase it (0x6000000) |
| USB network with no traffic (TX errors) | `CONFIG_USB_ETH=y` (legacy g_ether) grabs the UDC | `initcall_blacklist=eth_driver_init` or disable it |
| Ubuntu host doesn't talk RNDIS | `rndis_host` not loaded / `cdc_subset` binds wrongly | `modprobe rndis_host` and `bConfigurationValue` |
| "Not charging" | ADSP blacklisted (`adsp_driver_init`) | don't blacklist it |
| After ~6 reboots, fastboot with "Load Error" | A/B slot never marked successful | `qbootctl -m` on every boot |
| Empty pstore after a crash | the bootloader doesn't preserve RAM across a crash reset | pstore is useless here for crash logs |
| Phone "hangs" after U-Boot's "Starting kernel ..." (no USB), but the journal shows a full boot | pmOS initramfs creates the USB gadget only if a UDC already exists; when dwc3 probes later (race, seen with the GPU enabled) it silently skips it (`No UDC found`) and nothing retries | `usb-gadget-ensure.service` on the rootfs: waits for the UDC and recreates gadget g1 (NCM, 172.16.42.1). Lesson: check `journalctl -b -1` before calling it a kernel hang |
| `vulkaninfo`: `ERROR_OUT_OF_HOST_MEMORY` in `vkGetPhysicalDeviceDisplayPropertiesKHR` | with `separate_gpu_kms` the `card0` node has no KMS | run with access to `renderD128` only (`setpriv --groups=render`) |
| Modern kernel dies/freezes once `dispcc` probes (hence `initcall_blacklist=disp_cc_sm8250_driver_init`) | (1) since ~6.11 shared RCGs are parked at registration; (2) after `sync_state` nothing holds the display resources the bootloader left running: genpd/rpmhpd drop MMCX to performance level 0 while the MDP runs at 460 MHz → MDP freezes (command-mode panel keeps the last image, so it looks like a hang) | patch `0101` (`clk_rcg2_shared_no_init_park_ops`) **and** a simple-framebuffer node that holds `power-domains = <&rpmhpd MMCX>, <&dispcc MDSS_GDSC>`, `required-opps = <&rpmhpd_opp_nom>`, clocks GCC disp AHB/AXI + dispcc AHB/MDP/MDP_LUT/VSYNC, with `FB_SIMPLE`. Diagnosed with `genpd` summary (`mmcx on 0`) and the EFI earlycon (`calling of_platform_sync_state_init` = last line) |
| Wi-Fi: "Phy link never came up" | typo `vddaonwl-suppbly` in the port's DT + chip enable | see §7 |

---

## 5b. GPU benchmarks (2026-10-09, production 7.3-rc6, Mesa 26.2.4 Turnip)

Packages installed offline with `scripts/phone-apk-install.sh` (fetches in the buildroot chroot, copies only
packages the phone does not have). GPU devfreq 315–840 MHz (`simple_ondemand`, reaches 840 MHz under load).

| Test | OnePlus 9 Pro (Adreno 660) | Host i7-8565U (UHD 620) |
|---|---:|---:|
| `vkmark --winsys headless -s 1920x1080` score | **3052** | 2092 (llvmpipe: 424) |
| llama.cpp `llama-bench`, Qwen2.5-1.5B-Instruct Q4_0, CPU 4 threads pp512 / tg128 (t/s) | 54.9 / 17.7 | – |
| same, CPU 8 threads | **101.4 / 18.1** | – |
| same, GPU Vulkan `-ngl 99` | 61.0 / 7.9 | – |

- GPU temperature 32 → 47 °C after vkmark, ~58 °C during llama-bench (no throttling seen).
- For LLM inference the **CPU beats the GPU** (ggml-vulkan on Turnip: no integer dot product, no
  cooperative-matrix support, 32 KiB shared memory → ~0.2 TFLOPS effective of ~1.7 peak). Use the CPU
  for llama.cpp; the GPU is still useful for graphics/Vulkan work or to offload while the CPU is busy.
- OpenCL: `mesa-rusticl` loads but exposes **no device** for this GPU (`RUSTICL_ENABLE=freedreno`).

## 5c. Wi-Fi and Bluetooth (QCA6490) — how it was made to work (2026-10-09)

1. **DT bugs** in `sm8350-oneplus-common.dtsi`: gpio95 listed twice in the pcie0 default pinctrl (PCIe never
   probed) and PERST# gpio94 `GPIO_ACTIVE_HIGH` (must be LOW) — patch 0004.
2. **Power**: `qcom,wcn6855-pmu` (pwrseq-qcom-wcn) with wlan-en gpio64, bt-en gpio65, swctrl gpio153 and the
   vendor rail voltages (s11/pmr735a_s2 0.952 V, s12 1.352 V, pm8350c_s1 1.88 V; the common ranges let
   pmr735a_s2 sit at 500 mV) + pmr735a_l7 (RF front-end) always on; `wifi@0` (pci17cb,1103) on pcie0.
3. **Driver**: the chip reports TCSR soc version 1.0x10 = WCN6851 / "WCN6855 hw1.1"; ath11k support added as
   in Dmitry Baryshkov's series ("enable WiFi/BT on SM8350 HDK", lkml 2026-06): hw2.0 params copy,
   `WCN6855/hw1.1`, num_vdevs 3 — patch 0007 / package patch 0102.
4. **Firmware** (never redistribute): `amss.bin` + `m3.bin` from the phone's `modem_a` (WLAN.HSP.1.1-01737,
   V1/V2 silicon), and from `persist`: `bdwlan.elf` (OnePlus board data, what cnss2 loads for board_id 0xff)
   as `board.bin` and the vendor `regdb.bin`. The linux-firmware hw2.1 `amss.bin` stops in SBL (never
   reaches mission mode); the linux-firmware hw2.0 `regdb.bin` crashes this firmware at "wlan mode req".
   `firmware_class.path=` did not work for this, files go to `/lib/firmware/ath11k/WCN6855/hw1.1/`.
5. **Bluetooth**: `qcom,wcn6855-bt` on uart18 with the 4-pin qup18 config (vendor qupv3_se18_4uart) and an
   `aliases { serial1 = &uart18; }` (geni-serial fails with "Invalid line -19" without it); firmware
   `qca/wcnhpbtfw10.tlv` + `qca/wcnhpnv10.bin` (already shipped).
6. Debug notes: MHI host `-DDEBUG` + `MHI_BUS_DEBUG` regdump show the boot stages (PBL→SBL via BHI, BHIe of
   amss, mission mode); `FW_LOADER_USER_HELPER_FALLBACK=y` makes ath11k wait 60 s per missing optional file.

## 5d. System setup on the phone (2026-10-09)

- **Network:** NetworkManager; Wi-Fi profile created with `sudo nmcli --ask device wifi connect "<SSID>"` (the
  password is typed by the owner). Real Wi-Fi MAC: `scripts/wifi-mac-from-persist.sh` (systemd .link from
  persist `wlan_mac.bin`) + NM `wifi.scan-rand-mac-address=no` + empty `/etc/udev/rules.d/90-bootmac-wifi.rules`
  (pmOS bootmac would otherwise set a generated MAC).
- **USB-C role:** `/etc/usb-mode.conf` MODE=auto — UCSI decides (device towards a PC, host towards a hub).
- **Ethernet ↔ Wi-Fi:** NM dispatcher `70-ethernet-wifi` (wired up → Wi-Fi off, last wired down → on) and
  `wifi-boot-safety.service` (45 s after boot, no wired link → Wi-Fi on). `scripts/net-auto-install.sh`.
- **Time:** systemd-timesyncd, Europe/Madrid.
- **Docker:** `apk add docker docker-cli-compose`; `/etc/docker/daemon.json` `data-root: /opt/docker`. pmOS ships an
  nftables firewall (forward policy drop); `postmarketos-config-nftables-docker` adds `51_docker.nft`, but you
  must `systemctl reload nftables && systemctl restart docker` after installing (a reload can flush Docker NAT).
- **Tailscale:** `apk add tailscale`, `tailscale up --hostname=…` (owner logs in), firewall
  `/etc/nftables.d/52_tailscale.nft` (accept from tailscale0, UDP 41641).
- **Storage:** `scripts/data-setup.sh` formats `userdata` as btrfs (`@data`, `@docker`, `@containerd`), fstab
  with `nofail`; `scripts/docker-opt.sh` moves Docker to `/opt/docker`.

## 6. Repository layout
- `patches/pmos-package/` — the patches added to the pmOS `linux-postmarketos-mainline` APKBUILD
  (0100 battmgr charge_behaviour, 0101 dispcc no-init-park, 0102 ath11k WCN6855 hw1.1, 0103 SMMU identity
  for sm8350 MDSS, 0104 AMB670YF01 panel driver). Generated by `scripts/update-pmos-kernel.sh`.
- `patches/kernel-tree/` — the same work as a `git format-patch` series on top of mainline 7.3-rc6+
  (commit 2c3418fff), including the lemonade/lemonadep device trees (by Nia Espera) and our DT changes
  (display, PCIe0 fix, QCA6490 Wi-Fi via `wcn6855-pmu`, Bluetooth on UART18).
- `patches/u-boot/` — U-Boot patch, U-Boot environment (`<ROOT_FS_UUID>`/`<BOOT_FS_UUID>` are per
  install), FIT template. `patches/pmaports/`, `patches/old-6.7/` — earlier work.
- `dts/` — dtbo overlays we tried (they don't work with the OOS 14 ABL; kept for reference).
- `config/` — phone-side services: `screen-idle/` (btop console, idle blank, power key), USB gadget fix.
- `scripts/` — building, RAM tests, promoting to `boot_a` (with backup and verification), diagnostics,
  phone setup. `scripts/experiments/touch/` — touchscreen bring-up experiments.
  Conventions: the project directory is `/srv/oneplus9pro-pmos` (set `P=` / edit to taste), the build
  host reaches the phone at `172.16.42.1` (USB) with `~/.ssh/id_ed25519_phone`, and scripts that need sudo
  on the phone read the password from `~/oneplus9pro-password.txt` on the host (never commit it).
  Some comments and messages in scripts are in Spanish.
- `docs/development-log.md` — the chronological bring-up notes.

## 7. Pending work
1. Touchscreen (see `docs/touchscreen.md`). Then wake-on-touch comes for free (screen-idle listens to all
   input devices).
2. USB-C hub with Ethernet (host mode + automatic Wi-Fi off when Ethernet is up are installed, untested).
3. Multi-day server soak; kernel updates as pmaports moves.
4. Nicer console graphics (a graphical terminal instead of fbcon), GPU workloads, modem (disabled).

## 8. Credits
- **Nia Espera** — the original OnePlus 9 / 9 Pro mainline device trees and the sm8350-mainline effort
  (gitlab.com/sm8350-mainline).
- The postmarketOS project (pmbootstrap, pmaports, the generic mainline kernel package), U-Boot, Mesa
  (Turnip/freedreno), and the Linux kernel community.
- Dmitry Baryshkov's ath11k WCN6855 hw1.1 series (sm8350-hdk), which our 0102 patch follows.
- linux-mdss-dsi-panel-driver-generator (lmdpdg), used to generate the AMB670YF01 panel driver from the
  vendor device tree.
- LineageOS (`android_kernel_oneplus_sm8350`) for the vendor sources used as reference.

## 9. License
- Kernel patches and device trees (`patches/kernel-tree/`, `patches/pmos-package/`, `patches/old-6.7/`,
  `dts/`): **GPL-2.0-only**, like the Linux kernel (`LICENSES/GPL-2.0`). U-Boot patch: GPL-2.0+ (U-Boot).
- Everything else (scripts, config, docs): **MIT** (`LICENSE`).
- No vendor firmware, partition images or device-specific data (MAC addresses, calibration) are included;
  `scripts/qca6490-fw-install.sh` extracts the Wi-Fi firmware from **your own** phone's partitions.
