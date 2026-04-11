# =============================================================================
# Sorting Benchmark — 1 million elements
#
# Measures copy cost + sorting speed across different approaches.
#
# Run all (without C Node):
#   mix run bench/run.exs
#
# Run all (with C Node — requires distribution):
#   elixir --sname bench --cookie sorting_bench -S mix run bench/run.exs
#
# Run specific scenarios (substring match, case-insensitive):
#   mix run bench/run.exs -- port
#   mix run bench/run.exs -- "rust nif" mmap
#   elixir --sname bench --cookie sorting_bench -S mix run bench/run.exs -- "c node"
# =============================================================================

alias SortingBench.RustNif

size = 1_000_000
IO.puts("Generating #{size} random integers...")
list = SortingBench.generate_data(size)
binary = SortingBench.list_to_binary(list)
IO.puts("Data ready: list of #{length(list)} elements, binary of #{byte_size(binary)} bytes\n")

# Cheap per-iteration randomization: shuffle the first 1000 elements.
# This prevents adaptive algorithms from benefiting across iterations
# without the cost of generating a full 1M-element list each time.
shuffle_head = fn list ->
  {head, tail} = Enum.split(list, 1000)
  Enum.shuffle(head) ++ tail
end

fresh_list = fn _ -> shuffle_head.(list) end
fresh_binary = fn _ -> list |> shuffle_head.() |> SortingBench.list_to_binary() end

# -- Setup mmap resource (reused across iterations) ---------------------------
IO.puts("Setting up mmap shared memory region...")
mmap = RustNif.mmap_create(size)
IO.puts("mmap ready\n")

# -- Check optional library availability --------------------------------------
nx_available? = Code.ensure_loaded?(Nx)
exla_available? = Code.ensure_loaded?(EXLA.Backend)
explorer_available? = Code.ensure_loaded?(Explorer.Series)
dux_available? = Code.ensure_loaded?(Dux)
f_enum_available? = Code.ensure_loaded?(FEnum)

unless nx_available?, do: IO.puts("Nx not available — skipping Nx benchmarks.")
unless exla_available?, do: IO.puts("EXLA not available — skipping EXLA benchmark.")
unless explorer_available?, do: IO.puts("Explorer not available — skipping Explorer benchmark.")
unless dux_available?, do: IO.puts("Dux not available — skipping Dux benchmark.")
unless f_enum_available?, do: IO.puts("FEnum not available — skipping FEnum benchmark.")

# -- Setup C Node (optional — requires distribution) --------------------------
c_node_info =
  if Node.alive?() do
    IO.puts("BEAM is distributed (#{node()}), starting C Node...")

    try do
      {port, name} = SortingBench.CNodeSort.start()
      IO.puts("C Node connected: #{name}\n")
      {port, name}
    rescue
      e ->
        IO.puts("C Node setup failed: #{Exception.message(e)}")
        IO.puts("Skipping C Node benchmark.\n")
        nil
    end
  else
    IO.puts("""
    BEAM is not distributed — skipping C Node benchmark.
    To include it: elixir --sname bench --cookie sorting_bench -S mix run bench/run.exs
    """)

    nil
  end

# -- Setup Port sort (optional — requires built binary) -----------------------
port_sort_info =
  try do
    port = SortingBench.PortSort.start()
    IO.puts("Port sort process started.\n")
    port
  rescue
    e ->
      IO.puts("Port sort setup failed: #{Exception.message(e)}")
      IO.puts("Skipping Port sort benchmark.\n")
      nil
  end

# -- Build benchmark scenarios ------------------------------------------------

