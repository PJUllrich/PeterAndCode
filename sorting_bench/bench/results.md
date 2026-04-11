## Elixir Benchmark

```bash
Name                                                                          ips        average  deviation         median         99th %
R02. Rust NIF (Elixir-instructed sort â measures NIF call overhead        90.68       11.03 ms     ±0.85%       11.04 ms       11.27 ms
B02. Rust NIF (binary ref â in-place UNSAFE)                              89.80       11.14 ms     ±1.28%       11.13 ms       11.62 ms
B04. Rust NIF mmap (sort-only, data pre-loaded)                             89.24       11.21 ms     ±1.47%       11.19 ms       11.81 ms
B01. Rust NIF (binary ref â safe copy)                                    88.14       11.35 ms     ±1.16%       11.34 ms       11.68 ms
B03. Rust NIF mmap (full: write+sort+read)                                  86.52       11.56 ms     ±1.30%       11.53 ms       11.97 ms
R01. Rust NIF (generate+sort in Rust â reference)                         77.14       12.96 ms     ±1.92%       12.97 ms       13.48 ms
B05. Port stdin/stdout (Rust via pipe)                                      60.81       16.45 ms     ±2.34%       16.30 ms       17.64 ms
A11. FEnum (NIF round-trip: listâRustâsortâlist)                      54.51       18.35 ms     ±8.64%       17.34 ms       21.25 ms
R04. C Node (Elixir-instructed sort â measures dist overhead)             52.42       19.08 ms     ±0.32%       19.07 ms       19.30 ms
R03. C Node (generate+sort in C â reference)                              47.56       21.03 ms     ±0.29%       21.02 ms       21.22 ms
A02. Rust NIF (list protocol â full copy)                                 47.32       21.13 ms     ±7.65%       20.15 ms       24.02 ms
B06. C Node (distributed Erlang)                                            39.03       25.62 ms     ±2.84%       25.98 ms       26.65 ms
A09. Explorer (Polars)                                                      33.78       29.60 ms     ±9.25%       28.60 ms       35.58 ms
A00. Listâbinary conversion (no sort â measures overhead)               23.13       43.24 ms     ±7.69%       41.99 ms       49.66 ms
A03. Rust NIF binary round-trip (listâbinaryâsortâlist)               16.25       61.54 ms     ±6.49%       61.77 ms       86.39 ms
A12. Port round-trip (listâbinaryâpipeâsortâpipeâlist)            14.85       67.35 ms     ±5.73%       66.87 ms       86.75 ms
A04. Rust NIF mmap round-trip (listâbinaryâmmapâsortâmmapâ        13.85       72.18 ms    ±10.60%       69.29 ms       97.08 ms
A13. C Node round-trip (listâbinaryâdistâsortâdistâlist)          11.60       86.18 ms     ±9.25%       85.59 ms      113.02 ms
A01b. :lists.sort (Erlang â native term comparison)                        8.84      113.11 ms    ±14.46%      109.12 ms      155.73 ms
A01a. Enum.sort (Elixir â fun call per comparison)                         8.64      115.69 ms    ±13.21%      111.28 ms      168.87 ms
A08. Nx (EXLA)                                                               5.63      177.74 ms     ±0.94%      177.52 ms      182.81 ms
A10. Dux (DuckDB)                                                            4.82      207.57 ms     ±9.97%      219.36 ms      238.17 ms
A05. ETS ordered_set (AVL tree insert + tab2list)                            1.14      875.24 ms     ±2.96%      877.11 ms      907.16 ms
A06. Atomics (quicksort on off-heap i64 array)                               1.00     1000.75 ms     ±6.46%     1020.95 ms     1053.70 ms
A07. Nx (BinaryBackend)                                                      0.31     3253.71 ms     ±5.27%     3269.11 ms     3444.88 ms

Comparison:
R02. Rust NIF (Elixir-instructed sort â measures NIF call overhead        90.68
B02. Rust NIF (binary ref â in-place UNSAFE)                              89.80 - 1.01x slower +0.108 ms
B04. Rust NIF mmap (sort-only, data pre-loaded)                             89.24 - 1.02x slower +0.178 ms
B01. Rust NIF (binary ref â safe copy)                                    88.14 - 1.03x slower +0.32 ms
B03. Rust NIF mmap (full: write+sort+read)                                  86.52 - 1.05x slower +0.53 ms
R01. Rust NIF (generate+sort in Rust â reference)                         77.14 - 1.18x slower +1.94 ms
B05. Port stdin/stdout (Rust via pipe)                                      60.81 - 1.49x slower +5.42 ms
A11. FEnum (NIF round-trip: listâRustâsortâlist)                      54.51 - 1.66x slower +7.32 ms
R04. C Node (Elixir-instructed sort â measures dist overhead)             52.42 - 1.73x slower +8.05 ms
R03. C Node (generate+sort in C â reference)                              47.56 - 1.91x slower +10.00 ms
A02. Rust NIF (list protocol â full copy)                                 47.32 - 1.92x slower +10.10 ms
B06. C Node (distributed Erlang)                                            39.03 - 2.32x slower +14.59 ms
A09. Explorer (Polars)                                                      33.78 - 2.68x slower +18.57 ms
A00. Listâbinary conversion (no sort â measures overhead)               23.13 - 3.92x slower +32.21 ms
A03. Rust NIF binary round-trip (listâbinaryâsortâlist)               16.25 - 5.58x slower +50.51 ms
A12. Port round-trip (listâbinaryâpipeâsortâpipeâlist)            14.85 - 6.11x slower +56.32 ms
A04. Rust NIF mmap round-trip (listâbinaryâmmapâsortâmmapâ        13.85 - 6.55x slower +61.15 ms
A13. C Node round-trip (listâbinaryâdistâsortâdistâlist)          11.60 - 7.82x slower +75.15 ms
A01b. :lists.sort (Erlang â native term comparison)                        8.84 - 10.26x slower +102.08 ms
A01a. Enum.sort (Elixir â fun call per comparison)                         8.64 - 10.49x slower +104.66 ms
A08. Nx (EXLA)                                                               5.63 - 16.12x slower +166.72 ms
A10. Dux (DuckDB)                                                            4.82 - 18.82x slower +196.55 ms
A05. ETS ordered_set (AVL tree insert + tab2list)                            1.14 - 79.37x slower +864.21 ms
A06. Atomics (quicksort on off-heap i64 array)                               1.00 - 90.75x slower +989.72 ms
A07. Nx (BinaryBackend)                                                      0.31 - 295.06x slower +3242.69 ms
```

