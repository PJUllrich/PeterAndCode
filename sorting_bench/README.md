# Sorting Bench

Benchmarking different approaches to sorting **1 million integers** in Elixir,
focusing on two variables: **copy cost** (how data moves between the BEAM and
the sort engine) and **sorting speed** (how fast the actual sort runs).

The ideal would be zero copy cost with Rust-level sorting speed. This project
measures how close each approach gets.

## Test Setup

Each benchmark iteration simulates a realistic function call: **allocate a
buffer, sort the data, free the buffer**. This matches the real-world scenario
where a C/Rust function receives an array, sorts it, and returns the result.

All benchmarks test three input patterns:

- **Random** — average case, uniformly distributed integers
- **Presorted** — best case for adaptive algorithms (e.g. pdqsort detects sorted runs in near-linear time)
- **Reverse sorted** — classic worst case for naive quicksort implementations

The standalone Rust and C++ benchmarks use the same **xorshift64 PRNG** with
identical seeds, so they sort the exact same data for fair comparison.

## Data Format

All native approaches use a packed binary of **native-endian signed 64-bit
integers**. For 1M elements that's an **8 MB binary**.

This matters because the BEAM treats binaries >64 bytes as **refc binaries**
(reference-counted, heap-external). When passed to a NIF, the NIF receives a
pointer to the data — no copy. This is the key insight behind several approaches
below.

---

## Approaches — Detailed Data Flow

### 01a. Enum.sort (Elixir)

**Sort engine:** Erlang merge sort (via `:lists.sort/2`)
**Copy cost:** None (data stays on the BEAM heap)

```
Elixir list (BEAM heap)
  │
  ▼
Enum.sort/1 calls :lists.sort/2 with &<=/2 as comparator
  │
  │  For each comparison: calls the Elixir fun &<=/2
  │  This is a function call per comparison (~20M calls for 1M elements)
  │
  ▼
New sorted list (BEAM heap)
```

**Pros:** No interop overhead. No data leaves the BEAM process.

**Cons:** Merge sort is O(n log n) but allocates many intermediate list cells.
The per-comparison fun call adds overhead versus native term comparison.

---

### 01b. :lists.sort (Erlang)

**Sort engine:** Erlang merge sort (`:lists.sort/1`)
**Copy cost:** None

```
Elixir list (BEAM heap)
  │
  ▼
:lists.sort/1 — uses native Erlang term ordering (=<) directly
  │
  │  No function call per comparison — the comparator is baked into
  │  the BEAM's C implementation of term comparison
  │
  ▼
New sorted list (BEAM heap)
```

**Pros:** Fastest pure-BEAM sort. Same algorithm as Enum.sort but skips
~20M Elixir fun calls.

**Cons:** Still Erlang merge sort — fundamentally slower than native
introsort/pdqsort. Still allocates intermediate list cells.

---

### 02. Rust NIF — list protocol (full copy)

**Sort engine:** Rust `sort_unstable` (pdqsort — pattern-defeating quicksort)
**Copy cost:** 2 full copies (list→Vec on input, Vec→list on output)

```
Elixir list (BEAM heap)
  │
  │  Rustler walks the entire linked list, converting each element
  │  from an Erlang term to a Rust i64. Allocates a Vec<i64>.
  │  COPY 1: O(n) list traversal + allocation
  │
  ▼
Vec<i64> (Rust heap, inside NIF)
  │
  │  sort_unstable() — pdqsort, in-place, no allocation
  │
  ▼
Sorted Vec<i64> (Rust heap)
  │
  │  Rustler walks the Vec, converting each i64 back to an Erlang
  │  term and building a new linked list on the BEAM heap.
  │  COPY 2: O(n) Vec traversal + list construction
  │
  ▼
Sorted Elixir list (BEAM heap)
```

**Pros:** Uses the fastest sort algorithm available. Straightforward Rustler API.

**Cons:** Highest NIF copy cost. The two O(n) list walks (in + out) dominate
total time for large inputs. Each Erlang list cons cell must be individually
decoded/encoded.

---

### 03. Rust NIF — binary ref, safe copy

**Sort engine:** Rust `sort_unstable`
**Copy cost:** ~1 memcpy (allocate new binary for output)

