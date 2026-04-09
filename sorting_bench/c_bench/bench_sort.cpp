/*
 * Standalone C sort benchmark using Google Benchmark.
 *
 * Measures pure C qsort speed with no BEAM involvement,
 * providing the reference ceiling for the Elixir benchmarks.
 *
 * Build:  make -C c_bench
 * Run:    ./c_bench/bench_sort
 */

#include <benchmark/benchmark.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* --- PRNG (same xorshift64 as the Rust and NIF versions) --- */

static inline uint64_t xorshift64(uint64_t *state) {
    uint64_t x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    return x;
}

static int64_t *generate_data(size_t n) {
    int64_t *arr = (int64_t *)malloc(n * sizeof(int64_t));
    uint64_t rng = 0xdeadbeefcafe1234ULL;
    for (size_t i = 0; i < n; i++) {
        arr[i] = (int64_t)(xorshift64(&rng) % 1000000000);
    }
    return arr;
}

/* --- qsort comparator --- */

static int compare_i64(const void *a, const void *b) {
    int64_t ia = *(const int64_t *)a;
    int64_t ib = *(const int64_t *)b;
    if (ia < ib) return -1;
    if (ia > ib) return 1;
    return 0;
}

/* --- Benchmarks --- */

static void BM_GenerateAndSort(benchmark::State &state) {
    size_t n = state.range(0);
    for (auto _ : state) {
        int64_t *arr = generate_data(n);
        qsort(arr, n, sizeof(int64_t), compare_i64);
        benchmark::DoNotOptimize(arr);
        free(arr);
    }
    state.SetItemsProcessed(state.iterations() * n);
}
BENCHMARK(BM_GenerateAndSort)->Arg(1000000)->Unit(benchmark::kMillisecond);

static void BM_SortOnly(benchmark::State &state) {
    size_t n = state.range(0);
    for (auto _ : state) {
        state.PauseTiming();
        int64_t *arr = generate_data(n);
        state.ResumeTiming();

        qsort(arr, n, sizeof(int64_t), compare_i64);
        benchmark::DoNotOptimize(arr);
        free(arr);
    }
    state.SetItemsProcessed(state.iterations() * n);
}
BENCHMARK(BM_SortOnly)->Arg(1000000)->Unit(benchmark::kMillisecond);

static void BM_SortPresorted(benchmark::State &state) {
    size_t n = state.range(0);
    for (auto _ : state) {
        state.PauseTiming();
        int64_t *arr = generate_data(n);
        qsort(arr, n, sizeof(int64_t), compare_i64);
        state.ResumeTiming();

        qsort(arr, n, sizeof(int64_t), compare_i64);
        benchmark::DoNotOptimize(arr);
        free(arr);
    }
    state.SetItemsProcessed(state.iterations() * n);
}
BENCHMARK(BM_SortPresorted)->Arg(1000000)->Unit(benchmark::kMillisecond);

static int compare_i64_reverse(const void *a, const void *b) {
    return -compare_i64(a, b);
}

static void BM_SortReverseSorted(benchmark::State &state) {
    size_t n = state.range(0);
    for (auto _ : state) {
        state.PauseTiming();
        int64_t *arr = generate_data(n);
        qsort(arr, n, sizeof(int64_t), compare_i64_reverse);
        state.ResumeTiming();

        qsort(arr, n, sizeof(int64_t), compare_i64);
        benchmark::DoNotOptimize(arr);
        free(arr);
    }
    state.SetItemsProcessed(state.iterations() * n);
}
BENCHMARK(BM_SortReverseSorted)->Arg(1000000)->Unit(benchmark::kMillisecond);

BENCHMARK_MAIN();
