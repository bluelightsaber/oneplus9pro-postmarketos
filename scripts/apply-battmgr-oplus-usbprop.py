#!/usr/bin/env python3
# qcom_battmgr (Linux 7.3, applied after apply-battmgr-behaviour-73.py): raw access to the USB
# properties of the OnePlus/Oplus ADSP charger firmware, for the USB host / OTG investigation.
# The Oplus firmware extends the USB property list (USB_OTG_AP_ENABLE = 14, USB_OTG_SWITCH = 15,
# USB_TYPEC_CC_ORIENTATION = 16, USB_TYPEC_MODE = 18 (0 DRP, 1 SNK, 2 SRC, 3 disabled),
# USB_TYPEC_SINKONLY = 19, USB_OTG_VBUS_REGULATOR_ENABLE = 20; see the vendor oplus_battery_sm8350.h).
# sysfs: /sys/bus/auxiliary/devices/pmic_glink.power-supply.0/oplus_usb_prop
#   echo N > oplus_usb_prop       read property N (7..63)
#   echo "N V" > oplus_usb_prop   write V to property N, then read it back
#   cat oplus_usb_prop            "N value" of the last access
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


# 1. state
sub("""	struct qcom_battmgr_wireless wireless;
""", """	struct qcom_battmgr_wireless wireless;

	/* raw Oplus USB property access (oplus_usb_prop sysfs attribute) */
	u32 oplus_prop;
	u32 oplus_value;
""")

# 2. USB property responses the driver does not know: keep the value instead of warning
sub("""		case USB_TYPE:
			battmgr->usb.usb_type = le32_to_cpu(resp->intval.value);
			break;
		default:
			dev_warn(battmgr->dev, "unknown property %#x\\n", property);
			break;
""", """		case USB_TYPE:
			battmgr->usb.usb_type = le32_to_cpu(resp->intval.value);
			break;
		default:
			battmgr->oplus_value = le32_to_cpu(resp->intval.value);
			break;
""", last=True)

# 3. acknowledge USB property writes
sub("""	case BATTMGR_BAT_PROPERTY_SET:
	case BATTMGR_REQUEST_NOTIFICATION:
""", """	case BATTMGR_BAT_PROPERTY_SET:
	case BATTMGR_USB_PROPERTY_SET:
	case BATTMGR_REQUEST_NOTIFICATION:
""")

# 4. sysfs attribute
sub("""static int qcom_battmgr_probe(struct auxiliary_device *adev,
""", """static ssize_t oplus_usb_prop_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct qcom_battmgr *battmgr = dev_get_drvdata(dev);

	return sysfs_emit(buf, "%u %u\\n", battmgr->oplus_prop, battmgr->oplus_value);
}

static ssize_t oplus_usb_prop_store(struct device *dev, struct device_attribute *attr,
				    const char *buf, size_t count)
{
	struct qcom_battmgr *battmgr = dev_get_drvdata(dev);
	u32 prop, val;
	int n, ret = 0;

	n = sscanf(buf, "%u %u", &prop, &val);
	/* 0..6 are parsed into the regular USB state by the callback */
	if (n < 1 || prop < 7 || prop > 63)
		return -EINVAL;

	mutex_lock(&battmgr->lock);
	if (n == 2)
		ret = qcom_battmgr_request_property(battmgr, BATTMGR_USB_PROPERTY_SET, prop, val);
	if (!ret) {
		battmgr->oplus_prop = prop;
		battmgr->oplus_value = U32_MAX;
		ret = qcom_battmgr_request_property(battmgr, BATTMGR_USB_PROPERTY_GET, prop, 0);
	}
	mutex_unlock(&battmgr->lock);

	return ret ? ret : count;
}
static DEVICE_ATTR_RW(oplus_usb_prop);

static struct attribute *qcom_battmgr_oplus_attrs[] = {
	&dev_attr_oplus_usb_prop.attr,
	NULL
};

static const struct attribute_group qcom_battmgr_oplus_group = {
	.attrs = qcom_battmgr_oplus_attrs,
};

static int qcom_battmgr_probe(struct auxiliary_device *adev,
""")

sub("""	battmgr->dev = dev;
""", """	battmgr->dev = dev;
	dev_set_drvdata(dev, battmgr);
""")

sub("""	pmic_glink_client_register(battmgr->client);

	return 0;
}""", """	if (battmgr->variant == QCOM_BATTMGR_SM8350) {
		ret = devm_device_add_group(dev, &qcom_battmgr_oplus_group);
		if (ret)
			return ret;
	}

	pmic_glink_client_register(battmgr->client);

	return 0;
}""")

open(path, "w").write(s)
print("oplus_usb_prop added")