```
Elixir binary, 8 MB (BEAM refc binary, heap-external)
  │
  │  NIF receives a Binary<'a> — a pointer to the BEAM's refc binary
  │  data. NO COPY on input (binary >64 bytes = passed by reference).
  │
  ▼
Binary slice (pointer into BEAM memory)
  │
  │  NIF allocates a new OwnedBinary (8 MB), does memcpy from input.
  │  COPY 1: single memcpy of 8 MB
  │
  ▼
OwnedBinary (NIF-owned memory)
  │
  │  Reinterpret bytes as &mut [i64], sort_unstable() in-place
  │
  ▼
Sorted OwnedBinary
  │
  │  Returned to BEAM — ownership transfers, no additional copy.
  │  BEAM now owns the binary as a new refc binary.
  │
  ▼
Sorted Elixir binary (BEAM refc binary)
```

**Pros:** Only one memcpy. Input is truly zero-copy (just a pointer).
Output ownership transfers cleanly. Much faster than the list protocol.

**Cons:** Still allocates 8 MB for the output binary. Caller must convert
the list to a packed binary beforehand (one-time cost).

---

### 04. Rust NIF — binary ref, in-place (UNSAFE)

**Sort engine:** Rust `sort_unstable`
**Copy cost:** 0 copies

```
Elixir binary, 8 MB (BEAM refc binary)
  │
  │  NIF receives Binary<'a> — pointer to BEAM's refc binary.
  │  NO COPY.
  │
  ▼
Binary slice (pointer into BEAM memory)
  │
  │  ⚠️ UNSAFE: casts the const pointer to *mut i64
  │  Sorts the BEAM's own binary data in-place.
  │  The BEAM considers this binary immutable — we violate that.
  │  ZERO COPIES.
  │
  ▼
Same binary, now sorted in BEAM memory
  │
  │  Returns :ok (no data in return value)
  │  Caller reads the same binary variable — it's now sorted.
  │
  ▼
Caller reads the mutated binary
```

**Pros:** Absolute zero copy. Fastest possible data path — the sort runs
directly on BEAM-owned memory. No allocation.

**Cons:** **Dangerously unsafe.** If any other BEAM process, binary reference,
or sub-binary points to this data, they see corrupted/sorted data unexpectedly.
The benchmark ensures safety by calling `:binary.copy/1` to create a
sole-reference copy before each iteration.

---

### 05. Rust NIF — mmap shared memory (full cycle)

**Sort engine:** Rust `sort_unstable`
**Copy cost:** 2 memcpy (write into mmap + read from mmap)

```
Elixir binary, 8 MB (BEAM refc binary)
  │
  │  mmap_write: NIF receives binary by reference (no copy),
  │  then does memcpy into the mmap'd region (/dev/shm tmpfs).
  │  COPY 1: memcpy 8 MB into shared memory
  │
  ▼
mmap region (/dev/shm, 8 MB)
  │
  │  mmap_sort: NIF reinterprets the mmap region as &mut [i64],
  │  sorts in-place. The data never leaves the mmap region.
  │  ZERO COPIES for the sort itself.
  │
  ▼
Sorted mmap region
  │
  │  mmap_read: NIF allocates a new OwnedBinary, does memcpy
  │  from mmap into the new binary.
  │  COPY 2: memcpy 8 MB out of shared memory
  │
  ▼
Sorted Elixir binary (BEAM refc binary)
```

**Pros:** The sort step is truly zero-copy. Shared memory persists across
NIF calls — useful if you sort repeatedly or multiple processes read the
result. The mmap is backed by tmpfs, so no disk I/O.

**Cons:** Full cycle has 2 memcpys — same as the list protocol in copy count
but much cheaper per byte (memcpy vs. list cell encode/decode). The mmap
resource setup is a one-time cost.

---

### 06. Rust NIF — mmap shared memory (sort-only)

**Sort engine:** Rust `sort_unstable`
**Copy cost:** 0 copies (data already in mmap)

```
mmap region (/dev/shm, 8 MB, pre-loaded via mmap_write)
  │
  │  mmap_sort: reinterpret as &mut [i64], sort_unstable() in-place
  │  ZERO COPIES.
  │
  ▼
Sorted mmap region
```

**Pros:** True zero-copy sort with no safety concerns (unlike approach 4).
The mmap region is explicitly mutable. Demonstrates the raw sort speed
when copy cost is completely eliminated.

**Cons:** Requires prior mmap_write to load data (excluded from this
benchmark via before_each). Reading the result back requires mmap_read
(an additional memcpy not measured here).

---

### 07. Nx — BinaryBackend

**Sort engine:** Pure Elixir tensor sort
**Copy cost:** List → tensor conversion + tensor → list conversion

