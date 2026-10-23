#!/usr/bin/env python3
# OnePlus 9 Pro: Bluetooth of the QCA6490/WCN6851 on UART18 (QUP SE18, 4 pins gpio68-71 with CTS/RTS, as in
# the vendor qupv3_se18_4uart), powered through the wcn6855-pmu like on the sm8350-hdk.
import sys, pathlib
d = pathlib.Path(sys.argv[1]) / "arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dts"; t = d.read_text()
if "qcom,wcn6855-bt" in t: print("bt already present"); sys.exit(0)
t = t.rstrip("\n") + '''

/* vendor qupv3_se18_4uart: CTS/RTS needed for the BT HCI UART */
&qup_uart18_default {
	pins = "gpio68", "gpio69", "gpio70", "gpio71";
};

&uart18 {
	status = "okay";

	bluetooth {
		compatible = "qcom,wcn6855-bt";

		vddrfacmn-supply = <&vreg_pmu_rfa_cmn_0p8>;
		vddaon-supply = <&vreg_pmu_aon_0p8>;
		vddwlcx-supply = <&vreg_pmu_wlcx_0p8>;
		vddwlmx-supply = <&vreg_pmu_wlmx_0p8>;
		vddbtcmx-supply = <&vreg_pmu_btcmx_0p8>;
		vddrfa0p8-supply = <&vreg_pmu_rfa_0p8>;
		vddrfa1p2-supply = <&vreg_pmu_rfa_1p2>;
		vddrfa1p7-supply = <&vreg_pmu_rfa_1p7>;

		max-speed = <3200000>;
	};
};
'''
d.write_text(t); print("bt nodes added")
