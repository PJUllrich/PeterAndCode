## Elixir Benchmark

```
Name                                                                          ips        average  deviation         median         99th %
06. Rust NIF mmap (sort-only, data pre-loaded)                              92.36       10.83 ms     ±0.25%       10.82 ms       10.91 ms
04. Rust NIF (binary ref â in-place UNSAFE)                               92.17       10.85 ms     ±0.49%       10.84 ms       11.03 ms
00. Rust NIF (Elixir-instructed sort â measures NIF call overhead)        91.68       10.91 ms     ±0.76%       10.89 ms       11.17 ms
03. Rust NIF (binary ref â safe copy)                                     90.56       11.04 ms     ±0.60%       11.03 ms       11.24 ms
05. Rust NIF mmap (full: write+sort+read)                                   89.58       11.16 ms     ±0.81%       11.14 ms       11.67 ms
00. Rust NIF (generate+sort in Rust â reference)                          78.39       12.76 ms     ±0.62%       12.75 ms       12.97 ms
12. Port stdin/stdout (Rust via pipe)                                       55.98       17.86 ms     ±1.29%       17.84 ms       18.54 ms
00. C Node (Elixir-instructed sort â measures dist overhead)              52.45       19.07 ms     ±0.52%       19.05 ms       19.36 ms
00. C Node (generate+sort in C â reference)                               47.58       21.02 ms     ±0.24%       21.01 ms       21.18 ms
02. Rust NIF (list protocol â full copy)                                  47.57       21.02 ms     ±7.79%       20.01 ms       23.79 ms
10. C Node (distributed Erlang)                                             42.75       23.39 ms     ±2.58%       23.30 ms       24.69 ms
09. Explorer (Polars)                                                       34.51       28.98 ms    ±10.31%       27.72 ms       35.17 ms
01b. :lists.sort (Erlang â native term comparison, no fun overhead         8.31      120.38 ms    ±12.27%      116.86 ms      157.54 ms
01a. Enum.sort (Elixir â fun call per comparison)                          8.29      120.62 ms    ±12.46%      114.85 ms      158.64 ms
08. Nx (EXLA)                                                                5.38      185.92 ms     ±1.22%      185.80 ms      190.64 ms
14. Dux (DuckDB)                                                             4.56      219.10 ms     ±9.49%      232.20 ms      246.81 ms
11. ETS ordered_set (AVL tree insert + tab2list)                             1.19      838.59 ms     ±2.23%      835.43 ms      878.19 ms
13. Atomics (quicksort on off-heap i64 array)                                1.06      943.09 ms     ±7.91%      975.45 ms     1012.20 ms
07. Nx (BinaryBackend)                                                       0.32     3159.20 ms     ±3.59%     3208.75 ms     3229.50 ms

Comparison:
06. Rust NIF mmap (sort-only, data pre-loaded)                              92.36
04. Rust NIF (binary ref â in-place UNSAFE)                               92.17 - 1.00x slower +0.0232 ms
00. Rust NIF (Elixir-instructed sort â measures NIF call overhead)        91.68 - 1.01x slower +0.0803 ms
03. Rust NIF (binary ref â safe copy)                                     90.56 - 1.02x slower +0.22 ms
05. Rust NIF mmap (full: write+sort+read)                                   89.58 - 1.03x slower +0.34 ms
00. Rust NIF (generate+sort in Rust â reference)                          78.39 - 1.18x slower +1.93 ms
12. Port stdin/stdout (Rust via pipe)                                       55.98 - 1.65x slower +7.04 ms
00. C Node (Elixir-instructed sort â measures dist overhead)              52.45 - 1.76x slower +8.24 ms
00. C Node (generate+sort in C â reference)                               47.58 - 1.94x slower +10.19 ms
02. Rust NIF (list protocol â full copy)                                  47.57 - 1.94x slower +10.19 ms
10. C Node (distributed Erlang)                                             42.75 - 2.16x slower +12.56 ms
09. Explorer (Polars)                                                       34.51 - 2.68x slower +18.15 ms
01b. :lists.sort (Erlang â native term comparison, no fun overhead         8.31 - 11.12x slower +109.56 ms
01a. Enum.sort (Elixir â fun call per comparison)                          8.29 - 11.14x slower +109.79 ms
08. Nx (EXLA)                                                                5.38 - 17.17x slower +175.10 ms
14. Dux (DuckDB)                                                             4.56 - 20.24x slower +208.28 ms
11. ETS ordered_set (AVL tree insert + tab2list)                             1.19 - 77.46x slower +827.76 ms
13. Atomics (quicksort on off-heap i64 array)                                1.06 - 87.11x slower +932.26 ms
07. Nx (BinaryBackend)                                                       0.32 - 291.80x slower +3148.38 ms
```

## Rust Benchmark