```
Elixir list
  │
  │  Nx.tensor(list, type: :s64, backend: Nx.BinaryBackend)
  │  Walks the list, packs each integer into a flat binary in tensor format.
  │  COPY: O(n) conversion
  │
  ▼
Nx tensor (flat binary of i64, BinaryBackend)
  │
  │  Nx.sort/1 — implemented in pure Elixir (BinaryBackend).
  │  This is NOT native code. The sort runs on the BEAM.
  │
  ▼
Sorted tensor
  │
  │  Nx.to_list/1 — unpacks the tensor back into an Elixir list.
  │  COPY: O(n) conversion
  │
  ▼
Sorted Elixir list
```

**Pros:** Part of the Nx ecosystem. Clean API.

**Cons:** BinaryBackend runs entirely in Elixir — expected to be slower
than :lists.sort for this use case. Conversion overhead on both ends.
Nx is designed for GPU/TPU workloads, not CPU-bound integer sorts.

---

### 08. Nx — EXLA Backend

**Sort engine:** XLA JIT-compiled sort kernel
**Copy cost:** List → tensor (BEAM→XLA) + tensor → list (XLA→BEAM)

```
Elixir list
  │
  │  Nx.tensor(list, type: :s64, backend: EXLA.Backend)
  │  Walks the list, packs into a flat binary, transfers to XLA device memory.
  │  COPY: O(n) conversion + device transfer
  │
  ▼
XLA buffer (device memory, possibly CPU-side)
  │
  │  Nx.sort/1 — JIT-compiled by XLA into optimized machine code.
  │  Runs natively on CPU (or GPU if available).
  │
  ▼
Sorted XLA buffer
  │
  │  Nx.to_list/1 — transfers back from XLA, unpacks to Elixir list.
  │  COPY: device transfer + O(n) conversion
  │
  ▼
Sorted Elixir list
```

**Pros:** JIT-compiled native code. Potentially very fast for the sort itself.
Can run on GPU/TPU for massive parallelism.

**Cons:** JIT compilation overhead on first run. Data must cross the
BEAM↔XLA boundary twice. Designed for numerical computing workloads, not
general-purpose sorting.

---

### 09. Explorer — Polars

**Sort engine:** Polars (Rust, highly optimized for columnar data)
**Copy cost:** List → Series conversion + Series → list conversion

```
Elixir list
  │
  │  Explorer.Series.from_list(list)
  │  Walks the list, converts each element into Polars' internal
  │  columnar format (Arrow-compatible, off-BEAM-heap).
  │  COPY: O(n) conversion via Rustler NIF
  │
  ▼
Polars Series (Rust heap, Arrow format)
  │
  │  Explorer.Series.sort/1 — delegates to Polars' sort.
  │  Polars uses a highly optimized radix sort / introsort hybrid.
  │
  ▼
Sorted Polars Series
  │
  │  Explorer.Series.to_list/1 — converts back to an Elixir list.
  │  Walks the Polars array, builds Erlang terms.
  │  COPY: O(n) conversion via Rustler NIF
  │
  ▼
Sorted Elixir list
```

**Pros:** Polars is extremely fast for columnar operations. If your data is
already in Explorer DataFrames, the sort is nearly free.

**Cons:** Two NIF-mediated conversions (list↔Series). Overkill if you only
need a sort — Explorer is a full DataFrame library.

---

### 10. C Node — distributed Erlang protocol

**Sort engine:** C++ `std::sort` (introsort — quicksort/heapsort/insertion sort hybrid)
**Copy cost:** Full serialization over TCP loopback, twice

```
Elixir binary, 8 MB (BEAM refc binary)
  │
  │  send({:any, c_node}, {self(), {:sort, binary}})
  │  1. BEAM encodes the message into External Term Format (ETF)
  │  2. Writes ETF bytes to a TCP socket (loopback)
  │  COPY 1: ETF serialization + TCP send
  │
  ▼
TCP loopback socket
  │
  │  3. C Node reads from socket into a buffer
  │  4. ei_decode_binary: extracts raw bytes, malloc's a copy
  │  COPY 2: TCP recv + malloc + memcpy
  │
  ▼
C++ heap (malloc'd int64_t array)
  │
  │  std::sort() — introsort with inlined comparator
  │
  ▼
Sorted C++ array
  │
  │  5. ei_encode_binary: wraps sorted data into ETF
  │  6. ei_send: writes to TCP socket
  │  COPY 3: ETF serialization + TCP send
  │
  ▼
TCP loopback socket
  │
  │  7. BEAM reads from socket, decodes ETF
  │  8. Creates a new refc binary with the sorted data
  │  COPY 4: TCP recv + ETF decode + binary allocation
  │
  ▼
Sorted Elixir binary (BEAM refc binary)
```

