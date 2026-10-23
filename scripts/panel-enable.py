import sys, pathlib
f = pathlib.Path(sys.argv[1]); c = f.read_text()
if "samsung_amb670yf01_dsc_enable" in c: print("already"); sys.exit(0)
a = "static const struct drm_display_mode samsung_amb670yf01_dsc_mode = {"
assert a in c
c = c.replace(a, '''/*
 * Downstream sends DISPLAY_ON (0x29) separately, as qcom,mdss-dsi-post-on-backlight, after the first
 * frame/brightness update; it is not part of the on-command sequence (without it the screen stays black).
 */
static int samsung_amb670yf01_dsc_enable(struct drm_panel *panel)
{
	struct samsung_amb670yf01_dsc *ctx = to_samsung_amb670yf01_dsc(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	mipi_dsi_dcs_set_display_on_multi(&dsi_ctx);
	if (!dsi_ctx.accum_err)
		dev_info(&ctx->dsi->dev, "display on\\n");

	return dsi_ctx.accum_err;
}

static int samsung_amb670yf01_dsc_disable(struct drm_panel *panel)
{
	struct samsung_amb670yf01_dsc *ctx = to_samsung_amb670yf01_dsc(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	mipi_dsi_dcs_set_display_off_multi(&dsi_ctx);

	return dsi_ctx.accum_err;
}

''' + a, 1)
b = "\t.prepare = samsung_amb670yf01_dsc_prepare,\n"
assert b in c
c = c.replace(b, b + "\t.enable = samsung_amb670yf01_dsc_enable,\n\t.disable = samsung_amb670yf01_dsc_disable,\n", 1)
f.write_text(c); print("ok")
