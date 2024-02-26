# NVMe Benchmark

This is a repository that help you can simply run a benchmark to watch the performance of your NVMe SSD.

## Prerequisites

1. Ubuntu 22.04
2. NVMe SSD x2

## Installation

You can install the package by running the following command:

```bash
sudo apt install build-essential
sudo apt install liburing-dev
sudo apt install mdadm
sudo apt install fio
```

## FIO Benchmark

You can run the FIO benchmark by going to the following folder:

```bash
cd scripts/fio
```

## RAID Setup / Reset

You can setup the RAID by going to the following folder:

```bash
cd scripts/raid
```

## Liburing Benchmark

You can run the Liburing benchmark by using the following command:

1. modify the `run_benchmark.sh` file config to your own config

2. run the `.sh` file
    ```bash
    bash run_benchmark.sh
    ```