## Rust Benchmark

```bash
Running benches/sort_bench.rs (target/release/deps/sort_bench-a6fcc1a746aba8f6)
Gnuplot not found, using plotters backend
sort_1m_i64/generate_and_sort/1000000
                   time:   [12.738 ms 12.744 ms 12.751 ms]
                   change: [-0.0287% +0.0697% +0.1568%] (p = 0.14 > 0.05)
                   No change in performance detected.
Found 8 outliers among 100 measurements (8.00%)
2 (2.00%) high mild
6 (6.00%) high severe
sort_1m_i64/sort_only/1000000
                   time:   [10.958 ms 10.964 ms 10.972 ms]
                   change: [+0.0193% +0.1055% +0.1957%] (p = 0.02 < 0.05)
                   Change within noise threshold.
Found 4 outliers among 100 measurements (4.00%)
1 (1.00%) high mild
3 (3.00%) high severe
sort_1m_i64/sort_presorted/1000000
                   time:   [394.58 µs 394.86 µs 395.24 µs]
                   change: [-0.1407% +0.0453% +0.2119%] (p = 0.63 > 0.05)
                   No change in performance detected.
Found 13 outliers among 100 measurements (13.00%)
4 (4.00%) high mild
9 (9.00%) high severe
sort_1m_i64/sort_reverse_sorted/1000000
                   time:   [10.334 ms 10.345 ms 10.357 ms]
                   change: [+0.2478% +0.3689% +0.4891%] (p = 0.00 < 0.05)
                   Change within noise threshold.
Found 10 outliers among 100 measurements (10.00%)
6 (6.00%) high mild
4 (4.00%) high severe
```

## C Benchmark

```bash
Unable to determine clock rate from sysctl: hw.cpufrequency: No such file or directory
This does not affect benchmark measurements, only the metadata output.
***WARNING*** Failed to set thread affinity. Estimated CPU frequency may be incorrect.
2026-04-11T15:44:47+02:00
Running ./c_bench/bench_sort
Run on (10 X 24 MHz CPU s)
CPU Caches:
  L1 Data 64 KiB
  L1 Instruction 128 KiB
  L2 Unified 4096 KiB (x10)
Load Average: 1.54, 1.68, 1.77
---------------------------------------------------------------------------------------------------------------
Benchmark                                                     Time             CPU   Iterations UserCounters...
---------------------------------------------------------------------------------------------------------------
BM_GenerateAndSort/1000000/min_time:2.000                  80.6 ms         80.5 ms           35 items_per_second=12.4147M/s
BM_SortOnly/1000000/min_time:2.000                         78.8 ms         78.8 ms           36 items_per_second=12.6862M/s
BM_SortPresorted/1000000/min_time:2.000                    3.33 ms         3.33 ms          846 items_per_second=300.544M/s
BM_SortReverseSorted/1000000/min_time:2.000                14.4 ms         14.4 ms          193 items_per_second=69.4443M/s
BM_StdSort_GenerateAndSort/1000000/min_time:2.000          20.9 ms         20.9 ms          133 items_per_second=47.8369M/s
BM_StdSort_SortOnly/1000000/min_time:2.000                 19.1 ms         19.1 ms          146 items_per_second=52.4558M/s
BM_StdSort_SortPresorted/1000000/min_time:2.000           0.968 ms        0.968 ms         2854 items_per_second=1.03316G/s
BM_StdSort_SortReverseSorted/1000000/min_time:2.000        1.60 ms         1.60 ms         1742 items_per_second=626.929M/s
BM_PdqSort_GenerateAndSort/1000000/min_time:2.000          20.5 ms         20.5 ms          136 items_per_second=48.8988M/s
BM_PdqSort_SortOnly/1000000/min_time:2.000                 18.6 ms         18.6 ms          150 items_per_second=53.7183M/s
BM_PdqSort_SortPresorted/1000000/min_time:2.000           0.888 ms        0.888 ms         3191 items_per_second=1.12646G/s
BM_PdqSort_SortReverseSorted/1000000/min_time:2.000        1.36 ms         1.36 ms         2042 items_per_second=735.713M/s
BM_NanoSort_GenerateAndSort/1000000/min_time:2.000         18.1 ms         18.1 ms          153 items_per_second=55.1621M/s
BM_NanoSort_SortOnly/1000000/min_time:2.000                16.4 ms         16.4 ms          170 items_per_second=61.0551M/s
BM_NanoSort_SortPresorted/1000000/min_time:2.000           18.3 ms         18.3 ms          152 items_per_second=54.6305M/s
BM_NanoSort_SortReverseSorted/1000000/min_time:2.000       15.6 ms         15.6 ms          179 items_per_second=64.2713M/s
```