# ─── GROUP A: From list (full round-trip, list in → sorted list out) ─────────
scenarios = %{
  # Pure BEAM baselines
  "A01a. Enum.sort (Elixir — fun call per comparison)" =>
    {fn input -> Enum.sort(input) end, before_each: fresh_list},
  "A01b. :lists.sort (Erlang — native term comparison)" =>
    {fn input -> :lists.sort(input) end, before_each: fresh_list},

  # Rust NIF — list protocol (Rustler decodes/encodes list in Rust)
  "A02. Rust NIF (list protocol — full copy)" =>
    {fn input -> RustNif.sort_list(input) end, before_each: fresh_list},

  # Rust NIF — Elixir-side binary conversion round-trip
  "A03. Rust NIF binary round-trip (list→binary→sort→list)" =>
    {fn input ->
       bin = SortingBench.list_to_binary(input)
       sorted_bin = RustNif.sort_binary(bin)
       SortingBench.binary_to_list(sorted_bin)
     end, before_each: fresh_list},

  # Rust NIF — mmap round-trip
  "A04. Rust NIF mmap round-trip (list→binary→mmap→sort→mmap→list)" =>
    {fn input ->
       bin = SortingBench.list_to_binary(input)
       RustNif.mmap_write(mmap, bin)
       RustNif.mmap_sort(mmap)
       sorted_bin = RustNif.mmap_read(mmap)
       SortingBench.binary_to_list(sorted_bin)
     end, before_each: fresh_list},

  # ETS ordered_set (AVL tree)
  "A05. ETS ordered_set (AVL tree insert + tab2list)" =>
    {fn input -> SortingBench.EtsSort.sort(input) end, before_each: fresh_list},

  # Atomics (quicksort in Elixir on off-heap array)
  "A06. Atomics (quicksort on off-heap i64 array)" =>
    {fn input -> SortingBench.AtomicsSort.sort(input) end, before_each: fresh_list},

  # Overhead baseline — list↔binary conversion without sorting
  "A00. List↔binary conversion (no sort — measures overhead)" =>
    {fn input ->
       bin = SortingBench.list_to_binary(input)
       SortingBench.binary_to_list(bin)
     end, before_each: fresh_list},

  # ─── GROUP B: From binary (binary in → sorted binary out) ──────────────────

  # Rust NIF — binary ref, safe copy
  "B01. Rust NIF (binary ref — safe copy)" =>
    {fn input -> RustNif.sort_binary(input) end, before_each: fresh_binary},

  # Rust NIF — binary ref, in-place (UNSAFE)
  "B02. Rust NIF (binary ref — in-place UNSAFE)" =>
    {fn input -> RustNif.sort_binary_inplace(input) end, before_each: fresh_binary},

  # Rust NIF — mmap full cycle (write + sort + read)
  "B03. Rust NIF mmap (full: write+sort+read)" =>
    {fn input ->
       RustNif.mmap_write(mmap, input)
       RustNif.mmap_sort(mmap)
       RustNif.mmap_read(mmap)
     end, before_each: fresh_binary},

  # Rust NIF — mmap sort-only (data pre-loaded)
  "B04. Rust NIF mmap (sort-only, data pre-loaded)" =>
    {fn _input -> RustNif.mmap_sort(mmap) end,
     before_each: fn _ ->
       RustNif.mmap_write(mmap, shuffle_head.(list) |> SortingBench.list_to_binary())
       :ok
     end},

  # ─── GROUP R: Reference (no BEAM data, measures pure native speed) ─────────

  "R01. Rust NIF (generate+sort in Rust — reference)" =>
    {fn _input -> RustNif.generate_and_sort(size) end, before_each: fn _ -> :ok end},

  "R02. Rust NIF (Elixir-instructed sort — measures NIF call overhead)" =>
    {fn input -> RustNif.trigger_sort(input) end,
     before_each: fn _ -> RustNif.prepare_sort(size) end}
}

# Conditionally add Nx (BinaryBackend) — Group A
scenarios =
  if nx_available? do
    Map.put(scenarios, "A07. Nx (BinaryBackend)", {
      fn input -> SortingBench.NxSort.sort_binary_backend(input) end,
      before_each: fresh_list
    })
  else
    scenarios
  end

# Conditionally add EXLA — Group A
scenarios =
  if exla_available? do
    Map.put(scenarios, "A08. Nx (EXLA)", {
      fn input -> SortingBench.NxSort.sort_exla_backend(input) end,
      before_each: fresh_list
    })
  else
    scenarios
  end

# Conditionally add Explorer — Group A
scenarios =
  if explorer_available? do
    Map.put(scenarios, "A09. Explorer (Polars)", {
      fn input -> SortingBench.ExplorerSort.sort(input) end,
      before_each: fresh_list
    })
  else
    scenarios
  end

# Conditionally add Dux — Group A
scenarios =
  if dux_available? do
    Map.put(scenarios, "A10. Dux (DuckDB)", {
      fn input -> SortingBench.DuxSort.sort(input) end,
      before_each: fresh_list
    })
  else
    scenarios
  end

# Conditionally add FEnum — Group A
scenarios =
  if f_enum_available? do
    Map.put(scenarios, "A11. FEnum (NIF round-trip: list→Rust→sort→list)", {
      fn input -> FEnum.sort(input) end,
      before_each: fresh_list
    })
  else
    scenarios
  end

