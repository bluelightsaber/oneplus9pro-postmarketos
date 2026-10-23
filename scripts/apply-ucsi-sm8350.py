"""pmic_glink 6.7: crear también el cliente UCSI (USB-C, roles host/dispositivo) en SM8350,
como hace mainline 7.x para todos los SoC con la entrada genérica."""
import sys
p = sys.argv[1]
s = open(p).read()
if '"qcom,sm8350-pmic-glink"' in s:
    print("ya aplicado"); sys.exit(0)
old = '\t{ .compatible = "qcom,sm8450-pmic-glink", .data = &pmic_glink_sm8450_client_mask },\n'
assert old in s
s = s.replace(old, '\t{ .compatible = "qcom,sm8350-pmic-glink", .data = &pmic_glink_sm8450_client_mask },\n' + old, 1)
open(p, "w").write(s)
print("UCSI para sm8350 aplicado")