**Pros:** The C Node runs in its own OS process — a crash cannot bring down
the BEAM. `std::sort` is very fast for the actual computation (comparator is
inlined, unlike `qsort`'s function pointer). Full Erlang distribution protocol
means you could run this on a different machine.

**Cons:** Highest copy cost of all approaches. Data is serialized, sent over
TCP, deserialized, sorted, serialized again, sent back, and deserialized again.
For 8 MB of data over loopback, the TCP overhead dominates.

---

### 11. ETS ordered_set (AVL tree)

**Sort engine:** BEAM's built-in AVL tree (ETS ordered_set)
**Copy cost:** Each element copied into ETS + all elements copied out

```
Elixir list
  │
  │  For each element: :ets.insert(table, {{value, index}})
  │  ETS copies the term from the process heap into ETS-owned memory.
  │  The ordered_set maintains an AVL tree — each insert is O(log n).
  │  COPY IN: n individual term copies + n AVL tree insertions
  │
  ▼
ETS table (AVL tree, off-heap, sorted by key)
  │
  │  :ets.tab2list(table)
  │  Walks the AVL tree in-order, builds a new list on the process heap.
  │  Each element is copied from ETS memory back to the process.
  │  COPY OUT: full tree traversal + n term copies + list construction
  │
  ▼
Sorted list of {{value, index}} tuples
  │
  │  Enum.map to extract the values
  │
  ▼
Sorted Elixir list
```

**Pros:** Built into the BEAM — no external dependencies. ETS is concurrent-safe
and can be shared across processes. The data is sorted as it's inserted (no
separate sort step).

**Cons:** Very high overhead. Each of the 1M inserts involves a term copy into
ETS memory + AVL tree rebalancing. The Enum.with_index and Enum.map passes add
further list traversals. Expected to be slower than all other approaches for
this use case.

---

### 12. Port stdin/stdout (Rust via pipe)

**Sort engine:** Rust `sort_unstable`
**Copy cost:** 2 kernel pipe buffer copies (one per direction)

```
Elixir binary, 8 MB (BEAM refc binary)
  │
  │  Port.command(port, binary)
  │  BEAM writes a 4-byte length header + 8 MB payload to the pipe fd.
  │  The kernel copies data into the pipe buffer.
  │  COPY 1: write() syscall — kernel copies BEAM memory → pipe buffer
  │
  ▼
Kernel pipe buffer
  │
  │  Rust process reads from stdin.
  │  Kernel copies from pipe buffer into Rust's userspace buffer.
  │  COPY 2: read() syscall — kernel copies pipe buffer → Rust heap
  │
  ▼
Vec<u8> (Rust heap)
  │
  │  Reinterpret as &mut [i64], sort_unstable() in-place
  │
  ▼
Sorted data (Rust heap)
  │
  │  Write 4-byte length header + sorted data to stdout.
  │  COPY 3: write() syscall — kernel copies Rust memory → pipe buffer
  │
  ▼
Kernel pipe buffer
  │
  │  BEAM reads from port fd, creates a new refc binary.
  │  COPY 4: read() syscall — kernel copies pipe buffer → BEAM memory
  │
  ▼
Sorted Elixir binary (BEAM refc binary)
```

**Pros:** Crash isolation (like C Node) — the Rust process cannot crash the
BEAM. Simpler setup than a C Node (no distribution protocol, no epmd).
Standard Unix pipe interface works with any language.

**Cons:** 4 kernel copies (2 per direction: userspace→kernel→userspace).
For 8 MB of data, the pipe throughput is the bottleneck, not the sort.
Pipe buffer is typically 64 KB, so the kernel must do many small transfers.

---

### 13. Atomics (quicksort on off-heap i64 array)

**Sort engine:** Pure Elixir quicksort on `:atomics` array
**Copy cost:** List → atomics (n atomic writes) + atomics → list (n atomic reads)

