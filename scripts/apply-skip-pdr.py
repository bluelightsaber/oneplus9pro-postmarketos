import sys
p = sys.argv[1]
s = open(p).read()
if "skip_pdr" in s:
    print("ya aplicado"); sys.exit(0)
anchor = "static int pmic_glink_rpmsg_probe(struct rpmsg_device *rpdev)\n{"
param = ('/* OnePlus 9 Pro: the ADSP firmware does not seem to announce charger_pd over PDR */\n'
         'static bool skip_pdr;\n'
         'module_param(skip_pdr, bool, 0444);\n'
         'MODULE_PARM_DESC(skip_pdr, "Consider the service up as soon as the GLINK channel exists");\n\n')
assert anchor in s
s = s.replace(anchor, param + anchor, 1)
old = "\tpg->ept = rpdev->ept;\n\tpmic_glink_state_notify_clients(pg);"
new = ("\tpg->ept = rpdev->ept;\n"
       "\tif (skip_pdr)\n"
       "\t\tpg->pdr_state = SERVREG_SERVICE_STATE_UP;\n"
       "\tpmic_glink_state_notify_clients(pg);")
assert old in s
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("parche aplicado")
