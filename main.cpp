#include <liburing.h>
#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <cstring>
#include <constants.h>
#include <assert.h>
#include <chrono>

// compare normal write, read, liburing write, read, normal, poll

class IOUringHandler {
    private :
        struct io_uring ring;
        int task_count;

    public :
        IOUringHandler() {
            io_uring_queue_init(32, &ring, 0);
            task_count = 0;
        }

        ~IOUringHandler() {
            io_uring_queue_exit(&ring);
        }

        void write(int fd, char *buffer, int size, off_t offset) {
            struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
            io_uring_prep_write(sqe, fd, buffer, size, offset);
            io_uring_submit(&ring);
            task_count++;
        }

        void read(int fd, char *buffer, int size, off_t offset) {
            struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
            io_uring_prep_read(sqe, fd, buffer, size, offset);
            io_uring_submit(&ring);
            task_count++;
        }

        void poll() {
            assert(task_count > 0);
            struct io_uring_cqe *cqe;
            io_uring_wait_cqe(&ring, &cqe);
            io_uring_cqe_seen(&ring, cqe);
            if (cqe->res < 0) {
                std::cerr << "I/O operation failed\n";
                exit(1);
            }
            // std::cout << "I/O " << cqe->res << " bytes successful\n";
            task_count--;
        }

};

size_t get_aligned_size(size_t size) {
    return (size + NVME_SECTOR_SIZE - 1) & ~(NVME_SECTOR_SIZE - 1);
}

void random_generate_data(char *buffer, size_t size) {
    for (size_t i = 0; i < size; i++) {
        buffer[i] = rand() % 256;
    }
}

struct Profile {
    double write_time;
    double read_time;
};

Profile test_single_thread(int fd, size_t size, char *write_buffer, char *read_buffer){
    IOUringHandler write_handler, read_handler;
    std::chrono::time_point<std::chrono::high_resolution_clock> start_time, end_time;
    double write_time, read_time;

    start_time = std::chrono::high_resolution_clock::now();
    write_handler.write(fd, write_buffer, size, 0);
    write_handler.poll();
    end_time = std::chrono::high_resolution_clock::now();
    write_time = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();    
    
    start_time = std::chrono::high_resolution_clock::now();
    read_handler.read(fd, read_buffer, size, 0);
    read_handler.poll();
    end_time = std::chrono::high_resolution_clock::now();
    read_time = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();
    
    assert(memcmp(write_buffer, read_buffer, size) == 0);

    return {write_time, read_time};
}

#include <thread>

void thread_func(int fd, IOUringHandler &handler, char *buffer, size_t size, bool is_write) {
    if (is_write) {
        handler.write(fd, buffer, size, 0);
    } else {
        handler.read(fd, buffer, size, 0);
    }
    handler.poll();
}

Profile test_two_thread(int fd, int fd2, size_t size, char *write_buffer, char *read_buffer){
    IOUringHandler write_handler, read_handler;
    std::chrono::time_point<std::chrono::high_resolution_clock> start_time, end_time;
    double write_time, read_time;
    size_t each_thread_size = size / 2;

    std::thread thread1, thread2;
    start_time = std::chrono::high_resolution_clock::now();
    thread1 = std::thread(thread_func, fd, std::ref(write_handler), write_buffer, each_thread_size, true);
    thread2 = std::thread(thread_func, fd2, std::ref(write_handler), write_buffer + each_thread_size, each_thread_size, true);
    thread1.join();
    thread2.join();
    end_time = std::chrono::high_resolution_clock::now();
    write_time = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();

    start_time = std::chrono::high_resolution_clock::now();
    thread1 = std::thread(thread_func, fd, std::ref(read_handler), read_buffer, each_thread_size, false);
    thread2 = std::thread(thread_func, fd2, std::ref(read_handler), read_buffer + each_thread_size, each_thread_size, false);
    thread1.join();
    thread2.join();
    end_time = std::chrono::high_resolution_clock::now();
    read_time = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();

    assert(memcmp(write_buffer, read_buffer, size) == 0);
    return {write_time, read_time};
}

int main(int argc, char *argv[]) {
    assert(argc >= 5);
    char *nvme_path = argv[1];
    size_t size = atoi(argv[2]);
    size = get_aligned_size(size);
    int test_rounds = atoi(argv[3]);
    int process_count = atoi(argv[4]);
    assert(process_count == 1 || process_count == 2);
    char *nvme_path_2;
    if (process_count == 2) {
        nvme_path_2 = argv[5];
    }

    double total_write_time = 0, total_read_time = 0;
    
    int fd1, fd2;

    fd1 = open(nvme_path, O_RDWR | O_DIRECT);
    assert(fd1 > 0);
    if (process_count == 2) {
        fd2 = open(nvme_path_2, O_RDWR | O_DIRECT);
        assert(fd2 > 0);
    }
    
    for (int i = 0; i < test_rounds; i++) {
        Profile profiling_data;
        char *write_buffer, *read_buffer;
        int ret = posix_memalign((void **)&write_buffer, NVME_SECTOR_SIZE, size);
        assert(ret == 0);
        ret = posix_memalign((void **)&read_buffer, NVME_SECTOR_SIZE, size);
        assert(ret == 0);
        random_generate_data(write_buffer, size);

        if (process_count == 1) {
            profiling_data = test_single_thread(fd1, size, write_buffer, read_buffer);
            total_write_time += profiling_data.write_time;
            total_read_time += profiling_data.read_time;
        } else {
            profiling_data = test_two_thread(fd1, fd2, size, write_buffer, read_buffer);
            total_write_time += profiling_data.write_time;
            total_read_time += profiling_data.read_time;
        }

        delete[] write_buffer;
        delete[] read_buffer;
    }

    std::cout << "Average write time: " << total_write_time / test_rounds << " us\n";
    std::cout << "Average write bandwidth: " << size / (total_write_time / test_rounds) << " MB/s\n";
    std::cout << "Average read time: " << total_read_time / test_rounds << " us\n";
    std::cout << "Average read bandwidth: " << size / (total_read_time / test_rounds) << " MB/s\n";

    close(fd1);
    if (process_count == 2) {
        close(fd2);
    }
    return 0;
}