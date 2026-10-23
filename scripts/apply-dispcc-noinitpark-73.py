#!/usr/bin/env python3
# dispcc-sm8250 (Linux 7.3, also serves sm8350): do not park the shared display RCGs at registration.
# Since "clk: qcom: rcg2: park shared RCGs upon registration", clk_rcg2_shared_ops moves the RCG to XO
# in .init. That cuts the MDP/AHB/rotator/vsync clocks of the display pipeline the bootloader left
# running (simple-framebuffer), the MDSS stalls and the whole boot dies right at
# disp_cc_sm8250_driver_init. Same approach as dispcc-sc8280xp: clk_rcg2_shared_no_init_park_ops.
import sys

path = sys.argv[1]
s = open(path).read()
for name in ("disp_cc_mdss_ahb_clk_src", "disp_cc_mdss_mdp_clk_src",
             "disp_cc_mdss_rot_clk_src", "disp_cc_mdss_vsync_clk_src"):
    i = s.index(f'.name = "{name}"')
    j = s.index(".ops = &clk_rcg2_shared_ops,", i)
    assert j - i < 300, f"ops not right after {name}"
    s = s[:j] + ".ops = &clk_rcg2_shared_no_init_park_ops," + s[j + len(".ops = &clk_rcg2_shared_ops,"):]
assert "clk_rcg2_shared_ops," not in s, "unexpected remaining shared ops"
open(path, "w").write(s)
print("patched", path)
