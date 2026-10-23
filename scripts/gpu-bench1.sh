temps() { for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/type); case $t in gpu*|cpu-0-0*|cpu-1-0*|xo-therm*|skin*) printf "%s=%s " $t $(( $(cat $z/temp) / 1000 ));; esac; done; echo; }
echo "== temps before: $(temps)"
echo "== GPU freqs: $(cat /sys/class/devfreq/3d00000.gpu/available_frequencies 2>/dev/null) gov=$(cat /sys/class/devfreq/3d00000.gpu/governor 2>/dev/null)"
echo "== OpenCL (rusticl)"
RUSTICL_ENABLE=freedreno clinfo 2>&1 | grep -E "Platform Name|Device Name|Device Version|Max compute units|Max clock|Global memory size|Preferred vector width float|Number of devices" | head -12
echo "== vkmark headless 1920x1080"
vkmark --winsys headless -s 1920x1080 2>&1 | grep -vE "^\s*$" | tail -16
echo "== temps after: $(temps)"
echo "== GPU cur freq: $(cat /sys/class/devfreq/3d00000.gpu/cur_freq 2>/dev/null)"
