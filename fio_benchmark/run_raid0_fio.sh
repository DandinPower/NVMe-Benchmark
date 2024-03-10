# Test Configuration
IO_ENGINE=io_uring
TOTAL_SIZE=10G
BLOCK_SIZE=32M
NUM_JOBS=10
IO_DEPTH=16

# Constants
RAID_PATH=/dev/md127
NVME_PATH_0=/dev/nvme1n1
NVME_PATH_1=/dev/nvme2n1
RESULT_FOLDER=result/raid0/Job_${NUM_JOBS}_Block_${BLOCK_SIZE}
WRITE_RESULT_PATH=$RESULT_FOLDER/write_0.txt
READ_RESULT_PATH=$RESULT_FOLDER/read_0.txt

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

# Function to do write fio on the PATH
write_fio_benchmark() {
    echo "start write on $1"
    sudo fio --name=test --ioengine=$IO_ENGINE --rw=write  --bs=$BLOCK_SIZE --numjobs=$NUM_JOBS --size=$TOTAL_SIZE --iodepth=$IO_DEPTH --end_fsync=1 -direct=1 --filename=$1 --output=$2
    echo "end write on $1"
}

# Function to do read fio on the PATH
read_fio_benchmark() {
    echo "start read on $1"
    sudo fio --name=test --ioengine=$IO_ENGINE --rw=read  --bs=$BLOCK_SIZE --numjobs=$NUM_JOBS --size=$TOTAL_SIZE --iodepth=$IO_DEPTH --end_fsync=1 -direct=1 --filename=$1 --output=$2
    echo "end read on $1"
}

# ensure the RAID is stopped
stop_raid "$RAID_PATH"
start_raid "$RAID_PATH" "$NVME_PATH_0" "$NVME_PATH_1"

# reset the result folder
rm -rf $RESULT_FOLDER
mkdir -p $RESULT_FOLDER

# write benchmark

echo "format the nvme device..."
format_path "$RAID_PATH"

echo "start write benchmark"
write_fio_benchmark "$RAID_PATH" "$WRITE_RESULT_PATH"
echo "end write benchmark"

# read benchmark

echo "format the nvme device..."
format_path "$RAID_PATH"

echo "start read benchmark"
read_fio_benchmark "$RAID_PATH" "$READ_RESULT_PATH"
echo "end read benchmark"

# reset raid
stop_raid "$RAID_PATH"