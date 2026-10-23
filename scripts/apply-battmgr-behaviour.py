"""Añade charge_behaviour (auto / inhibit-charge) a qcom_battmgr 6.7 (variante SM8350), usando
BATTMGR_BAT_PROPERTY_SET sobre BATT_CHG_CTRL_EN. Requiere apply-battmgr-thresholds.py aplicado antes."""
import sys
p = sys.argv[1]
s = open(p).read()
if "chg_behaviour" in s:
    print("ya aplicado"); sys.exit(0)

def rep(old, new):
    global s
    assert old in s, old[:70]
    s = s.replace(old, new, 1)

if "#define BATT_CHG_CTRL_EN" not in s:
    rep("#define BATT_CHG_CTRL_LIM_MAX\t\t11\n", "#define BATT_CHG_CTRL_LIM_MAX\t\t11\n#define BATT_CHG_CTRL_EN\t\t24\n")

rep("static int chg_ctrl_end = CHARGE_CTRL_END_THR_MAX;\n",
    "static int chg_ctrl_end = CHARGE_CTRL_END_THR_MAX;\n"
    "static int chg_behaviour = POWER_SUPPLY_CHARGE_BEHAVIOUR_AUTO;\n")

rep("""	return psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD ||
	       psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD;""",
    """	return psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD ||
	       psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD ||
	       psp == POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR;""")

rep("""	switch (psp) {
	case POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD:
		start = clamp(""",
    """	switch (psp) {
	case POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR: {
		int ret;

		if (pval->intval != POWER_SUPPLY_CHARGE_BEHAVIOUR_AUTO &&
		    pval->intval != POWER_SUPPLY_CHARGE_BEHAVIOUR_INHIBIT_CHARGE)
			return -EINVAL;
		mutex_lock(&battmgr->lock);
		ret = qcom_battmgr_request_property(battmgr, BATTMGR_BAT_PROPERTY_SET,
						    BATT_CHG_CTRL_EN,
						    pval->intval == POWER_SUPPLY_CHARGE_BEHAVIOUR_AUTO);
		mutex_unlock(&battmgr->lock);
		if (!ret)
			chg_behaviour = pval->intval;
		return ret;
	}
	case POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD:
		start = clamp(""")

rep("""	if (psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD) {
		val->intval = chg_ctrl_end;
		return 0;
	}
""",
    """	if (psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD) {
		val->intval = chg_ctrl_end;
		return 0;
	}
	if (psp == POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR) {
		val->intval = chg_behaviour;
		return 0;
	}
""")

rep("\n\tPOWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD,",
    "\n\tPOWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD,\n\tPOWER_SUPPLY_PROP_CHARGE_BEHAVIOUR,")

# la respuesta a BAT_PROPERTY_SET debe completar la petición (segunda aparición = callback sm8350)
marker = "\tcase BATTMGR_REQUEST_NOTIFICATION:\n\tcase BATTMGR_CHG_CTRL_LIMIT_EN:\n"
i = s.rfind(marker)
assert i >= 0
s = s[:i] + "\tcase BATTMGR_BAT_PROPERTY_SET:\n" + s[i:]

open(p, "w").write(s)
print("charge_behaviour aplicado")
