set -e
# test leftovers the user does not want to keep
rm -rf /data/models; rm -f /home/user/models; rm -rf /var/lib/qca6490-fw
# Docker data-root -> /opt/docker (btrfs subvolume @docker on the data disk), like the user's other servers
systemctl stop docker docker.socket containerd
umount /var/lib/docker
sed -i 's|^\(UUID=[0-9a-f-]* \)/var/lib/docker \(btrfs subvol=@docker,\)|\1/opt/docker \2|' /etc/fstab
grep -n "@docker" /etc/fstab
mkdir -p /opt/docker; rmdir /var/lib/docker 2>/dev/null || true
mkdir -p /etc/docker
printf '{\n  "data-root": "/opt/docker"\n}\n' > /etc/docker/daemon.json
printf '[Unit]\nRequiresMountsFor=/opt/docker /var/lib/containerd\n' > /etc/systemd/system/docker.service.d/data-disk.conf
systemctl daemon-reload
mount /opt/docker
rm -rf /opt/docker/* 2>/dev/null || true
systemctl start containerd docker; sleep 3
docker info 2>/dev/null | grep -E "Docker Root Dir|Storage Driver"
timeout 90 docker run --rm hello-world 2>&1 | grep -m1 "Hello from Docker"
docker image prune -af >/dev/null 2>&1 || true
findmnt -n -o TARGET,SOURCE /opt/docker; df -h /data | tail -1
