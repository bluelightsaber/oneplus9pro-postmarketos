echo "== kernel $(uname -r)"; grep -q separate_gpu_kms /proc/cmdline || { echo "not the gpu variant"; exit 0; }
touch /run/keep-experiment
echo "== usb gadget path:"; journalctl -b -o short-monotonic --no-pager | grep -E "usb-gadget-ensure|Setting up USB gadget|No UDC" | cut -c1-150
ls -l /dev/dri/
# render node only (no card0/video group) so Turnip does not try VK_KHR_display on a KMS-less node
RUN="setpriv --reuid=user --regid=user --groups=render --reset-env env XDG_RUNTIME_DIR=/tmp"
echo "== vulkaninfo --summary"; $RUN vulkaninfo --summary 2>&1 | head -45
echo "== EGL"; $RUN eglinfo -B -p surfaceless 2>&1 | grep -iE "renderer|version" | head -5
dmesg | grep -iE "msm|gpu|zap|gmu|a6[0-9]0" | tail -15; dmesg | wc -l
rm -f /run/keep-experiment; systemctl reboot --reboot-argument=bootloader
