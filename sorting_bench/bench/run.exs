# =============================================================================
# Sorting Benchmark — 1 million elements
#
# Measures copy cost + sorting speed across different approaches.
#
# Run (without C Node):
#   mix run bench/run.exs
#
# Run (with C Node — requires distribution):
#   elixir --sname bench --cookie sorting_bench -S mix run bench/run.exs
# =============================================================================

alias SortingBench.RustNif

size = 1_000_000
IO.puts("Generating #{size} random integers...")
list = SortingBench.generate_data(size)
binary = SortingBench.list_to_binary(list)
IO.puts("Data ready: list of #{length(list)} elements, binary of #{byte_size(binary)} bytes\n")

# -- Setup mmap resource (reused across iterations) ---------------------------
IO.puts("Setting up mmap shared memory region...")
mmap = RustNif.mmap_create(size)
IO.puts("mmap ready\n")

# -- Check optional library availability --------------------------------------
nx_available? = Code.ensure_loaded?(Nx)
exla_available? = Code.ensure_loaded?(EXLA.Backend)
explorer_available? = Code.ensure_loaded?(Explorer.Series)

unless nx_available?, do: IO.puts("Nx not available — skipping Nx benchmarks.")
unless exla_available?, do: IO.puts("EXLA not available — skipping EXLA benchmark.")
unless explorer_available?, do: IO.puts("Explorer not available — skipping Explorer benchmark.")

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

# -- Build benchmark scenarios ------------------------------------------------
scenarios = %{
  # === Baseline ===
  "01. Enum.sort (pure Elixir)" =>
    {fn _input -> Enum.sort(list) end,
     before_each: fn _ -> :ok end},

  # === Rust NIFs ===
  "02. Rust NIF (list protocol — full copy)" =>
    {fn _input -> RustNif.sort_list(list) end,
     before_each: fn _ -> :ok end},

  "03. Rust NIF (binary ref — safe copy)" =>
    {fn _input -> RustNif.sort_binary(binary) end,
     before_each: fn _ -> :ok end},

  "04. Rust NIF (binary ref — in-place UNSAFE)" =>
    {fn input -> RustNif.sort_binary_inplace(input) end,
     before_each: fn _ -> :binary.copy(binary) end},

  # === Shared memory ===
  "05. Rust NIF mmap (full: write+sort+read)" =>
    {fn _input ->
       RustNif.mmap_write(mmap, binary)
       RustNif.mmap_sort(mmap)
       RustNif.mmap_read(mmap)
     end,
     before_each: fn _ -> :ok end},

  "06. Rust NIF mmap (sort-only, data pre-loaded)" =>
    {fn _input -> RustNif.mmap_sort(mmap) end,
     before_each: fn _ ->
       RustNif.mmap_write(mmap, binary)
       :ok
     end}
}

# Conditionally add Nx (BinaryBackend)
scenarios =
  if nx_available? do
    Map.put(scenarios, "07. Nx (BinaryBackend)", {
      fn _input -> SortingBench.NxSort.sort_binary_backend(list) end,
      before_each: fn _ -> :ok end
    })
  else
    scenarios
  end

# Conditionally add EXLA
scenarios =
  if exla_available? do
    Map.put(scenarios, "08. Nx (EXLA)", {
      fn _input -> SortingBench.NxSort.sort_exla_backend(list) end,
      before_each: fn _ -> :ok end
    })
  else
    scenarios
  end

# Conditionally add Explorer
scenarios =
  if explorer_available? do
    Map.put(scenarios, "09. Explorer (Polars)", {
      fn _input -> SortingBench.ExplorerSort.sort(list) end,
      before_each: fn _ -> :ok end
    })
  else
    scenarios
  end

# Conditionally add C Node
scenarios =
  case c_node_info do
    {_port, c_node_name} ->
      Map.put(scenarios, "10. C Node (distributed Erlang)", {
        fn _input -> SortingBench.CNodeSort.sort(c_node_name, binary) end,
        before_each: fn _ -> :ok end
      })

    nil ->
      scenarios
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
  formatters: [Benchee.Formatters.Console]
)

# -- Cleanup ------------------------------------------------------------------
case c_node_info do
  {port, c_node_name} ->
    IO.puts("\nShutting down C Node...")
    SortingBench.CNodeSort.stop(port, c_node_name)

  nil ->
    :ok
end

IO.puts("\nDone!")