```
Elixir list
  │
  │  For each element: :atomics.put(arr, i, value)
  │  Writes each integer into a fixed-size, off-heap, mutable array
  │  of 64-bit atomic integers.
  │  COPY IN: n atomic writes (each with memory barrier)
  │
  ▼
:atomics array (off-heap, mutable, 64-bit signed integers)
  │
  │  Quicksort implemented in pure Elixir:
  │  Every comparison = :atomics.get (atomic read)
  │  Every swap = 2x :atomics.get + 2x :atomics.put (atomic ops)
  │  O(n log n) atomic operations total
  │
  ▼
Sorted :atomics array
  │
  │  For each element: :atomics.get(arr, i)
  │  Reads back into a new Elixir list.
  │  COPY OUT: n atomic reads + list construction
  │
  ▼
Sorted Elixir list
```

**Pros:** Uses a true mutable array — no linked list overhead for the sort
itself. `:atomics` is built into OTP, no external dependencies. The array
is off-heap and process-safe, so a parallel sort is theoretically possible.

**Cons:** Every array access goes through an atomic operation with a memory
barrier, which is massive overkill for single-threaded sorting. The sort
algorithm runs in interpreted Elixir, not native code. A fun curiosity,
not a practical approach.

---

### 14. Dux (DuckDB)

**Sort engine:** DuckDB's analytical SQL engine
**Copy cost:** List → DataFrame (one conversion) + sort + DataFrame → list (one conversion)

```
Elixir list
  │
  │  Enum.map(&%{v: &1}) to wrap each integer in a map
  │  Dux.from_list(list_of_maps) — converts to a DuckDB-backed DataFrame.
  │  Data is transferred from the BEAM into DuckDB's columnar storage.
  │  COPY IN: O(n) conversion via ADBC/NIF
  │
  ▼
DuckDB table (columnar, off-heap)
  │
  │  Dux.sort_by(:v) — compiles to SQL ORDER BY, executed by DuckDB.
  │  DuckDB uses an optimized sort (typically radix sort for integers).
  │
  ▼
Sorted DuckDB result set
  │
  │  Dux.to_columns() — transfers sorted data back to Elixir.
  │  COPY OUT: O(n) conversion via ADBC/NIF
  │
  ▼
Sorted Elixir list
```

**Pros:** DuckDB is a high-performance analytical engine. If your data is
already in DuckDB (e.g., loaded from Parquet/CSV), the sort is nearly free.
Lazy evaluation means operations can be fused.

**Cons:** Two conversions (list↔DataFrame). Wrapping integers in maps for
`from_list` adds overhead. Overkill for sorting — DuckDB is a full SQL engine.

---

## Reference Benchmarks (Elixir-instructed)

These benchmarks isolate the BEAM↔native communication overhead:

### Rust NIF — generate+sort (reference)
Generates 1M random i64s entirely inside the NIF, sorts them, returns `:ok`.
No data crosses the BEAM/Rust boundary. This is the theoretical speed ceiling.

### Rust NIF — Elixir-instructed (trigger_sort)
Data is pre-generated in Rust (via `prepare_sort`, excluded from timing).
Elixir calls `trigger_sort` — the NIF sorts its pre-stored Vec and returns `:ok`.
The measured time = NIF function call overhead + pure sort time.

### C Node — generate+sort (reference)
Same as the NIF version but inside the C Node process (C++ `std::sort`).

### C Node — Elixir-instructed (trigger_sort)
Data is pre-generated in the C Node (via `prepare_sort`, excluded from timing).
Elixir sends `{:trigger_sort, :go}`, C Node sorts with `std::sort` and replies `:ok`.
The measured time = distribution protocol round-trip (tiny atoms) + pure sort time.

By comparing `trigger_sort` against the data-passing approaches, you see
exactly how much wall time is spent on copying/serialization.

---

## Copy Cost Spectrum

```
Zero copy ◄──────────────────────────────────────────────────────────────────────────► Maximum copy

 NIF          NIF binary    NIF binary    mmap full    NIF list    Explorer/   Port        C Node       Atomics      ETS
 trigger_sort in-place      safe copy     cycle        protocol    Dux         pipe        dist TCP     (:atomics)   ordered_set
 (0 copies)   (0 copies)    (1 memcpy)    (2 memcpy)   (2 list     (2 NIF      (4 kernel   (4 ETF       (2n atomic   (2n term
              UNSAFE                                    walks)      conv)       copies)     serialize    ops)         copies +
                                                                                            + TCP)                    AVL tree)
```

---

## Sorting Algorithms

