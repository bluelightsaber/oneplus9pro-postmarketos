# USB host mode (OTG): status and investigation

**Status (2026-11-09): USB 2.0 host works with a powered USB-C hub** (patch 0105). USB 3 devices
behind the hub (its USB-A ports and integrated RJ45) are not visible yet, because only the USB 2 half
of the port is enabled. An unpowered hub still does not attach.

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

## Next: USB 3

The dwc3 node only has `usb2-phy` and `maximum-speed = "high-speed"`, and the QMP USB3/DP combo PHY is
not probed. Hub devices that sit on the USB 3 side (here: all USB-A ports and the RJ45) therefore do not
appear. Enabling USB 3 needs the combo PHY in the DT and orientation handling through pmic_glink.

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
