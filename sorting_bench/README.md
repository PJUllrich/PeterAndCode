# Sorting Bench

Benchmarking different approaches to sorting 1 million integers in Elixir,
focusing on **copy costs** and **sorting speed**.

## Approaches

| # | Approach | Copy Cost | Sort Engine | Notes |
|---|----------|-----------|-------------|-------|
| 1 | `Enum.sort` | N/A (pure Elixir) | Merge sort | Baseline |
| 2 | Rust NIF (list protocol) | 2x full copy (list→Vec→list) | `sort_unstable` | Reference for NIF copy overhead |
| 3 | Rust NIF (binary ref, safe) | 1x memcpy (new binary out) | `sort_unstable` | Refc binary passed by reference |
| 4 | Rust NIF (binary ref, in-place) | 0 copies | `sort_unstable` | **UNSAFE** — mutates "immutable" binary |
| 5 | Rust NIF mmap (full cycle) | 2x memcpy (write + read) | `sort_unstable` | Shared memory via `/dev/shm` |
| 6 | Rust NIF mmap (sort-only) | 0 copies | `sort_unstable` | Data pre-loaded, sort in-place |
| 7 | Nx (BinaryBackend) | tensor conversion | Nx.sort | Pure Elixir tensor ops |
| 8 | Nx (EXLA) | tensor conversion | XLA JIT | JIT-compiled, runs on CPU |
| 9 | Explorer (Polars) | Series conversion | Polars (Rust) | DataFrame library |
| 10 | C Node (distributed Erlang) | Full serialization over TCP | C `qsort` | Highest copy cost, near-native speed |

## Prerequisites

- Elixir >= 1.14
- Rust (for building the NIF)
- GCC + Erlang dev headers (for the C Node)

## Setup

```bash
# Install Elixir deps
mix deps.get

# Build the C Node
make -C c_node

# Compile everything (this also builds the Rust NIF via Rustler)
mix compile
```

## Running the Benchmark

```bash
# Without C Node (simplest)
mix run bench/run.exs

# With C Node (requires BEAM distribution)
elixir --sname bench --cookie sorting_bench -S mix run bench/run.exs
```

## How It Works

### Data Format

All native approaches (NIF, mmap, C Node) use a packed binary of native-endian
signed 64-bit integers. For 1M elements, that's an 8 MB binary.

BEAM refc binaries (>64 bytes) are passed to NIFs **by reference** — no copy.
This is the key insight behind approaches 3 and 4.

### Copy Cost Spectrum

```
Zero copy ◄─────────────────────────────────────► Maximum copy

  mmap sort-only     binary in-place     binary safe     list protocol     C Node
  (0 copies)         (0 copies)          (1 memcpy)      (2 list walks)    (2x serialize+TCP)
```

### Safety Trade-offs

- **In-place binary sort** (approach 4): Mutates a binary the BEAM considers immutable.
  Safe only if the caller holds the sole reference (ensured via `:binary.copy/1` in the benchmark).
- **mmap**: Proper shared memory — the sort is truly in-place with no safety concerns.
  The write/read steps are explicit memcpy operations.