# Conditionally add Port sort — Group A (list round-trip) + Group B (binary)
scenarios =
  if port_sort_info do
    port = port_sort_info

    scenarios
    |> Map.put("A12. Port round-trip (list→binary→pipe→sort→pipe→list)", {
      fn input ->
        bin = SortingBench.list_to_binary(input)
        sorted_bin = SortingBench.PortSort.sort(port, bin)
        SortingBench.binary_to_list(sorted_bin)
      end, before_each: fresh_list
    })
    |> Map.put("B05. Port stdin/stdout (Rust via pipe)", {
      fn input -> SortingBench.PortSort.sort(port, input) end,
      before_each: fresh_binary
    })
  else
    scenarios
  end

# Conditionally add C Node — Group A (list round-trip) + Group B (binary) + Group R (reference)
scenarios =
  case c_node_info do
    {_port, c_node_name} ->
      scenarios
      |> Map.put("A13. C Node round-trip (list→binary→dist→sort→dist→list)", {
        fn input ->
          bin = SortingBench.list_to_binary(input)
          sorted_bin = SortingBench.CNodeSort.sort(c_node_name, bin)
          SortingBench.binary_to_list(sorted_bin)
        end, before_each: fresh_list
      })
      |> Map.put("B06. C Node (distributed Erlang)", {
        fn input -> SortingBench.CNodeSort.sort(c_node_name, input) end,
        before_each: fresh_binary
      })
      |> Map.put("R03. C Node (generate+sort in C — reference)", {
        fn _input -> SortingBench.CNodeSort.generate_and_sort(c_node_name, size) end,
        before_each: fn _ -> :ok end
      })
      |> Map.put("R04. C Node (Elixir-instructed sort — measures dist overhead)", {
        fn _input -> SortingBench.CNodeSort.trigger_sort(c_node_name) end,
        before_each: fn _ ->
          SortingBench.CNodeSort.prepare_sort(c_node_name, size)
          :ok
        end
      })

    nil ->
      scenarios
  end

# -- Verify every approach produces correct output (outside timing) -----------
alias SortingBench.Verify

expected_sum = Enum.sum(list)
IO.puts("\nVerifying all approaches (expected sum: #{expected_sum})...")

# ─── Group A: from list ───
Verify.verify_list!("Enum.sort", Enum.sort(list), expected_sum)
Verify.verify_list!(":lists.sort", :lists.sort(list), expected_sum)
Verify.verify_list!("Rust NIF list protocol", RustNif.sort_list(list), expected_sum)

roundtrip_bin = list |> SortingBench.list_to_binary() |> RustNif.sort_binary() |> SortingBench.binary_to_list()
Verify.verify_list!("Rust NIF binary round-trip", roundtrip_bin, expected_sum)

mmap_rt_bin = SortingBench.list_to_binary(list)
RustNif.mmap_write(mmap, mmap_rt_bin)
RustNif.mmap_sort(mmap)
mmap_rt_result = RustNif.mmap_read(mmap) |> SortingBench.binary_to_list()
Verify.verify_list!("Rust NIF mmap round-trip", mmap_rt_result, expected_sum)

Verify.verify_list!("ETS ordered_set", SortingBench.EtsSort.sort(list), expected_sum)
Verify.verify_list!("Atomics quicksort", SortingBench.AtomicsSort.sort(list), expected_sum)

# List↔binary conversion overhead (no sort — verify round-trip preserves data)
conversion_result = list |> SortingBench.list_to_binary() |> SortingBench.binary_to_list()
if conversion_result == list do
  Verify.pass!("List↔binary conversion")
else
  raise "VERIFY FAILED [List↔binary conversion]: round-trip changed data"
end

if nx_available? do
  Verify.verify_list!("Nx BinaryBackend", SortingBench.NxSort.sort_binary_backend(list), expected_sum)
end

if exla_available? do
  Verify.verify_list!("Nx EXLA", SortingBench.NxSort.sort_exla_backend(list), expected_sum)
end

if explorer_available? do
  Verify.verify_list!("Explorer Polars", SortingBench.ExplorerSort.sort(list), expected_sum)
end

if dux_available? do
  Verify.verify_list!("Dux DuckDB", SortingBench.DuxSort.sort(list), expected_sum)
end

