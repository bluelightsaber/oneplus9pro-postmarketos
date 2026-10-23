echo "== kernel $(uname -r)"; [ "$(uname -r)" = "7.3.0-rc5" ] && ! grep -q separate_gpu_kms /proc/cmdline && { echo "not the gpu variant"; exit 0; }
touch /run/keep-experiment
ls /dev/dri/
echo "== vulkaninfo"; su user -c "vulkaninfo --summary 2>&1" | grep -E "deviceName|driverName|driverInfo|apiVersion|deviceType" | head -8
echo "== eglinfo (surfaceless)"; su user -c "EGL_PLATFORM=surfaceless eglinfo -B 2>&1" | grep -iE "renderer|version string" | head -4
echo "== dmesg"; dmesg | grep -iE "adreno|a6xx|a660|gmu|zap|msm_gpu|\[drm\]" | head -20
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
