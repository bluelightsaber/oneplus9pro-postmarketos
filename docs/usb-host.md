# USB host mode (OTG): status and investigation

**Status (2026-11-13): USB 3 through a powered USB-C hub is in production**, on the stock
postmarketOS kernel package plus our patches, with DT changes only (`scripts/usb3-dt.sh` stage `c8`, now the default in
`scripts/build-pmos-image.sh`, `USB3=1`). The hub's VIA VL822 comes up at 10 Gbit/s, the RTL8153 RJ45
adapter at 5 Gbit/s (1000 Mbit/s Ethernet link) and a USB 3 stick at 5 Gbit/s, in both cable
orientations, and the hub charges the phone at the same time. Before promotion: automated RAM test,
a 15-minute soak and a hub check on the final image. USB 2 host with a powered hub works since patch
0105. An unpowered hub still does not attach.

The goal is a USB-C hub with Ethernet (and later a USB disk) while the hub also charges the phone.

## Root cause of the `-71` errors (fixed)

With a powered PD hub the phone became `host`, but the hub never enumerated:

```
usb 1-1: new full-speed USB device number 2 using xhci-hcd
usb 1-1: device descriptor read/64, error -71
usb usb1-port1: unable to enumerate USB device
```

Reading the HS PHY (snps femto v2 at `0x88e3000`, 8-bit registers at a 4-byte stride) in both modes
showed the difference:

| register | device mode (PC) | host mode (powered hub) |
|---|---|---|
| `USB2_PHY_USB_PHY_CFG0` (0x94) | 0x00 | **0x01** = `UTMI_PHY_DATAPATH_CTRL_OVERRIDE_EN` |
| `USB2_PHY_USB_PHY_UTMI_CTRL0` (0x3c) | 0x01 | **0x09** = `SLEEPM` \| `OPMODE_NONDRIVING` |

That is the charger-detection state: the UTMI datapath is overridden and D+/D− are left high-Z so the
charger can probe them (the vendor kernel exposes it as a "dpdm" regulator and turns it off again).
Mainline never writes these bits, so the charger firmware leaves them set after detecting the hub as
a power source. With the PHY in non-driving mode the host cannot send anything, so the hub only shows
its D+ pull-up (seen as full-speed) and never answers.

Clearing bit 0 of `CFG0` at runtime made the hub enumerate at once at high speed. **Patch 0105**
(`patches/pmos-package/0105-phy-qcom-snps-femto-v2-host-release-utmi-override.patch`, applied by
`scripts/apply-femto-host-override.py`) does it in the kernel: the femto v2 PHY gets a `.connect`
operation (called on every root-port connect) and a `set_mode(HOST)` hook that clear the override
when the PHY is in host mode. The kernel logs:

```
phy phy-88e3000.phy.1: host mode: releasing UTMI datapath override (non-driving)
usb 1-1: new high-speed USB device number 2 using xhci-hcd
usb 1-1: Product: USB 2.0 Hub
```

Test hub topology on USB 2: `1a40:0801` 4-port USB 2.0 hub → `2109:2822` VIA VL822 (USB 2 half,
5 ports) plus two billboard devices (`2109:0103`, `2109:8822`).

How it was found: the production kernel forces integrity lockdown, which blocks `/dev/mem`. A test
build without it (`scripts/update-pmos-kernel-lockoff.sh`, `CONFIG_LOCK_DOWN_KERNEL_FORCE_NONE`, RAM
boot only, never promoted) plus a tiny freestanding reader/writer (`scripts/rdmem.c`; dump script
`scripts/phydump.sh`) gave register access.

## USB 3

The original port's dwc3 node only has `usb2-phy`, `maximum-speed = "high-speed"` and
`qcom,select-utmi-as-pipe-clk` (its DT says "USB3 seems broken (though it's enabled downstream?)").
`scripts/usb3-dt.sh` applies the USB 3 changes to the DTB in stages (`scripts/build-usb3.sh <stage>`,
RAM boot with `scripts/try-usb3.sh <stage>`).

**Working recipe (stage `c8`):**
- QMP USB3/DP combo PHY (`phy@88e8000`) `okay`, `vdda-phy-supply` = **L1B** (0.88 V),
  `vdda-pll-supply` = **L6B** (1.2 V), as on sm8350-hdk/mtp;
- dwc3 `phys = <hsphy>, <qmpphy 0>`, `phy-names = "usb2-phy", "usb3-phy"`;
- no `qcom,select-utmi-as-pipe-clk` (the controller runs on the QMP pipe clock);
- **`maximum-speed = "super-speed-plus"`** (the vendor value);
- pmic-glink connector `port@1` (SS) ↔ QMP `port@0` graph, so pmic_glink_altmode passes the cable
  orientation to the PHY (`TYPEC_CTRL` follows the plug; both orientations tested).