```bash
$ cd rust_bench && cargo bench
     Finished `bench` profile [optimized] target(s) in 0.03s
     Running benches/sort_bench.rs (target/release/deps/sort_bench-a6fcc1a746aba8f6)
Gnuplot not found, using plotters backend
sort_1m_i64/generate_and_sort/1000000
                        time:   [12.726 ms 12.735 ms 12.746 ms]
                        change: [-0.3824% -0.2054% -0.0539%] (p = 0.01 < 0.05)
                        Change within noise threshold.
Found 8 outliers among 100 measurements (8.00%)
  4 (4.00%) high mild
  4 (4.00%) high severe
sort_1m_i64/sort_only/1000000
                        time:   [10.947 ms 10.953 ms 10.960 ms]
                        change: [-1.1780% -0.9444% -0.7144%] (p = 0.00 < 0.05)
                        Change within noise threshold.
Found 3 outliers among 100 measurements (3.00%)
  2 (2.00%) high mild
  1 (1.00%) high severe
sort_1m_i64/sort_presorted/1000000
                        time:   [393.99 µs 394.25 µs 394.56 µs]
                        change: [-0.0056% +0.2619% +0.4986%] (p = 0.03 < 0.05)
                        Change within noise threshold.
Found 10 outliers among 100 measurements (10.00%)
  4 (4.00%) high mild
  6 (6.00%) high severe
sort_1m_i64/sort_reverse_sorted/1000000
                        time:   [10.302 ms 10.307 ms 10.313 ms]
                        change: [-0.0571% +0.0297% +0.1088%] (p = 0.50 > 0.05)
                        No change in performance detected.
Found 5 outliers among 100 measurements (5.00%)
  4 (4.00%) high mild
  1 (1.00%) high severe
```
  
## C benchmark

```
$ ./c_bench/bench_sort
Unable to determine clock rate from sysctl: hw.cpufrequency: No such file or directory
This does not affect benchmark measurements, only the metadata output.
***WARNING*** Failed to set thread affinity. Estimated CPU frequency may be incorrect.
2026-04-11T13:19:49+02:00
Running ./c_bench/bench_sort
Run on (10 X 24 MHz CPU s)
CPU Caches:
  L1 Data 64 KiB
  L1 Instruction 128 KiB
  L2 Unified 4096 KiB (x10)
Load Average: 1.61, 2.17, 2.17
---------------------------------------------------------------------------------------------------------------
Benchmark                                                     Time             CPU   Iterations UserCounters...
---------------------------------------------------------------------------------------------------------------
BM_GenerateAndSort/1000000/min_time:2.000                  81.5 ms         81.4 ms           34 items_per_second=12.2811M/s
BM_SortOnly/1000000/min_time:2.000                         79.3 ms         79.3 ms           35 items_per_second=12.6101M/s
BM_SortPresorted/1000000/min_time:2.000                    3.33 ms         3.33 ms          842 items_per_second=300.186M/s
BM_SortReverseSorted/1000000/min_time:2.000                14.4 ms         14.4 ms          193 items_per_second=69.3925M/s
BM_StdSort_GenerateAndSort/1000000/min_time:2.000          20.9 ms         20.9 ms          134 items_per_second=47.9294M/s
BM_StdSort_SortOnly/1000000/min_time:2.000                 19.2 ms         19.2 ms          146 items_per_second=52.1485M/s
BM_StdSort_SortPresorted/1000000/min_time:2.000           0.970 ms        0.970 ms         2858 items_per_second=1.03138G/s
BM_StdSort_SortReverseSorted/1000000/min_time:2.000        1.60 ms         1.60 ms         1746 items_per_second=624.192M/s
BM_PdqSort_GenerateAndSort/1000000/min_time:2.000          20.4 ms         20.4 ms          137 items_per_second=48.9817M/s
BM_PdqSort_SortOnly/1000000/min_time:2.000                 18.6 ms         18.6 ms          150 items_per_second=53.7405M/s
BM_PdqSort_SortPresorted/1000000/min_time:2.000           0.879 ms        0.879 ms         3161 items_per_second=1.13765G/s
BM_PdqSort_SortReverseSorted/1000000/min_time:2.000        1.36 ms         1.36 ms         2051 items_per_second=734.028M/s
BM_NanoSort_GenerateAndSort/1000000/min_time:2.000         18.3 ms         18.3 ms          154 items_per_second=54.6503M/s
BM_NanoSort_SortOnly/1000000/min_time:2.000                16.4 ms         16.4 ms          170 items_per_second=60.9166M/s
BM_NanoSort_SortPresorted/1000000/min_time:2.000           18.4 ms         18.4 ms          152 items_per_second=54.4898M/s
BM_NanoSort_SortReverseSorted/1000000/min_time:2.000       15.6 ms         15.6 ms          179 items_per_second=64.1416M/s
```