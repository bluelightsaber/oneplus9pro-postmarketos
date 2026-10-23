#!/usr/bin/env python3
# OnePlus 9 Pro touchscreen: Synaptics S3908 (TCM oncell) driver by Frieder Hannenheim (sm8250-mainline MR 12,
# OnePlus 8T) + DT (vendor node synaptics@4B on qupv3_se4_i2c: irq gpio23 low, reset gpio22, 2v8 enable gpio31
# from L3C, 1v8 enable gpio197, 1440x3216). Usage: add-touch.py <kernel tree> <driver.c> [--no-dt]
import sys, pathlib, shutil
K = pathlib.Path(sys.argv[1]); drv = pathlib.Path(sys.argv[2]); no_dt = "--no-dt" in sys.argv
T = K / "drivers/input/touchscreen"
src = drv.read_text()
# 7.x: <linux/of_gpio.h> is gone; the driver only uses gpiod
src = src.replace("#include <linux/of_gpio.h>\n", "")
(T / "synaptics_tcm_oncell.c").write_text(src)
kc = T / "Kconfig"; t = kc.read_text()
if "TOUCHSCREEN_SYNAPTICS_TCM_ONCELL" not in t:
    a = "config TOUCHSCREEN_TS4800"
    assert a in t, "Kconfig anchor"
    t = t.replace(a, "config TOUCHSCREEN_SYNAPTICS_TCM_ONCELL\n\ttristate \"Synaptics TCM Oncell Touchscreen driver\"\n\tdepends on I2C\n\thelp\n\t  Say Y if you have the Synaptics S3908 TCM Oncell\n\n\t  If unsure, say N\n\n\t  To compile this driver as module, choose M here: the\n\t  module will be called synaptics_tcm_oncell.\n\n" + a, 1)
    kc.write_text(t)
mk = T / "Makefile"; t = mk.read_text()
if "synaptics_tcm_oncell" not in t:
    t = t.rstrip("\n") + "\nobj-$(CONFIG_TOUCHSCREEN_SYNAPTICS_TCM_ONCELL)\t+= synaptics_tcm_oncell.o\n"
    mk.write_text(t)
dt = K / "arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dts"
if not no_dt and dt.exists():
    t = dt.read_text()
    if "syna,s3908" not in t:
        t = t.replace('\tmodel = "OnePlus 9 Pro";\n', '''\tmodel = "OnePlus 9 Pro";

	ts_vdd_2v8: regulator-ts-vdd-2v8 {
		compatible = "regulator-fixed";
		regulator-name = "ts_vdd_2v8";
		regulator-min-microvolt = <2800000>;
		regulator-max-microvolt = <2800000>;
		gpio = <&tlmm 31 GPIO_ACTIVE_HIGH>;
		enable-active-high;
		vin-supply = <&pm8350c_l3>;
	};

	ts_vcc_1v8: regulator-ts-vcc-1v8 {
		compatible = "regulator-fixed";
		regulator-name = "ts_vcc_1v8";
		regulator-min-microvolt = <1800000>;
		regulator-max-microvolt = <1800000>;
		gpio = <&tlmm 197 GPIO_ACTIVE_HIGH>;
		enable-active-high;
	};
''', 1)
        t = t.rstrip("\n") + '''

&i2c4 {
	touchscreen@4b {
		compatible = "syna,s3908";
		reg = <0x4b>;

		interrupts-extended = <&tlmm 23 IRQ_TYPE_LEVEL_LOW>;
		reset-gpios = <&tlmm 22 GPIO_ACTIVE_HIGH>; /* driver leaves it at logical 1 = released */

		vdd-supply = <&ts_vdd_2v8>;
		vcc-supply = <&ts_vcc_1v8>;

		touchscreen-size-x = <1440>;
		touchscreen-size-y = <3216>;
	};
};
'''
        if "dt-bindings/interrupt-controller/irq.h" not in t and "IRQ_TYPE_LEVEL_LOW" in t:
            t = t.replace('#include "sm8350-oneplus-common.dtsi"', '#include <dt-bindings/interrupt-controller/irq.h>\n#include "sm8350-oneplus-common.dtsi"', 1)
        dt.write_text(t)
print("ok")
