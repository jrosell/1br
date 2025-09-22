// $ g++ -std=c++17 -O3 -m64 -march=native -mtune=native -flto -pthread -DNTHREADS=$(nproc) run.cpp -o run && ./run data/measurements.1e9.csv
// $ g++ -std=c++17 -O3 -m64 -march=native -mtune=native -flto -pthread -DNTHREADS=8 run.cpp -o run && ./run data/measurements.1e9.csv
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <array>
#include <thread>
#include <vector>
#include <algorithm>
#include <iostream>
#include <charconv>
#include <chrono>
#include <cstdint>
#include <cstring>

#ifndef NTHREADS
#define NTHREADS 8
#endif

struct Agg { double min, max, sum; int count; };

constexpr int n_states = 50;
const std::array<std::string, n_states> states = {
    "NC","MA","TX","VT","OR","NY","ND","NV","SD",
    "IN","ID","RI","TN","SC","PA","WV","CT","NE","KY","DE",
    "MT","ME","AL","WI","IA","MI","UT","LA","WA","NM",
    "AR","MO","MD","MN","KS","AK","OK","NH","NJ","AZ",
    "CA","HI","IL","GA","WY","CO","MS","VA","OH","FL"
};

std::array<int, 65536> code_to_index_array;

void init_state_codes() {
    code_to_index_array.fill(-1);
    for (int i = 0; i < n_states; ++i) {
        uint16_t code = (static_cast<uint16_t>(states[i][0]) << 8)
                      | static_cast<uint16_t>(states[i][1]);
        code_to_index_array[code] = i;
    }
}

inline const char* find_newline(const char* ptr, const char* end) {
    while (ptr < end && *ptr != '\n') ++ptr;
    return ptr;
}

inline uint16_t extract_state_code(const char* line_start, const char* line_end) {
    const char* state_ptr = line_end - 2;
    return (static_cast<uint16_t>(state_ptr[0]) << 8) |
           static_cast<uint16_t>(state_ptr[1]);
}

inline bool parse_numeric(
    const char* line_start, const char* line_end, double& value
) {
    const char* num_end = line_end - 3;
    auto res = std::from_chars(line_start, num_end, value);
    return res.ec == std::errc();
}

inline void update_values(
    std::array<Agg, n_states>& stats, int idx, double value
) {
    auto& agg = stats[idx];
    if (agg.count == 0) {
        agg = {value, value, value, 1};
    } else {
        agg.min = std::min(agg.min, value);
        agg.max = std::max(agg.max, value);
        agg.sum += value;
        agg.count += 1;
    }
}



void parse_chunk(
    const char* data_chunk,
    size_t start_chunk,
    size_t end_chunk,
    std::array<Agg, n_states>& local_stats
) {
    size_t current_pos = start_chunk;

    while (current_pos < end_chunk) {
        const char* line_start = data_chunk + current_pos;
        const char* line_end = find_newline(line_start, data_chunk + end_chunk);
        size_t line_len = line_end - line_start;
        uint16_t state_code = extract_state_code(line_start, line_end);
        int idx = code_to_index_array[state_code];
        if (idx == -1) {
            std::cerr << "Error: unknown code at line " << current_pos << "\n";
            std::abort();
        }
        double value;
        if (!parse_numeric(line_start, line_end, value)) {
            std::cerr << "Error: parsing fails at line " << current_pos << "\n";
            std::abort();
        }
        update_values(local_stats, idx, value);
        current_pos += line_len + 1;
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <csv_file>\n";
        return 1;
    }

    auto start_time = std::chrono::high_resolution_clock::now();
    const char* file_name = argv[1];

    int fd = open(file_name, O_RDONLY);
    if (fd == -1) { perror("open"); return 1; }

    struct stat st;
    if (fstat(fd, &st) == -1) { perror("fstat"); close(fd); return 1; }
    size_t sz = st.st_size;

    char* data = static_cast<char*>(mmap(nullptr, sz, PROT_READ, MAP_SHARED, fd, 0));
    if (data == MAP_FAILED) { perror("mmap"); close(fd); return 1; }

    // --- skip header ---
    size_t pos = 0;
    while (pos < sz && data[pos] != '\n') pos++;
    if (pos < sz) pos++;

    init_state_codes();

    int n_threads = NTHREADS;
    std::vector<std::thread> threads;
    std::vector<std::array<Agg, n_states>> locals(n_threads);

    size_t chunk_size = (sz - pos) / n_threads;
    size_t start = pos;

    for (int t = 0; t < n_threads; ++t) {
        size_t end = (t == n_threads - 1) ? sz : start + chunk_size;
        while (end < sz && data[end] != '\n') end++;

        threads.emplace_back(parse_chunk, data, start, end, std::ref(locals[t]));
        start = end + 1;
    }

    for (auto& th : threads) th.join();

    std::array<Agg, n_states> final_stats{};
    for (int i = 0; i < n_states; ++i) { final_stats[i].count = 0; final_stats[i].sum = 0; }

    for (int t = 0; t < n_threads; ++t) {
        for (int i = 0; i < n_states; ++i) {
            const auto& src = locals[t][i];
            auto& dst = final_stats[i];
            if (src.count == 0) continue;
            if (dst.count == 0) dst = src;
            else {
                dst.min = std::min(dst.min, src.min);
                dst.max = std::max(dst.max, src.max);
                dst.sum += src.sum;
                dst.count += src.count;
            }
        }
    }

    munmap(data, sz);
    close(fd);

    // print results
    for (int i = 0; i < n_states; ++i) {
        const auto& agg = final_stats[i];
        if (agg.count == 0) continue;
        std::cout << states[i]
                  << ": min=" << agg.min
                  << " max=" << agg.max
                  << " mean=" << (agg.sum / agg.count)
                  << " count=" << agg.count
                  << "\n";
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> total_time = end_time - start_time;
    std::cout << "Total execution time: " << total_time.count() << " s\n";
    // Total execution time: 0.538664 s

    return 0;
}
