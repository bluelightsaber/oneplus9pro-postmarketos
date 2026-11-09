#!/usr/bin/env python3
# phy-qcom-snps-femto-v2: in host mode, drop the UTMI datapath override (CFG0 bit0) that the charger firmware
# leaves set after charger detection (UTMI_CTRL0 = non-driving) -> host cannot talk to the attached device (-71).
# Cleared on set_mode(HOST) and on every root-port connect notification.
import sys
p = sys.argv[1]; s = open(p).read()
if 'qcom_snps_hsphy_release_utmi' in s:
    print("already patched"); sys.exit(0)
old_set = '''	hsphy->mode = mode;
	return 0;
}
'''
assert s.count(old_set) == 1, "set_mode anchor"
helper = '''static void qcom_snps_hsphy_release_utmi(struct qcom_snps_hsphy *hsphy)
{
	if (!hsphy->phy_initialized)
		return;

	if (readl_relaxed(hsphy->base + USB2_PHY_USB_PHY_CFG0) & UTMI_PHY_DATAPATH_CTRL_OVERRIDE_EN) {
		dev_info(&hsphy->phy->dev, "host mode: releasing UTMI datapath override (non-driving)\\n");
		qcom_snps_hsphy_write_mask(hsphy->base, USB2_PHY_USB_PHY_CFG0,
					   UTMI_PHY_DATAPATH_CTRL_OVERRIDE_EN, 0);
	}
}

'''
new_set = '''	hsphy->mode = mode;
	if (mode == PHY_MODE_USB_HOST)
		qcom_snps_hsphy_release_utmi(hsphy);
	return 0;
}

static int qcom_snps_hsphy_connect(struct phy *phy, int port)
{
	struct qcom_snps_hsphy *hsphy = phy_get_drvdata(phy);

	if (hsphy->mode == PHY_MODE_USB_HOST)
		qcom_snps_hsphy_release_utmi(hsphy);
	return 0;
}
'''
s = s.replace(old_set, new_set)
anchor = 'static int qcom_snps_hsphy_set_mode(struct phy *phy, enum phy_mode mode,'
assert s.count(anchor) == 1, "set_mode decl"
s = s.replace(anchor, helper + anchor)
old_ops = '''	.set_mode	= qcom_snps_hsphy_set_mode,
	.owner		= THIS_MODULE,'''
assert s.count(old_ops) == 1, "ops anchor"
s = s.replace(old_ops, '''	.set_mode	= qcom_snps_hsphy_set_mode,
	.connect	= qcom_snps_hsphy_connect,
	.owner		= THIS_MODULE,''')
open(p, 'w').write(s); print("patched", p)
