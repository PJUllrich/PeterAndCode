//! Standalone Rust sort benchmark using Criterion.
//!
//! This measures pure Rust sorting speed with no BEAM involvement,
//! providing the reference ceiling for the Elixir benchmarks.
//!
//! Run:  cargo bench  (from the rust_bench/ directory)

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};

const N: usize = 1_000_000;
const MAX_VAL: u64 = 1_000_000_000;

/// Same xorshift64 PRNG as the C++ benchmark and NIF.
fn xorshift64(state: &mut u64) -> i64 {
    let mut x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    (x % MAX_VAL) as i64
}

fn generate_data(n: usize) -> Vec<i64> {
    let mut rng_state: u64 = 0xdeadbeefcafe1234;
    (0..n).map(|_| xorshift64(&mut rng_state)).collect()
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
    // Uses iter() instead of iter_batched so that alloc + dealloc are
    // included in the measurement, matching the C++ benchmark and the
    // real use case (receive data, sort, return).
    group.bench_with_input(BenchmarkId::new("sort_only", N), &N, |b, &n| {
        let source = generate_data(n);
        b.iter(|| {
            let mut data = source.clone();
            data.sort_unstable();
            data
        });
    });

    // Measure sort on already-sorted data (best case)
    group.bench_with_input(BenchmarkId::new("sort_presorted", N), &N, |b, &n| {
        let mut source = generate_data(n);
        source.sort_unstable();
        b.iter(|| {
            let mut data = source.clone();
            data.sort_unstable();
            data
        });
    });

    // Measure sort on reverse-sorted data (worst case for some algorithms)
    group.bench_with_input(
        BenchmarkId::new("sort_reverse_sorted", N),
        &N,
        |b, &n| {
            let mut source = generate_data(n);
            source.sort_unstable_by(|a, b| b.cmp(a));
            b.iter(|| {
                let mut data = source.clone();
                data.sort_unstable();
                data
            });
        },
    );

    group.finish();
}

criterion_group!(benches, bench_sort);
criterion_main!(benches);
