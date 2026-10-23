set -e
DEV=/dev/disk/by-partlabel/userdata
R=$(readlink -f $DEV); echo "target: $R ($(lsblk -no SIZE $R))"
[ "$R" = /dev/sda20 ] || { echo "unexpected device"; exit 1; }
findmnt -S $R >/dev/null && { echo "already mounted"; exit 1; }
T=$(blkid -o value -s TYPE $R || true); [ -z "$T" ] || { echo "has a filesystem ($T), refusing"; exit 1; }
mkfs.btrfs -q -f -L data $R
UUID=$(blkid -o value -s UUID $R); echo "uuid $UUID"
M=$(mktemp -d); mount -o noatime $R $M
btrfs subvolume create $M/@data >/dev/null; btrfs subvolume create $M/@docker >/dev/null; btrfs subvolume create $M/@containerd >/dev/null
btrfs subvolume list $M; umount $M; rmdir $M
cp /etc/fstab /etc/fstab.pre-data
O="noatime,compress=zstd:2,ssd,nofail,x-systemd.device-timeout=15s"
cat >> /etc/fstab <<F
# userdata (102 GB) -> data disk (2026-10-09)
UUID=$UUID /data btrfs subvol=@data,$O 0 0
UUID=$UUID /var/lib/docker btrfs subvol=@docker,$O 0 0
UUID=$UUID /var/lib/containerd btrfs subvol=@containerd,$O 0 0
F
systemctl stop docker docker.socket containerd 2>/dev/null || true
rm -rf /var/lib/docker /var/lib/containerd
mkdir -p /data /var/lib/docker /var/lib/containerd
systemctl daemon-reload
mount /data && mount /var/lib/docker && mount /var/lib/containerd
mkdir -p /etc/systemd/system/containerd.service.d /etc/systemd/system/docker.service.d
printf '[Unit]\nRequiresMountsFor=/var/lib/containerd\n' > /etc/systemd/system/containerd.service.d/data-disk.conf
printf '[Unit]\nRequiresMountsFor=/var/lib/docker /var/lib/containerd\n' > /etc/systemd/system/docker.service.d/data-disk.conf
mkdir -p /data/models && chown user:user /data /data/models
systemctl daemon-reload; systemctl start containerd docker
sleep 3
findmnt -t btrfs -o TARGET,SOURCE,OPTIONS | grep -E "/data|docker|containerd" | cut -c1-110
df -h /data | tail -1
timeout 90 docker run --rm hello-world 2>&1 | grep -m1 "Hello from Docker"
