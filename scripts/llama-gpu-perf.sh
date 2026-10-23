G=/sys/class/devfreq/3d00000.gpu
OLD=$(cat $G/governor); echo performance > $G/governor; echo "gov=$(cat $G/governor) cur=$(cat $G/cur_freq)"
su user -s /bin/sh -c "llama-bench -m /home/user/models/qwen2.5-1.5b-instruct-q4_0.gguf -ngl 99 -p 512 -n 128 -r 2 -o md 2>&1 | grep -E '^\| qwen'" &
P=$!; sleep 20; echo "during: cur=$(cat $G/cur_freq) gpu_busy=$(cat /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage 2>/dev/null) temp=$(( $(cat /sys/class/thermal/thermal_zone*/temp | sort -n | tail -1) / 1000 ))"
wait $P
echo $OLD > $G/governor; echo "restored gov=$(cat $G/governor)"
