NVME_PATH=/dev/nvme1n1
RESULT_PATH=result/nvme1n1_write.txt
NUM_JOBS=10
IO_DEPTH=16
BLOCK_SIZE=4k

rm -f $RESULT_PATH

sudo fio --name=test --ioengine=libaio --rw=write  --bs=$BLOCK_SIZE --numjobs=$NUM_JOBS --size=20G --iodepth=$IO_DEPTH --end_fsync=1 -direct=1 --filename=$NVME_PATH --output=$RESULT_PATH 