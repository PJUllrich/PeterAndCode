//! Standalone Rust sort benchmark using Criterion.
//!
//! This measures pure Rust sorting speed with no BEAM involvement,
//! providing the reference ceiling for the Elixir benchmarks.
//!
//! Run:  cargo bench  (from the rust_bench/ directory)

use criterion::{criterion_group, criterion_main, BatchSize, BenchmarkId, Criterion};
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

const N: usize = 1_000_000;
const MAX_VAL: i64 = 1_000_000_000;

fn generate_data(n: usize) -> Vec<i64> {
    let mut rng = StdRng::seed_from_u64(0xdeadbeefcafe1234);
    (0..n).map(|_| rng.gen_range(0..MAX_VAL)).collect()
}

fn bench_sort(c: &mut Criterion) {
    let mut group = c.benchmark_group("sort_1m_i64");

    // Measure generate + sort together (matches the NIF generate_and_sort)
    group.bench_with_input(
        BenchmarkId::new("generate_and_sort", N),
        &N,
        |b, &n| {
            b.iter(|| {
                let mut data = generate_data(n);
                data.sort_unstable();
                data
            });
        },
    );

    // Measure sort-only (data pre-generated, fresh copy per iteration)
    group.bench_with_input(BenchmarkId::new("sort_only", N), &N, |b, &n| {
        b.iter_batched(
            || generate_data(n),
            |mut data| {
                data.sort_unstable();
                data
            },
            BatchSize::LargeInput,
        );
    });

    // Measure sort on already-sorted data (best case)
    group.bench_with_input(BenchmarkId::new("sort_presorted", N), &N, |b, &n| {
        b.iter_batched(
            || {
                let mut data = generate_data(n);
                data.sort_unstable();
                data
            },
            |mut data| {
                data.sort_unstable();
                data
            },
            BatchSize::LargeInput,
        );
    });

    // Measure sort on reverse-sorted data (worst case for some algorithms)
    group.bench_with_input(
        BenchmarkId::new("sort_reverse_sorted", N),
        &N,
        |b, &n| {
            b.iter_batched(
                || {
                    let mut data = generate_data(n);
                    data.sort_unstable_by(|a, b| b.cmp(a));
                    data
                },
                |mut data| {
                    data.sort_unstable();
                    data
                },
                BatchSize::LargeInput,
            );
        },
    );

    group.finish();
}

criterion_group!(benches, bench_sort);
criterion_main!(benches);