if f_enum_available? do
  Verify.verify_list!("FEnum sort", FEnum.sort(list), expected_sum)
end

if port_sort_info do
  port_rt = SortingBench.list_to_binary(list)
    |> then(&SortingBench.PortSort.sort(port_sort_info, &1))
    |> SortingBench.binary_to_list()
  Verify.verify_list!("Port round-trip", port_rt, expected_sum)
end

case c_node_info do
  {_port, c_node_name} ->
    c_rt = SortingBench.list_to_binary(list)
      |> then(&SortingBench.CNodeSort.sort(c_node_name, &1))
      |> SortingBench.binary_to_list()
    Verify.verify_list!("C Node round-trip", c_rt, expected_sum)
  nil -> :ok
end

# ─── Group B: from binary ───
Verify.verify_binary!("Rust NIF binary safe", RustNif.sort_binary(binary), expected_sum)

inplace_copy = :binary.copy(binary)
:ok = RustNif.sort_binary_inplace(inplace_copy)
Verify.verify_binary!("Rust NIF binary in-place", inplace_copy, expected_sum)

RustNif.mmap_write(mmap, binary)
RustNif.mmap_sort(mmap)
Verify.verify_binary!("Rust NIF mmap full cycle", RustNif.mmap_read(mmap), expected_sum)

RustNif.mmap_write(mmap, binary)
RustNif.mmap_sort(mmap)
Verify.verify_binary!("Rust NIF mmap sort-only", RustNif.mmap_read(mmap), expected_sum)

if port_sort_info do
  Verify.verify_binary!("Port stdin/stdout", SortingBench.PortSort.sort(port_sort_info, binary), expected_sum)
end

case c_node_info do
  {_port, c_node_name} ->
    Verify.verify_binary!("C Node distributed", SortingBench.CNodeSort.sort(c_node_name, binary), expected_sum)
  nil -> :ok
end

# ─── Group R: reference (no BEAM data) ───
:ok = RustNif.generate_and_sort(size)
Verify.pass!("Rust NIF generate+sort")

ref = RustNif.prepare_sort(size)
:ok = RustNif.trigger_sort(ref)
Verify.pass!("Rust NIF trigger_sort")

case c_node_info do
  {_port, c_node_name} ->
    :ok = SortingBench.CNodeSort.generate_and_sort(c_node_name, size)
    Verify.pass!("C Node generate+sort")

    SortingBench.CNodeSort.prepare_sort(c_node_name, size)
    :ok = SortingBench.CNodeSort.trigger_sort(c_node_name)
    Verify.pass!("C Node trigger_sort")
  nil -> :ok
end

IO.puts("Verification complete!\n")

# -- Filter scenarios by CLI args (if any) ------------------------------------
filters = System.argv()

scenarios =
  if filters == [] do
    scenarios
  else
    filtered =
      Enum.filter(scenarios, fn {name, _} ->
        name_down = String.downcase(name)
        Enum.any?(filters, fn f -> String.contains?(name_down, String.downcase(f)) end)
      end)
      |> Map.new()

    if filtered == %{} do
      IO.puts("No scenarios matched filters: #{inspect(filters)}")
      IO.puts("Available scenarios:")
      scenarios |> Map.keys() |> Enum.sort() |> Enum.each(&IO.puts("  #{&1}"))
      System.halt(1)
    end

    IO.puts("Filtered to #{map_size(filtered)} scenario(s):")
    filtered |> Map.keys() |> Enum.sort() |> Enum.each(&IO.puts("  #{&1}"))
    IO.puts("")
    filtered
  end

# -- Run Benchee --------------------------------------------------------------
IO.puts("\n" <> String.duplicate("=", 70))
IO.puts("SORTING BENCHMARK — #{size} elements")
IO.puts(String.duplicate("=", 70) <> "\n")

Benchee.run(
  scenarios,
  warmup: 3,
  time: 10,
  memory_time: 2,
  reduction_time: 0,
  print: [configuration: true, benchmarking: true],
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML,
     file: "bench/output/results-#{System.system_time(:second)}.html", auto_open: false}
  ]
)

# -- Cleanup ------------------------------------------------------------------
if port_sort_info, do: SortingBench.PortSort.stop(port_sort_info)

case c_node_info do
  {port, c_node_name} ->
    IO.puts("\nShutting down C Node...")
    SortingBench.CNodeSort.stop(port, c_node_name)

  nil ->
    :ok
end

IO.puts("\nDone!")
