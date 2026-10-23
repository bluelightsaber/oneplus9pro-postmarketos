"""Backport mínimo de los umbrales de carga (charge_control_start/end_threshold) de qcom_battmgr
de Linux 7.3 al driver 6.7, solo para la variante SM8350 (OnePlus 9 Pro).
Usa la orden BATTMGR_CHG_CTRL_LIMIT_EN (0x48): target_soc = fin, delta_soc = fin - inicio."""
import sys
p = sys.argv[1]
s = open(p).read()
if "BATTMGR_CHG_CTRL_LIMIT_EN" in s:
    print("ya aplicado"); sys.exit(0)

def rep(old, new):
    global s
    assert old in s, old[:60]
    s = s.replace(old, new, 1)

# 1) definiciones y estructura de la petición
rep("#define BATTMGR_REQUEST_NOTIFICATION\t0x4\n",
    "#define BATTMGR_REQUEST_NOTIFICATION\t0x4\n"
    "#define BATTMGR_CHG_CTRL_LIMIT_EN\t0x48\n"
    "#define CHARGE_CTRL_START_THR_MIN\t40\n"
    "#define CHARGE_CTRL_START_THR_MAX\t95\n"
    "#define CHARGE_CTRL_END_THR_MIN\t\t50\n"
    "#define CHARGE_CTRL_END_THR_MAX\t\t100\n")

# 2) funciones de umbral, antes de get_property
anchor = "static int qcom_battmgr_bat_get_property(struct power_supply *psy,"
code = r'''struct qcom_battmgr_charge_ctrl_request {
	struct pmic_glink_hdr hdr;
	__le32 enable;
	__le32 target_soc;
	__le32 delta_soc;
};

/* single instance on this platform: keep the last thresholds sent to the firmware */
static int chg_ctrl_start = CHARGE_CTRL_START_THR_MIN;
static int chg_ctrl_end = CHARGE_CTRL_END_THR_MAX;

static int qcom_battmgr_set_charge_control(struct qcom_battmgr *battmgr, int start, int end)
{
	struct qcom_battmgr_charge_ctrl_request request = {
		.hdr.owner = cpu_to_le32(PMIC_GLINK_OWNER_BATTMGR),
		.hdr.type = cpu_to_le32(PMIC_GLINK_REQ_RESP),
		.hdr.opcode = cpu_to_le32(BATTMGR_CHG_CTRL_LIMIT_EN),
		.enable = cpu_to_le32(1),
		.target_soc = cpu_to_le32(end),
		.delta_soc = cpu_to_le32(end - start),
	};
	int ret;

	mutex_lock(&battmgr->lock);
	ret = qcom_battmgr_request(battmgr, &request, sizeof(request));
	mutex_unlock(&battmgr->lock);
	if (!ret) {
		chg_ctrl_start = start;
		chg_ctrl_end = end;
	}
	return ret;
}

static int qcom_battmgr_bat_is_writeable(struct power_supply *psy,
					 enum power_supply_property psp)
{
	return psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD ||
	       psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD;
}

static int qcom_battmgr_bat_set_property(struct power_supply *psy,
					 enum power_supply_property psp,
					 const union power_supply_propval *pval)
{
	struct qcom_battmgr *battmgr = power_supply_get_drvdata(psy);
	int start = chg_ctrl_start, end = chg_ctrl_end;

	if (!battmgr->service_up)
		return -EAGAIN;

	switch (psp) {
	case POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD:
		start = clamp(pval->intval, CHARGE_CTRL_START_THR_MIN, CHARGE_CTRL_START_THR_MAX);
		if (end <= start)
			end = min(start + 5, CHARGE_CTRL_END_THR_MAX);
		break;
	case POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD:
		end = clamp(pval->intval, CHARGE_CTRL_END_THR_MIN, CHARGE_CTRL_END_THR_MAX);
		if (start >= end)
			start = max(end - 5, CHARGE_CTRL_START_THR_MIN);
		break;
	default:
		return -EINVAL;
	}
	return qcom_battmgr_set_charge_control(battmgr, start, end);
}

'''
rep(anchor, code + anchor)

# 3) get_property: devolver los umbrales guardados
rep("""	if (!battmgr->service_up)
		return -ENODEV;

	if (battmgr->variant == QCOM_BATTMGR_SC8280XP)
		ret = qcom_battmgr_bat_sc8280xp_update(battmgr, psp);""",
    """	if (!battmgr->service_up)
		return -ENODEV;

	if (psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD) {
		val->intval = chg_ctrl_start;
		return 0;
	}
	if (psp == POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD) {
		val->intval = chg_ctrl_end;
		return 0;
	}

	if (battmgr->variant == QCOM_BATTMGR_SC8280XP)
		ret = qcom_battmgr_bat_sc8280xp_update(battmgr, psp);""")

# 4) propiedades y callbacks en la descripción sm8350 (búsqueda por estructura, no por texto exacto)
i = s.index("static const enum power_supply_property sm8350_bat_props[] = {")
j = s.index("\n};", i)
s = s[:j] + ("\n\tPOWER_SUPPLY_PROP_CHARGE_CONTROL_START_THRESHOLD,"
             "\n\tPOWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD,") + s[j:]
i = s.index("static const struct power_supply_desc sm8350_bat_psy_desc = {")
g = "\t.get_property = qcom_battmgr_bat_get_property,\n"
j = s.index(g, i) + len(g)
assert j < s.index("\n};", i) + 3
s = s[:j] + ("\t.set_property = qcom_battmgr_bat_set_property,\n"
             "\t.property_is_writeable = qcom_battmgr_bat_is_writeable,\n") + s[j:]

# 5) respuesta del firmware a la orden 0x48 (en el callback sm8350: segunda aparición)
marker = """	case BATTMGR_REQUEST_NOTIFICATION:
		battmgr->error = 0;
		break;
	default:
		dev_warn(battmgr->dev, "unknown message %#x\\n", opcode);"""
i = s.rfind(marker)
assert i >= 0
s = s[:i] + marker.replace("	case BATTMGR_REQUEST_NOTIFICATION:\n", "	case BATTMGR_REQUEST_NOTIFICATION:\n	case BATTMGR_CHG_CTRL_LIMIT_EN:\n", 1) + s[i + len(marker):]

open(p, "w").write(s)
print("parche de umbrales aplicado")
