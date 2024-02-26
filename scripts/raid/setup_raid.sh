RAID_PATH=/dev/md127
NORMAL_PATH=/dev/nvme0n1
NORMAL_PATH2=/dev/nvme1n1

sudo mdadm --create --verbose ${RAID_PATH} --level=0 --raid-devices=2 ${NORMAL_PATH} ${NORMAL_PATH2}