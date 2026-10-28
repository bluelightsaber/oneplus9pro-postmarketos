# USB host mode (OTG): status and investigation

**Status: not working (2026-10-28).** The goal is a USB-C hub with Ethernet (and later a USB disk)
while the hub also charges the phone.

## What works

- Type-C role handling through UCSI (pmic_glink): towards a PC the phone is `device` (USB networking,
  SSH), towards a PD hub the hub requests a data-role swap and the phone becomes `host` while still
  being charged (`/sys/class/typec/port0`: data role host, power role sink).
- The xHCI controller comes up in host mode (one USB2 port, one USB3 port).

## What fails

**Powered PD hub** (hub on its own charger, works on a laptop, including Ethernet):

```
usb 1-1: new full-speed USB device number 2 using xhci-hcd
usb 1-1: device descriptor read/64, error -71
usb usb1-port1: attempt power cycle
usb usb1-port1: unable to enumerate USB device
```

The hub is seen as *full-speed* (the high-speed chirp handshake fails), and even full-speed descriptor
reads fail with `-EPROTO`. Nothing appears on the USB3 bus (USB3 is disabled in our DT, as in the
original sm8350-mainline port, so only the USB2 path is in use).

**Unpowered hub:** no Type-C partner is detected at all. The phone does not source VBUS and stays in
`device`/`sink`.

## Ruled out

| Test | Result |
|---|---|
| Flip the USB-C plug 180° | identical: not an orientation / mux problem |
| `fsa4480` registers | USB path enabled (`ENABLE` = 0x98) |
| HS PHY tuning via `qcom,*-bp` DT properties (squelch, HS amplitude, pre-emphasis, disconnect threshold, rise/fall, crossover, output impedance) roughly mirroring the vendor host override sequence | identical |
| DT differences with the original sm8350-mainline lemonadep port (which listed "USB incl. OTG") | none in the USB nodes |

## The Oplus charger firmware

The ADSP charger firmware on this phone is Oplus-specific. Its USB property list (vendor
`drivers/power/oplus/charger_ic/oplus_battery_sm8350.h`, `enum usb_property_id`) matches mainline
only for ids 0–9; from 10 on it has its own entries:

| id | name | value read on mainline (phone charging from a PC) |
|---|---|---|
| 14 | `USB_OTG_AP_ENABLE` | 0 (the vendor kernel writes 1 at boot) |
| 15 | `USB_OTG_SWITCH` | 0 (Android's "OTG" toggle) |
| 16 | `USB_TYPEC_CC_ORIENTATION` | 0 |
| 18 | `USB_TYPEC_MODE` | 0 = DRP (1 SNK, 2 SRC, 3 disabled) |
| 19 | `USB_TYPEC_SINKONLY` | 0 |
| 20 | `USB_OTG_VBUS_REGULATOR_ENABLE` | 0 |

Patch 0100 now adds a sysfs attribute to read and write them:
`/sys/bus/auxiliary/devices/pmic_glink.power-supply.0/oplus_usb_prop`
(`echo N >` reads property N, `echo "N V" >` writes V and reads it back, `cat` shows `N value`).

The port is already dual-role, so the firmware does not keep it sink-only. What mainline does not do,
compared with the vendor kernel:

1. write `USB_OTG_AP_ENABLE = 1` at boot and `USB_OTG_SWITCH = 1` when OTG is wanted
   (`config/usb/oplus-otg.service` does both; not yet tested with a device);
2. on the firmware's `BC_OTG_ENABLE` notification (0x49), switch on the **external VBUS boost**
   this wireless-charging phone uses for OTG: PM8350C GPIO 6 (`wrx_en`), TLMM GPIO 8
   (`ext1-otg-en`), and on some paths PM8350C GPIO 1 (`mps_otg_en`). This would explain why an
   unpowered hub never attaches. **Do not drive these while a VBUS source is connected.**

## Other leads

- The vendor HS PHY driver programs a different override sequence in host mode
  (`qcom,param-override-seq-host = <0xe7 0x6c 0x0c 0x70 0x17 0x74>` vs device
  `<0xe6 0x6c 0x0f 0x70 0x17 0x74>`). It only changes the HS disconnect threshold and TX amplitude,
  so it cannot explain why full-speed transfers fail too.
- The vendor PHY driver requests regulator loads (0.88 V 30 mA, 1.8 V 19 mA, 3.3 V 16 mA);
  mainline requests none, and the 0.88 V rail (L5B, `regulator-allow-set-load`) runs in LPM.
- Ruled out as well: the D+/D− switch towards the Warp fast-charge ASIC (TLMM GPIO 47 is in the
  normal/USB position, and device mode runs at 480 Mbit/s), and EUD (not enabled).
