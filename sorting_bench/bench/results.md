# Benchmark Results

Sorting 1,000,000 random `i64` integers.

## Elixir Benchmark

| Name | ips | average | deviation | median | 99th % |
|------|----:|--------:|----------:|-------:|-------:|
| R02. Rust NIF (Elixir-instructed sort — NIF call overhead) | 90.68 | 11.03 ms | ±0.85% | 11.04 ms | 11.27 ms |
| B02. Rust NIF (binary ref — in-place UNSAFE) | 89.80 | 11.14 ms | ±1.28% | 11.13 ms | 11.62 ms |
| B04. Rust NIF mmap (sort-only, data pre-loaded) | 89.24 | 11.21 ms | ±1.47% | 11.19 ms | 11.81 ms |
| B01. Rust NIF (binary ref — safe copy) | 88.14 | 11.35 ms | ±1.16% | 11.34 ms | 11.68 ms |
| B03. Rust NIF mmap (full: write+sort+read) | 86.52 | 11.56 ms | ±1.30% | 11.53 ms | 11.97 ms |
| R01. Rust NIF (generate+sort in Rust — reference) | 77.14 | 12.96 ms | ±1.92% | 12.97 ms | 13.48 ms |
| B05. Port stdin/stdout (Rust via pipe) | 60.81 | 16.45 ms | ±2.34% | 16.30 ms | 17.64 ms |
| A11. FEnum (NIF round-trip: list→Rust→sort→list) | 54.51 | 18.35 ms | ±8.64% | 17.34 ms | 21.25 ms |
| R04. C Node (Elixir-instructed sort — dist overhead) | 52.42 | 19.08 ms | ±0.32% | 19.07 ms | 19.30 ms |
| R03. C Node (generate+sort in C — reference) | 47.56 | 21.03 ms | ±0.29% | 21.02 ms | 21.22 ms |
| A02. Rust NIF (list protocol — full copy) | 47.32 | 21.13 ms | ±7.65% | 20.15 ms | 24.02 ms |
| B06. C Node (distributed Erlang) | 39.03 | 25.62 ms | ±2.84% | 25.98 ms | 26.65 ms |
| A09. Explorer (Polars) | 33.78 | 29.60 ms | ±9.25% | 28.60 ms | 35.58 ms |
| A00. List→binary conversion (no sort — overhead) | 23.13 | 43.24 ms | ±7.69% | 41.99 ms | 49.66 ms |
| A03. Rust NIF binary round-trip (list→binary→sort→list) | 16.25 | 61.54 ms | ±6.49% | 61.77 ms | 86.39 ms |
| A12. Port round-trip (list→binary→pipe→sort→pipe→list) | 14.85 | 67.35 ms | ±5.73% | 66.87 ms | 86.75 ms |
| A04. Rust NIF mmap round-trip (list→binary→mmap→sort→mmap→list) | 13.85 | 72.18 ms | ±10.60% | 69.29 ms | 97.08 ms |
| A13. C Node round-trip (list→binary→dist→sort→dist→list) | 11.60 | 86.18 ms | ±9.25% | 85.59 ms | 113.02 ms |
| A01b. :lists.sort (Erlang — native term comparison) | 8.84 | 113.11 ms | ±14.46% | 109.12 ms | 155.73 ms |
| A01a. Enum.sort (Elixir — fun call per comparison) | 8.64 | 115.69 ms | ±13.21% | 111.28 ms | 168.87 ms |
| A08. Nx (EXLA) | 5.63 | 177.74 ms | ±0.94% | 177.52 ms | 182.81 ms |
| A10. Dux (DuckDB) | 4.82 | 207.57 ms | ±9.97% | 219.36 ms | 238.17 ms |
| A05. ETS ordered_set (AVL tree insert + tab2list) | 1.14 | 875.24 ms | ±2.96% | 877.11 ms | 907.16 ms |
| A06. Atomics (quicksort on off-heap i64 array) | 1.00 | 1000.75 ms | ±6.46% | 1020.95 ms | 1053.70 ms |
| A07. Nx (BinaryBackend) | 0.31 | 3253.71 ms | ±5.27% | 3269.11 ms | 3444.88 ms |

### Comparison

