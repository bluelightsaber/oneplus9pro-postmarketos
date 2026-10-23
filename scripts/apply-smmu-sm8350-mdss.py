#!/usr/bin/env python3
# iommu/arm-smmu-qcom: add qcom,sm8350-mdss to qcom_smmu_client_of_match (identity default domain, like
# sm8150/sm8250/sm8450), otherwise the bootloader scanout faults once MDSS is enabled. Anchored.
import sys
p = sys.argv[1]; t = open(p).read()
if '"qcom,sm8350-mdss" },\n\t{ .compatible = "qcom,sm8450-mdss" }' in t: print("already"); sys.exit(0)
s = t.index("qcom_smmu_client_of_match[]")
a = '\t{ .compatible = "qcom,sm8450-mdss" },\n'
i = t.index(a, s)
t = t[:i] + '\t{ .compatible = "qcom,sm8350-mdss" },\n' + t[i:]
open(p, "w").write(t); print("patched", p)
