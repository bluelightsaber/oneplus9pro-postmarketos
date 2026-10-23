#!/usr/bin/env python3
# OnePlus 9 Pro: QCA6490 (WCN6855-compatible) Wi-Fi on PCIe0 via pwrseq-qcom-wcn, and fix the PCIe0 pinctrl
# (gpio95 was listed twice in the default state: clkreq function + a "sleep-pins" gpio entry -> -EINVAL).
import sys, pathlib, re
K = pathlib.Path(sys.argv[1]) / "arch/arm64/boot/dts/qcom"
c = (K / "sm8350-oneplus-common.dtsi"); t = c.read_text()
t2, n = re.subn(r"\n\t\tsleep-pins \{\n\t\t\tpins = \"gpio95\";\n\t\t\tfunction = \"gpio\";\n\t\t\tdrive-strength = <2>;\n\t\t\tbias-pull-up;\n\t\t\};\n", "\n", t)
if n == 1: c.write_text(t2); print("pcie0 sleep-pins removed")
elif "sleep-pins" not in t: print("pcie0 sleep-pins already gone")
else: sys.exit("sleep-pins block not matched")
d = (K / "sm8350-oneplus-lemonadep.dts"); t = d.read_text()
if "wcn6855-pmu" in t: print("wifi already present"); sys.exit(0)
regs = ["rfa_cmn_0p8", "aon_0p8", "wlcx_0p8", "wlmx_0p8", "btcmx_0p8", "pcie_1p8", "pcie_0p9", "rfa_0p8", "rfa_1p2", "rfa_1p7"]
ldos = "".join(f"\n\t\t\tvreg_pmu_{r}: ldo{i} {{\n\t\t\t\tregulator-name = \"vreg_pmu_{r}\";\n\t\t\t}};\n" for i, r in enumerate(regs))
t = t.replace('\tmodel = "OnePlus 9 Pro";\n', '''\tmodel = "OnePlus 9 Pro";

	/* QCA6490 Wi-Fi/BT, WCN6855-compatible; supplies and GPIOs from the vendor cnss/bt nodes */
	wcn6855-pmu {
		compatible = "qcom,wcn6855-pmu";

		pinctrl-0 = <&bt_en>, <&wlan_en>;
		pinctrl-names = "default";

		wlan-enable-gpios = <&tlmm 64 GPIO_ACTIVE_HIGH>;
		bt-enable-gpios = <&tlmm 65 GPIO_ACTIVE_HIGH>;
		swctrl-gpios = <&tlmm 153 GPIO_ACTIVE_HIGH>;

		vddio-supply = <&pm8350_s10>;
		vddaon-supply = <&pm8350_s11>;
		vddpmu-supply = <&pm8350_s12>;
		vddpmumx-supply = <&pmr735a_s2>;
		vddpmucx-supply = <&pm8350_s11>;
		vddrfa0p95-supply = <&pm8350_s11>;
		vddrfa1p3-supply = <&pm8350_s12>;
		vddrfa1p9-supply = <&pm8350c_s1>;
		vddpcie1p3-supply = <&pm8350_s12>;
		vddpcie1p9-supply = <&pm8350c_s1>;

		regulators {''' + ldos + '''		};
	};
''', 1)
t = t.rstrip("\n") + '''

&{/soc@0/pcie@1c00000/pcie@0} {
	wifi@0 {
		compatible = "pci17cb,1103";
		reg = <0x10000 0x0 0x0 0x0 0x0>;

		vddrfacmn-supply = <&vreg_pmu_rfa_cmn_0p8>;
		vddaon-supply = <&vreg_pmu_aon_0p8>;
		vddwlcx-supply = <&vreg_pmu_wlcx_0p8>;
		vddwlmx-supply = <&vreg_pmu_wlmx_0p8>;
		vddpcie1p8-supply = <&vreg_pmu_pcie_1p8>;
		vddpcie0p9-supply = <&vreg_pmu_pcie_0p9>;
		vddrfa0p8-supply = <&vreg_pmu_rfa_0p8>;
		vddrfa1p2-supply = <&vreg_pmu_rfa_1p2>;
		vddrfa1p8-supply = <&vreg_pmu_rfa_1p7>;
	};
};

&tlmm {
	bt_en: bt-en-state {
		pins = "gpio65";
		function = "gpio";
		drive-strength = <16>;
		output-low;
		bias-pull-down;
	};

	wlan_en: wlan-en-state {
		pins = "gpio64";
		function = "gpio";
		drive-strength = <16>;
		output-low;
		bias-pull-down;
	};
};
'''
d.write_text(t); print("wifi nodes added")
