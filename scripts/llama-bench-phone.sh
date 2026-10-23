M=$HOME/models/qwen2.5-1.5b-instruct-q4_0.gguf
temps() { for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/type); case $t in gpu-top*|cpu-1-0-0*|cpu-0-0-0*) printf "%s=%s " $t $(( $(cat $z/temp) / 1000 ));; esac; done; }
echo "== devices"; llama-bench --list-devices 2>&1 | tail -5
echo "== CPU (temps: $(temps))"
llama-bench -m $M -ngl 0 -dev none -t 4,8 -p 512 -n 128 -r 2 -o md 2>&1 | grep -E "^\|"
echo "== GPU Vulkan (temps: $(temps))"
llama-bench -m $M -ngl 99 -p 512 -n 128 -r 2 -o md 2>&1 | grep -E "^\||ggml_vulkan|error" | head -12
echo "== end (temps: $(temps))"