| stage | change | result |
|---|---|---|
| — | QMP PHY with vdda-phy L6B / vdda-pll L5B | hard hang at boot: L1B, the PHY core supply, stays off |
| a | QMP PHY `okay`, vdda-phy L1B, vdda-pll L6B | boots, PHY probes |
| b | a + dwc3 `usb3-phy` | boots, 480 Mbit/s as expected |
| c1, c, c3, c6 | b + QMP pipe clock + `maximum-speed = "super-speed"` (± graph, interconnects, host-only) | **"hang"**: a dwc3 Oops, see below |
| c7 | c1 with `super-speed-plus` | boots |
| **c8** | c7 + orientation graph | **boots; USB 3 through the hub at 10/5 Gbit/s** |

**The "hang" was an Oops caused by `maximum-speed = "super-speed"`.** On a DWC_usb31 core with
`maximum_speed == USB_SPEED_SUPER`, `dwc3_core_init()` forces Gen1 by writing `LLUCTL` at offset
`0xd024`. sm8350.dtsi maps the dwc3 core with `reg = <0 0x0a600000 0 0xcd00>`, so the read faults
(`Unable to handle kernel paging request` in `dwc3_readl`). The Oops kills the deferred-probe
worker. Every later probe (Wi-Fi, …) stalls, and with the display driver loaded the phone freezes. It
looked like a hardware hang because pstore did not survive the forced reset.

It was found with a small debug service (`scripts/usb3dbg.service` + `scripts/usb3dbg-dump.sh`). The
service runs only when `usb3dbg` is on the kernel command line. It copies `dmesg` and the blocked tasks
(sysrq-w) to `/data` every few seconds, so the log survives the long-press reset. Blacklisting `msm`
for that run (`modprobe.blacklist=msm`) kept the phone alive long enough to write the log.

Other findings on the way:
- The gcc `clk_regmap_phy_mux` patch for the USB3 pipe clock source
  (`scripts/apply-gcc-sm8350-usb3-phy-mux.py`, test only) is **not needed**: c8 works on the
  unpatched production kernel.
- In device mode towards a PC the link still trains at 480 Mbit/s, although the PHY is ready
  (`PCS_STATUS1` PHYSTATUS clear, read with `scripts/qmpdump.sh`). This does not matter for the server
  use case.

## Unpowered hub (still open)

No Type-C partner attaches. The Oplus charger firmware sets `USB_TYPEC_MODE` to 1 (SNK) after a
detach, even with `USB_OTG_AP_ENABLE` and `USB_OTG_SWITCH` set to 1. Writing 0 (DRP) or 2 (SRC) is
acknowledged but ignored. On Android, a separate cc-detect interrupt makes the kernel switch to DRP;
property 27 (`USB_CCDETECT_HAPPENED`) does not exist in this firmware. The external VBUS boost is
likely needed too.

## The Oplus charger firmware

The ADSP charger firmware on this phone is Oplus-specific. Its USB property list (vendor
`drivers/power/oplus/charger_ic/oplus_battery_sm8350.h`, `enum usb_property_id`) matches mainline
only for ids 0–9:

| id | name | notes |
|---|---|---|
| 14 | `USB_OTG_AP_ENABLE` | 0 on mainline (the vendor kernel writes 1 at boot) |
| 15 | `USB_OTG_SWITCH` | Android's "OTG" toggle; the firmware clears it on detach |
| 16 | `USB_TYPEC_CC_ORIENTATION` | |
| 18 | `USB_TYPEC_MODE` | 0 = DRP (1 SNK, 2 SRC, 3 disabled); 1 after a detach |
| 19 | `USB_TYPEC_SINKONLY` | 0 |
| 20 | `USB_OTG_VBUS_REGULATOR_ENABLE` | 0 |

With a powered hub and 14/15 set to 1, the firmware sends `BC_OTG_ENABLE` (0x49) on attach.

Patch 0100 adds a sysfs attribute to read and write these properties:
`/sys/bus/auxiliary/devices/pmic_glink.power-supply.0/oplus_usb_prop`. `echo N >` reads property N,
`echo "N V" >` writes V and reads it back, and `cat` shows `N value`. It has a single slot, so read it
from one process at a time. `config/usb/oplus-otg.service` sets 14/15 at boot. It is not needed for the
powered hub, and its effect on the unpowered case is still open.

The vendor kernel also switches on an external VBUS boost for OTG on the firmware's 0x49
notification: PM8350C GPIO 6 (`wrx_en`), TLMM GPIO 8 (`ext1-otg-en`) and PM8350C GPIO 1
(`mps_otg_en`). **Do not drive these while a VBUS source is connected.**

## Ruled out along the way

- **Not the cause:**
  - plug orientation;
  - the `fsa4480` mux;
  - HS PHY tuning (`qcom,*-bp` properties);
  - PHY supply voltages and modes (L5B is in normal mode, L2B 3.072 V, L1C 1.8 V);
  - runtime role switching (`dr_mode = "host"` from boot fails the same way);
  - `usbcore.old_scheme_first`;
  - the Warp D+/D− switch (TLMM GPIO 47 in the USB position);
  - EUD (its enable register reads 0).
- **The hub itself:** it works on a laptop.
