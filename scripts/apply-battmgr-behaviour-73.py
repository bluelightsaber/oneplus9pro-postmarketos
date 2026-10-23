#!/usr/bin/env python3
# qcom_battmgr (Linux 7.3): add POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR (auto / inhibit-charge) for SM8350.
# The OnePlus 9 Pro ADSP firmware rejects BATTMGR_CHG_CTRL_LIMIT_EN (0x48, used by the mainline
# charge thresholds) but accepts BATTMGR_BAT_PROPERTY_SET of BATT_CHG_CTRL_EN, which enables or
# inhibits charging. A userspace service implements the 45-65 % hysteresis on top of it.
import sys

path = sys.argv[1]
s = open(path).read()


def sub(old, new, count=1, last=False):
    global s
    n = s.count(old)
    assert n >= 1, f"anchor not found:\n{old}"
    if last:
        i = s.rindex(old)
        s = s[:i] + new + s[i + len(old):]
    else:
        assert n == count, f"anchor found {n} times (expected {count}):\n{old}"
        s = s.replace(old, new)


# 1. cached state + writeable property
sub("""static int qcom_battmgr_bat_is_writeable(struct power_supply *psy,
					 enum power_supply_property psp)
{
	switch (psp) {
""", """static int qcom_battmgr_bat_is_writeable(struct power_supply *psy,
					 enum power_supply_property psp)
{
	switch (psp) {
	case POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR:
""")

# 2. set_property: BAT_PROPERTY_SET(BATT_CHG_CTRL_EN)
sub("""	switch (psp) {
	case POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD:
		return qcom_battmgr_set_charge_start_threshold(battmgr, pval->intval);
""", """	switch (psp) {
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
			qcom_battmgr_chg_behaviour = pval->intval;
		return ret;
	}
	case POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD:
		return qcom_battmgr_set_charge_start_threshold(battmgr, pval->intval);
""")

# 3. get_property: answer from the cache (declared before its first user)
sub("""static int qcom_battmgr_bat_get_property(struct power_supply *psy,
""", """/* single instance on this platform: last charge behaviour sent to the firmware */
static int qcom_battmgr_chg_behaviour = POWER_SUPPLY_CHARGE_BEHAVIOUR_AUTO;

static int qcom_battmgr_bat_get_property(struct power_supply *psy,
""")
sub("""	struct qcom_battmgr *battmgr = power_supply_get_drvdata(psy);
	enum qcom_battmgr_unit unit = battmgr->unit;
	int ret;

	if (!battmgr->service_up)
		return -EAGAIN;

	if (battmgr->variant == QCOM_BATTMGR_SC8280XP ||
	    battmgr->variant == QCOM_BATTMGR_X1E80100)
		ret = qcom_battmgr_bat_sc8280xp_update(battmgr, psp);
""", """	struct qcom_battmgr *battmgr = power_supply_get_drvdata(psy);
	enum qcom_battmgr_unit unit = battmgr->unit;
	int ret;

	if (!battmgr->service_up)
		return -EAGAIN;

	if (psp == POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR) {
		val->intval = qcom_battmgr_chg_behaviour;
		return 0;
	}

	if (battmgr->variant == QCOM_BATTMGR_SC8280XP ||
	    battmgr->variant == QCOM_BATTMGR_X1E80100)
		ret = qcom_battmgr_bat_sc8280xp_update(battmgr, psp);
""")

# 4. SM8350 property list + desc
sub("""	POWER_SUPPLY_PROP_POWER_NOW,
};

static const struct power_supply_desc sm8350_bat_psy_desc = {
	.name = "qcom-battmgr-bat",
	.type = POWER_SUPPLY_TYPE_BATTERY,
	.properties = sm8350_bat_props,
	.num_properties = ARRAY_SIZE(sm8350_bat_props),
	.get_property = qcom_battmgr_bat_get_property,
};
""", """	POWER_SUPPLY_PROP_POWER_NOW,
	POWER_SUPPLY_PROP_CHARGE_BEHAVIOUR,
};

static const struct power_supply_desc sm8350_bat_psy_desc = {
	.name = "qcom-battmgr-bat",
	.type = POWER_SUPPLY_TYPE_BATTERY,
	.properties = sm8350_bat_props,
	.num_properties = ARRAY_SIZE(sm8350_bat_props),
	.get_property = qcom_battmgr_bat_get_property,
	.set_property = qcom_battmgr_bat_set_property,
	.property_is_writeable = qcom_battmgr_bat_is_writeable,
	.charge_behaviours = BIT(POWER_SUPPLY_CHARGE_BEHAVIOUR_AUTO) |
			     BIT(POWER_SUPPLY_CHARGE_BEHAVIOUR_INHIBIT_CHARGE),
};
""")

# 5. SM8350 callback (the last one in the file): acknowledge BAT_PROPERTY_SET
sub("""	case BATTMGR_REQUEST_NOTIFICATION:
	case BATTMGR_CHG_CTRL_LIMIT_EN:
		battmgr->error = 0;
		break;
""", """	case BATTMGR_BAT_PROPERTY_SET:
	case BATTMGR_REQUEST_NOTIFICATION:
	case BATTMGR_CHG_CTRL_LIMIT_EN:
		battmgr->error = 0;
		break;
""", last=True)

open(path, "w").write(s)
print("patched", path)
