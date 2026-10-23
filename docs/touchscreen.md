# Touchscreen (Synaptics S3908) — status: not working yet

The OnePlus 9 Pro uses an on-cell Synaptics **S3908** (TouchComm protocol, not RMI4) at I2C address
**0x4b** on **QUP SE4 (`i2c4`, 0x990000)**, pins gpio20 (SDA) / gpio21 (SCL). Touch works on Android, so
this is a software/power-sequencing problem.

## What the vendor kernel does (stock `dtbo_a`, overlay "lemonadep", and LineageOS sources)
- Node `synaptics@4B` (`synaptics-s3908`) on `qupv3_se4_i2c`: irq gpio23, reset gpio22,
  `enable2v8_gpio` = gpio31 (with `vdd_2v8-supply` = L3C at 3.008 V), `enable1v8_gpio` = gpio197
  (`vcc_1v8-supply` commented out). Power-on order: AVDD → VDDI → delay → reset high → delay.
- The same bus also carries `tof8801@41` (laser AF; supply pm8008i L3, enable gpio126).
- `&sdhc_2` is disabled under `OPLUS_FEATURE_TP_BASIC` (SD controller supplies L9C/L6C on the MTP base).

## What we have
- Driver: `synaptics_tcm_oncell.c` from the sm8250-mainline MR 12 (adapted to 7.x), DT node
  `syna,s3908`, fixed regulators for gpio31/gpio197 (`scripts/experiments/touch/add-touch.py`).
  The driver probes but every I2C transfer times out.

## Findings
With every rail forced on and reset released, **SDA and SCL read 0 V** (validated: the working `i2c13`
pins read high with the same method). Ruled out, one by one (RAM-booted test kernels, `fdtput` DT edits):
- GENI/GPI: a bit-banged `i2c-gpio` bus on gpio20/21 with GENI disabled sees the same (all NACK).
- Rails L3C, L8C (MTP touch I2C rail), L6C (forced 1.8 V), L9C always-on; gpio31/gpio197 high with
  2 mA and 16 mA drive + pull-up; reset sequence as the vendor's (from userspace with `gpioset`).
- The ToF and its PMIC: pm8008i (i2c13 0x08/0x09, enable gpio33) answers; enabling its L3 by hand +
  gpio126 changes nothing.
- The panel: the touch IC stays silent with the panel on (real panel driver) or left on by the bootloader.

Conclusion so far: something outside the SoC holds the bus low — most likely the touch side is not really
powered. Next step: boot the LineageOS recovery in RAM (its kernel matches the LineageOS `vendor_boot`
already on slot a) and read the real pin/regulator/PMIC state while touch works there.

Gotchas: `fdtput` writes `0x7f01` as 0 (use decimal phandles); a pin state with `function` on a
regulator's own enable GPIO makes the regulator fail to probe; libgpiod bias flags are not applied by this
pinctrl (do not use `gpioget -b` for pad tests); `#` inside a shell-quoted fdtput chain starts a comment.
