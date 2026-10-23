import sys, pathlib
d = pathlib.Path(sys.argv[1]) / "arch/arm64/boot/dts/qcom/sm8350-oneplus-lemonadep.dts"; t = d.read_text()
if "QCA6490 rails" in t: print("already"); sys.exit(0)
t = t.rstrip("\n") + '''

/*
 * QCA6490 rails: the common ranges let these sit at their minimum (pmr735a_s2 at 500 mV); the chip needs
 * the vendor cnss voltages. pmr735a_l7 feeds the RF front-end / antenna switch (always on, as on sm8350-hdk).
 */
&pm8350_s11 {
	regulator-min-microvolt = <952000>;
};

&pm8350_s12 {
	regulator-min-microvolt = <1352000>;
};

&pm8350c_s1 {
	regulator-min-microvolt = <1880000>;
};

&pmr735a_s2 {
	regulator-min-microvolt = <952000>;
};

&pmr735a_l7 {
	regulator-always-on;
	regulator-boot-on;
};
'''
d.write_text(t); print("rails added")