| Name | ips | vs fastest |
|------|----:|-----------:|
| R02. Rust NIF (Elixir-instructed sort) | 90.68 | baseline |
| B02. Rust NIF (binary ref — in-place UNSAFE) | 89.80 | 1.01x slower +0.11 ms |
| B04. Rust NIF mmap (sort-only) | 89.24 | 1.02x slower +0.18 ms |
| B01. Rust NIF (binary ref — safe copy) | 88.14 | 1.03x slower +0.32 ms |
| B03. Rust NIF mmap (full cycle) | 86.52 | 1.05x slower +0.53 ms |
| R01. Rust NIF (generate+sort in Rust) | 77.14 | 1.18x slower +1.94 ms |
| B05. Port stdin/stdout (Rust via pipe) | 60.81 | 1.49x slower +5.42 ms |
| A11. FEnum (NIF round-trip) | 54.51 | 1.66x slower +7.32 ms |
| R04. C Node (Elixir-instructed sort) | 52.42 | 1.73x slower +8.05 ms |
| R03. C Node (generate+sort in C) | 47.56 | 1.91x slower +10.00 ms |
| A02. Rust NIF (list protocol) | 47.32 | 1.92x slower +10.10 ms |
| B06. C Node (distributed Erlang) | 39.03 | 2.32x slower +14.59 ms |
| A09. Explorer (Polars) | 33.78 | 2.68x slower +18.57 ms |
| A00. List→binary conversion (no sort) | 23.13 | 3.92x slower +32.21 ms |
| A03. Rust NIF binary round-trip | 16.25 | 5.58x slower +50.51 ms |
| A12. Port round-trip | 14.85 | 6.11x slower +56.32 ms |
| A04. Rust NIF mmap round-trip | 13.85 | 6.55x slower +61.15 ms |
| A13. C Node round-trip | 11.60 | 7.82x slower +75.15 ms |
| A01b. :lists.sort | 8.84 | 10.26x slower +102.08 ms |
| A01a. Enum.sort | 8.64 | 10.49x slower +104.66 ms |
| A08. Nx (EXLA) | 5.63 | 16.12x slower +166.72 ms |
| A10. Dux (DuckDB) | 4.82 | 18.82x slower +196.55 ms |
| A05. ETS ordered_set | 1.14 | 79.37x slower +864.21 ms |
| A06. Atomics (quicksort) | 1.00 | 90.75x slower +989.72 ms |
| A07. Nx (BinaryBackend) | 0.31 | 295.06x slower +3242.69 ms |

## Rust Benchmark

Rust `sort_unstable` (pdqsort) via Criterion.

| Benchmark | Time |
|-----------|-----:|
| generate_and_sort | 12.74 ms |
| sort_only | 10.96 ms |
| sort_presorted | 394.86 us |
| sort_reverse_sorted | 10.35 ms |

## C Benchmark

Run on Apple Silicon (10 cores). Google Benchmark with `min_time:2.000`.

| Benchmark | Time | items/s |
|-----------|-----:|--------:|
| qsort — generate_and_sort | 80.5 ms | 12.41 M/s |
| qsort — sort_only | 78.8 ms | 12.69 M/s |
| qsort — sort_presorted | 3.33 ms | 300.54 M/s |
| qsort — sort_reverse_sorted | 14.4 ms | 69.44 M/s |
| std::sort — generate_and_sort | 20.9 ms | 47.84 M/s |
| std::sort — sort_only | 19.1 ms | 52.46 M/s |
| std::sort — sort_presorted | 0.968 ms | 1.03 G/s |
| std::sort — sort_reverse_sorted | 1.60 ms | 626.93 M/s |
| pdqsort — generate_and_sort | 20.5 ms | 48.90 M/s |
| pdqsort — sort_only | 18.6 ms | 53.72 M/s |
| pdqsort — sort_presorted | 0.888 ms | 1.13 G/s |
| pdqsort — sort_reverse_sorted | 1.36 ms | 735.71 M/s |
| nanosort — generate_and_sort | 18.1 ms | 55.16 M/s |
| nanosort — sort_only | 16.4 ms | 61.06 M/s |
| nanosort — sort_presorted | 18.3 ms | 54.63 M/s |
| nanosort — sort_reverse_sorted | 15.6 ms | 64.27 M/s |
