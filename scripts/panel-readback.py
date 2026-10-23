import sys, pathlib
f = pathlib.Path(sys.argv[1]); c = f.read_text()
if "amb670_log_power_mode" in c: print("already"); sys.exit(0)
a = "/*\n * Downstream sends DISPLAY_ON (0x29)"
assert a in c
c = c.replace(a, '''/* Debug: downstream ESD check reads DCS 0x0a and expects 0x9f (booster, normal mode, sleep out, display on) */
static void amb670_log_power_mode(struct samsung_amb670yf01_dsc *ctx, const char *when)
{
	u8 mode = 0;
	int ret;

	ctx->dsi->mode_flags |= MIPI_DSI_MODE_LPM;
	ret = mipi_dsi_dcs_get_power_mode(ctx->dsi, &mode);
	dev_info(&ctx->dsi->dev, "power mode %s: ret=%d mode=0x%02x\\n", when, ret, mode);
}

''' + a, 1)
b = "\tif (!dsi_ctx.accum_err)\n\t\tdev_info(&ctx->dsi->dev, \"display on\\n\");\n"
assert b in c
c = c.replace(b, b + "\tmsleep(20);\n\tamb670_log_power_mode(ctx, \"after display on\");\n", 1)
d = "\tmsleep(28); /* TODO: Is this panel-dependent? */\n"
assert d in c
c = c.replace(d, d + "\tamb670_log_power_mode(ctx, \"after prepare\");\n", 1)
proto = "static void amb670_log_power_mode(struct samsung_amb670yf01_dsc *ctx, const char *when);\n"
if proto not in c:
    r = "static void samsung_amb670yf01_dsc_reset("
    assert r in c
    c = c.replace(r, proto + "\n" + r, 1)
f.write_text(c); print("ok")
