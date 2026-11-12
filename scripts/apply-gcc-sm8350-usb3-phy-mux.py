#!/usr/bin/env python3
"""gcc-sm8350: model the USB3 primary PHY pipe clock source as a clk_regmap_phy_mux.

The downstream (vendor) QMP driver parks GCC_USB3_PRIM_PHY_PIPE_CLK_SRC on XO whenever the PHY pipe
clock is off and selects the PHY pipe clock only while the PHY is running. Mainline sm8350 uses a plain
clk_regmap_mux, which leaves the mux on the PHY source while the PHY is powered down. clk_regmap_phy_mux
does what downstream does (enable -> PHY source, disable -> XO). TEST patch for the USB 3 bring-up.
Usage: apply-gcc-sm8350-usb3-phy-mux.py drivers/clk/qcom/gcc-sm8350.c
"""
import sys

path = sys.argv[1]
s = open(path).read()

old = """static struct clk_regmap_mux gcc_usb3_prim_phy_pipe_clk_src = {
	.reg = 0xf060,
	.shift = 0,
	.width = 2,
	.parent_map = gcc_parent_map_13,
	.clkr = {
		.hw.init = &(struct clk_init_data){
			.name = "gcc_usb3_prim_phy_pipe_clk_src",
			.parent_data = gcc_parent_data_13,
			.num_parents = ARRAY_SIZE(gcc_parent_data_13),
			.ops = &clk_regmap_mux_closest_ops,
		},
	},
};
"""
new = """static struct clk_regmap_phy_mux gcc_usb3_prim_phy_pipe_clk_src = {
	.reg = 0xf060,
	.clkr = {
		.hw.init = &(struct clk_init_data){
			.name = "gcc_usb3_prim_phy_pipe_clk_src",
			.parent_data = &(const struct clk_parent_data){
				.fw_name = "usb3_phy_wrapper_gcc_usb30_pipe_clk",
			},
			.num_parents = 1,
			.ops = &clk_regmap_phy_mux_ops,
		},
	},
};
"""
maps = """static const struct parent_map gcc_parent_map_13[] = {
	{ P_USB3_PHY_WRAPPER_GCC_USB30_PIPE_CLK, 0 },
	{ P_BI_TCXO, 2 },
};

static const struct clk_parent_data gcc_parent_data_13[] = {
	{ .fw_name = "usb3_phy_wrapper_gcc_usb30_pipe_clk" },
	{ .fw_name = "bi_tcxo" },
};

"""
for frag in (old, maps):
    if s.count(frag) != 1:
        sys.exit("anchor not found (driver changed?): " + frag.splitlines()[0])
if '#include "clk-regmap-phy-mux.h"' not in s:
    sys.exit("clk-regmap-phy-mux.h not included")
s = s.replace(old, new).replace(maps, "")
if "gcc_parent_map_13" in s or "gcc_parent_data_13" in s:
    sys.exit("gcc_parent_*_13 still referenced")
open(path, "w").write(s)
print("gcc-sm8350: usb3_prim pipe clk src -> clk_regmap_phy_mux")
