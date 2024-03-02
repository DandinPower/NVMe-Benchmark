RAID_PATH=/dev/md127
NVME_PATH_0=/dev/nvme1n1
NVME_PATH_1=/dev/nvme2n1
SIZE=134217728
TEST_ROUNDS=10

# Function to stop the RAID
stop_raid() {
    if lsblk "$1" >/dev/null 2>&1; then
        sudo mdadm --stop "$1"
    else
        echo "RAID path does not exist: $1"
    fi
}

# Function to start the RAID
start_raid() {
    if lsblk "$1" >/dev/null 2>&1; then
        echo "RAID path already exists: $1"
    else
        sudo mdadm --create --verbose "$1" --level=0 --raid-devices=2 "$2" "$3"
    fi
}

# Function to format the PATH
format_path() {
    if lsblk "$1" >/dev/null 2>&1; then
        sudo mkfs.ext4 "$1"
    else
        echo "path does not exist: $1"
    fi
}

make clean && make

# ensure the RAID is stopped
stop_raid "$RAID_PATH"

format_path "$NVME_PATH_0"
sudo ./build/bin/benchmark $NVME_PATH_0 $SIZE $TEST_ROUNDS 1

# ensure the RAID is stopped
stop_raid "$RAID_PATH"

format_path "$NVME_PATH_0"
format_path "$NVME_PATH_1"
sudo ./build/bin/benchmark $NVME_PATH_0 $SIZE $TEST_ROUNDS 2 $NVME_PATH_1

# ensure the RAID is started
start_raid "$RAID_PATH" "$NVME_PATH_0" "$NVME_PATH_1"

format_path "$RAID_PATH"
sudo ./build/bin/benchmark $RAID_PATH $SIZE $TEST_ROUNDS 1

# reset raid
stop_raid "$RAID_PATH"