| Algorithm | Used by | Random | Presorted | Reverse sorted |
|---|---|---|---|---|
| **Merge sort** | Erlang (`:lists.sort`) | O(n log n) | O(n log n) | O(n log n) |
| **pdqsort** (pattern-defeating quicksort) | Rust (`sort_unstable`) | O(n log n) | O(n) | O(n log n) |
| **Introsort** (quicksort + heapsort) | C++ `std::sort` (standalone bench + C Node) | O(n log n) | O(n log n) | O(n log n) |
| **AVL tree insert** | ETS `ordered_set` | O(n log n) | O(n log n) | O(n log n) |
| **Quicksort** (Elixir on `:atomics`) | Atomics | O(n log n) | O(n log n) | O(n^2)* |
| **Radix/introsort hybrid** | Polars (Explorer) | O(n log n) | O(n log n) | O(n log n) |
| **Radix sort** | DuckDB (Dux) | O(n log n) | O(n log n) | O(n log n) |
| **XLA JIT-compiled sort** | Nx (EXLA) | O(n log n) | O(n log n) | O(n log n) |

All algorithms are O(n log n) in the average/worst case. The key difference
is **constant factors**: cache behavior, branch prediction, and whether the
comparator is inlined (`std::sort`) or called via a function pointer (`qsort`).
pdqsort stands out by detecting presorted runs in O(n), giving it a
significant edge on partially sorted inputs.

---

## Prerequisites

- Elixir 1.19.4
- Erlang/OTP 28.4
- Rust 1.94.0 (for the NIF, Port binary, and standalone benchmark)
- A C++ compiler with C++23 support + Erlang dev headers (for the C Node)
- Google Benchmark for the standalone C++ benchmark

## Setup

```bash
# Install Google Benchmark (macOS)
brew install google-benchmark

# Install Elixir deps
mix deps.get

# Build the C Node
make -C c_node

# Build the Port sort binary
cd port_sort && cargo build --release && cd ..

# Compile everything (also builds the Rust NIF via Rustler)
mix compile

# (Optional) Build standalone native benchmarks
make -C c_bench
cd rust_bench && cargo bench --no-run && cd ..
```

## Running the Benchmarks

### Elixir (Benchee) — all approaches compared

```bash
# Without C Node (simplest — skips C Node benchmarks)
mix run bench/run.exs

# With C Node (requires BEAM distribution)
elixir --sname bench --cookie sorting_bench -S mix run bench/run.exs
```

### Standalone Rust (Criterion)

```bash
cd rust_bench && cargo bench
```

Measures pure Rust `sort_unstable` with no BEAM involvement:
generate+sort, sort-only, pre-sorted, and reverse-sorted inputs.
Results with HTML reports are saved to `rust_bench/target/criterion/`.

### Standalone C++ (Google Benchmark)

```bash
./c_bench/bench_sort
```

Measures pure C++ `std::sort` with no BEAM involvement.
Same scenarios as the Rust benchmark for direct comparison.

### Unsafe Binary Mutation Demo

```bash
mix run bench/unsafe_demo.exs
```

Demonstrates **why the zero-copy in-place NIF sort (approach 04) is dangerous**.
The BEAM assumes binaries are immutable, but the NIF mutates the underlying
memory. This script shows four scenarios where that breaks:

1. **Shared reference** — two variables point to the same refc binary; sorting
   via one silently mutates the other
2. **Sub-binary corruption** — a sub-binary (`<<chunk::binary-size(24), _::binary>> = big`)
   points into the parent binary's memory; sorting the parent corrupts the sub-binary
3. **Cross-process mutation** — another process holds a reference to the binary;
   the parent sorts it in-place and the child's "copy" changes silently
4. **The safe alternative** — `:binary.copy/1` creates a separate refc binary
   that isolates the mutation

This is not included in the timed benchmarks — it is a safety test showing
why `:binary.copy/1` is essential before any in-place mutation.

### Safe Binary Mutation Demo

```bash
mix run bench/safe_demo.exs
```

The counterpart to the unsafe demo. Runs the **exact same three scenarios**
(shared reference, sub-binary, cross-process) but applies `:binary.copy/1`
before passing the binary to the NIF. Every scenario that was broken in
the unsafe demo now works correctly.

After the demos, it runs a **Benchee benchmark** comparing:

- **UNSAFE** — `sort_binary_inplace` without a safety copy
- **SAFE** — `:binary.copy/1` + `sort_binary_inplace`
- **sort_binary** — the NIF that copies internally (the recommended approach)

This shows that the "safety tax" is just a single 8 MB memcpy, and that
`:binary.copy + sort_binary_inplace` performs identically to `sort_binary`.
There is no reason to use the unsafe approach in production.
