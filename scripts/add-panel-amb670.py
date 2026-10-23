#!/usr/bin/env python3
# Add the lmdpdg-generated Samsung AMB670YF01 (OnePlus 9 Pro) panel driver + DT to the 7.3 tree.
import re, sys, pathlib
K = pathlib.Path(sys.argv[1]); gen = pathlib.Path(sys.argv[2])
c = gen.read_text()
def rep(a, b, n=1):
    global c
    if a not in c: sys.exit("driver anchor not found: " + a[:60])
    c = c.replace(a, b, n)
rep("// Copyright (c) 2026 FIXME\n", "// Copyright (c) 2026 OnePlus 9 Pro (lemonadep) mainline port, made with AI assistance\n")
rep("//   Copyright (c) 2013, The Linux Foundation. All rights reserved. (FIXME)\n",
    "//   Copyright (c) 2013, The Linux Foundation. All rights reserved.\n"
    "// Changes: the vendor PPS (DCS 0x9e) is not sent from the init sequence; the PPS computed by the\n"
    "// kernel from ctx->dsc (the one the DPU encoder uses) is sent instead, and dumped to dmesg.\n")
# drop the vendor PPS write (0x9e ...); keep 0x9d 0x01 (Samsung compression enable)
c, n = re.subn(r"\tmipi_dsi_dcs_write_seq_multi\(&dsi_ctx, 0x9e,\n(\t+ +.*\n)+?(?=\tmipi_dsi_dcs_write_seq_multi\(&dsi_ctx, 0x9d)", "", c)
if n != 1: sys.exit("vendor PPS block not removed")
rep("\tdrm_dsc_pps_payload_pack(&pps, &ctx->dsc);\n",
    "\tdrm_dsc_pps_payload_pack(&pps, &ctx->dsc);\n"
    "\tprint_hex_dump(KERN_INFO, \"amb670yf01 pps: \", DUMP_PREFIX_OFFSET, 16, 1, &pps, sizeof(pps), false);\n")
rep('{ .compatible = "samsung,amb670yf01-dsc" }, // FIXME', '{ .compatible = "samsung,amb670yf01" },')
rep('MODULE_AUTHOR("linux-mdss-dsi-panel-driver-generator <fix@me>"); // FIXME', 'MODULE_AUTHOR("OnePlus 9 Pro mainline port");')
rep("#include <linux/module.h>\n", "#include <linux/module.h>\n#include <linux/printk.h>\n")
(K / "drivers/gpu/drm/panel/panel-samsung-amb670yf01.c").write_text(c)

kc = K / "drivers/gpu/drm/panel/Kconfig"; t = kc.read_text()
if "DRM_PANEL_SAMSUNG_AMB670YF01" not in t:
    a = "config DRM_PANEL_SAMSUNG_S6E3FA7\n"
    if a not in t: sys.exit("Kconfig anchor")
    t = t.replace(a, "config DRM_PANEL_SAMSUNG_AMB670YF01\n"
        "\ttristate \"Samsung AMB670YF01 DSI DSC command mode panel\"\n"
        "\tdepends on OF\n\tdepends on DRM_MIPI_DSI\n\tdepends on BACKLIGHT_CLASS_DEVICE\n"
        "\tselect DRM_DISPLAY_DSC_HELPER\n\tselect DRM_DISPLAY_HELPER\n"
        "\thelp\n\t  Say Y or M here if you want to enable support for the Samsung\n"
        "\t  AMB670YF01 1080x2412 DSC command mode panel (OnePlus 9 Pro).\n\n" + a, 1)
    kc.write_text(t)
mk = K / "drivers/gpu/drm/panel/Makefile"; t = mk.read_text()
if "panel-samsung-amb670yf01" not in t:
    a = "obj-$(CONFIG_DRM_PANEL_SAMSUNG_S6E3FA7)"
    if a not in t: sys.exit("Makefile anchor")
    t = t.replace(a, "obj-$(CONFIG_DRM_PANEL_SAMSUNG_AMB670YF01) += panel-samsung-amb670yf01.o\n" + a, 1)
    mk.write_text(t)

dt = K / "arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dts"
t = dt.read_text() if dt.exists() else "amb670yf01 (no lemonadep DTS in this tree: driver only)"
if "amb670yf01" not in t:
    t = t.rstrip("\n") + """

&mdss {
	status = "okay";
};

&mdss_dsi0 {
	vdda-supply = <&pm8350_l6>;
	status = "okay";

	panel@0 {
		compatible = "samsung,amb670yf01";
		reg = <0>;

		vddio-supply = <&pm8350c_l12>;
		vci-supply = <&pm8350c_l13>;
		reset-gpios = <&tlmm 24 GPIO_ACTIVE_LOW>;

		pinctrl-0 = <&panel_reset_n &mdp_vsync_active>;
		pinctrl-names = "default";

		port {
			panel_in: endpoint {
				remote-endpoint = <&mdss_dsi0_out>;
			};
		};
	};
};

&mdss_dsi0_out {
	remote-endpoint = <&panel_in>;
	data-lanes = <0 1 2 3>;
};

&mdss_dsi0_phy {
	vdds-supply = <&pm8350_l5>;
	status = "okay";
};

&tlmm {
	panel_reset_n: panel-reset-n-state {
		pins = "gpio24";
		function = "gpio";
		drive-strength = <8>;
		bias-disable;
	};

	mdp_vsync_active: mdp-vsync-active-state {
		pins = "gpio82";
		function = "mdp_vsync";
		drive-strength = <2>;
		bias-pull-down;
	};
};
"""
    if "#include <dt-bindings/gpio/gpio.h>" not in t and "gpio.h" not in (K / "arch/arm64/boot/dts/qcom/sm8350-oneplus-common.dtsi").read_text():
        t = t.replace('#include "sm8350-oneplus-common.dtsi"', '#include <dt-bindings/gpio/gpio.h>\n#include "sm8350-oneplus-common.dtsi"', 1)
    dt.write_text(t)
print("ok")
