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

## Leads

- The vendor kernel programs a different HS PHY override sequence in host mode
  (`qcom,param-override-seq-host = <0xe7 0x6c 0x0c 0x70 0x17 0x74>` vs device
  `<0xe6 0x6c 0x0f 0x70 0x17 0x74>`); the mainline `phy-qcom-snps-femto-v2` driver has no host-specific
  sequence. The `-bp` properties may not map exactly to those raw values.
- On the vendor side, OTG VBUS is driven by the Oplus charger driver, not by the ADSP:
  `oplus,ext1-otg-en` (TLMM GPIO 8), `mps_otg_en` (PM8350C GPIO 1) and `op,vbus-ctrl-gpio`
  (PM8350C GPIO 7, active low). Mainline has none of these, which would explain the unpowered-hub
  result.
- The PMIC charger also uses D+/D− for charger detection; how it behaves while the phone is a
  sink *and* a host is unknown.
