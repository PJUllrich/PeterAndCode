Running benches/sort_bench.rs (target/release/deps/sort_bench-a6fcc1a746aba8f6)
Gnuplot not found, using plotters backend
sort_1m_i64/generate_and_sort/1000000
                        time:   [12.745 ms 12.761 ms 12.782 ms]
                        change: [-38.506% -38.409% -38.296%] (p = 0.00 < 0.05)
                        Performance has improved.
Found 11 outliers among 100 measurements (11.00%)
  2 (2.00%) high mild
  9 (9.00%) high severe
sort_1m_i64/sort_only/1000000
                        time:   [11.033 ms 11.057 ms 11.082 ms]
                        change: [-1.3772% -1.1513% -0.9043%] (p = 0.00 < 0.05)
                        Change within noise threshold.
sort_1m_i64/sort_presorted/1000000
                        time:   [393.08 µs 393.21 µs 393.34 µs]
                        change: [+31.772% +32.118% +32.502%] (p = 0.00 < 0.05)
                        Performance has regressed.
Found 10 outliers among 100 measurements (10.00%)
  5 (5.00%) high mild
  5 (5.00%) high severe
sort_1m_i64/sort_reverse_sorted/1000000
                        time:   [10.298 ms 10.304 ms 10.311 ms]
                        change: [-2.6889% -2.5470% -2.4145%] (p = 0.00 < 0.05)
                        Performance has improved.
Found 7 outliers among 100 measurements (7.00%)
  2 (2.00%) high mild
  5 (5.00%) high severe