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
scenarios = %{
  # === Baselines ===
  "01a. Enum.sort (Elixir — fun call per comparison)" =>
    {fn _input -> Enum.sort(list) end,
     before_each: fn _ -> :ok end},

  "01b. :lists.sort (Erlang — native term comparison, no fun overhead)" =>
    {fn _input -> :lists.sort(list) end,
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
     end},

  # === Reference: pure native (generate + sort, zero BEAM overhead) ===
  "00. Rust NIF (generate+sort in Rust — reference)" =>
    {fn _input -> RustNif.generate_and_sort(size) end,
     before_each: fn _ -> :ok end},

  # === Elixir-instructed: data lives in Rust, Elixir just says "go" ===
  "00. Rust NIF (Elixir-instructed sort — measures NIF call overhead)" =>
    {fn input -> RustNif.trigger_sort(input) end,
     before_each: fn _ -> RustNif.prepare_sort(size) end},

  # === ETS ordered_set (AVL tree) ===
  "11. ETS ordered_set (AVL tree insert + tab2list)" =>
    {fn _input -> SortingBench.EtsSort.sort(list) end,
     before_each: fn _ -> :ok end}
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

# Conditionally add Port sort
scenarios =
  if port_sort_info do
    port = port_sort_info

    Map.put(scenarios, "12. Port stdin/stdout (Rust via pipe)", {
      fn _input -> SortingBench.PortSort.sort(port, binary) end,
      before_each: fn _ -> :ok end
    })
  else
    scenarios
  end

# Conditionally add C Node
scenarios =
  case c_node_info do
    {_port, c_node_name} ->
      scenarios
      |> Map.put("10. C Node (distributed Erlang)", {
        fn _input -> SortingBench.CNodeSort.sort(c_node_name, binary) end,
        before_each: fn _ -> :ok end
      })
      |> Map.put("00. C Node (generate+sort in C — reference)", {
        fn _input -> SortingBench.CNodeSort.generate_and_sort(c_node_name, size) end,
        before_each: fn _ -> :ok end
      })
      |> Map.put("00. C Node (Elixir-instructed sort — measures dist overhead)", {
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

# Baselines (return lists)
Verify.verify_list!("Enum.sort", Enum.sort(list), expected_sum)
Verify.verify_list!(":lists.sort", :lists.sort(list), expected_sum)

# Rust NIF — list protocol (returns list)
Verify.verify_list!("Rust NIF list protocol", RustNif.sort_list(list), expected_sum)

# Rust NIF — binary safe copy (returns binary)
Verify.verify_binary!("Rust NIF binary safe", RustNif.sort_binary(binary), expected_sum)

# Rust NIF — binary in-place UNSAFE (returns :ok, mutates binary)
inplace_copy = :binary.copy(binary)
:ok = RustNif.sort_binary_inplace(inplace_copy)
Verify.verify_binary!("Rust NIF binary in-place", inplace_copy, expected_sum)

# Rust NIF — mmap full cycle (write + sort + read → returns binary)
RustNif.mmap_write(mmap, binary)
RustNif.mmap_sort(mmap)
Verify.verify_binary!("Rust NIF mmap full cycle", RustNif.mmap_read(mmap), expected_sum)

# Rust NIF — mmap sort-only (verify via mmap_read after sort)
RustNif.mmap_write(mmap, binary)
RustNif.mmap_sort(mmap)
Verify.verify_binary!("Rust NIF mmap sort-only", RustNif.mmap_read(mmap), expected_sum)

# ETS ordered_set (returns list)
Verify.verify_list!("ETS ordered_set", SortingBench.EtsSort.sort(list), expected_sum)

# Nx — BinaryBackend (returns list)
if nx_available? do
  Verify.verify_list!("Nx BinaryBackend", SortingBench.NxSort.sort_binary_backend(list), expected_sum)
end

# Nx — EXLA (returns list)
if exla_available? do
  Verify.verify_list!("Nx EXLA", SortingBench.NxSort.sort_exla_backend(list), expected_sum)
end

# Explorer (returns list)
if explorer_available? do
  Verify.verify_list!("Explorer Polars", SortingBench.ExplorerSort.sort(list), expected_sum)
end

# Port stdin/stdout (returns binary)
if port_sort_info do
  Verify.verify_binary!("Port stdin/stdout", SortingBench.PortSort.sort(port_sort_info, binary), expected_sum)
end

# C Node (returns binary)
case c_node_info do
  {_port, c_node_name} ->
    Verify.verify_binary!("C Node distributed", SortingBench.CNodeSort.sort(c_node_name, binary), expected_sum)
  nil -> :ok
end

# Reference runs (generate_and_sort, trigger_sort) return :ok — data stays
# on the native side and never comes back. Cannot verify from Elixir.
IO.puts("  [SKIP] Rust NIF generate+sort (data stays in Rust)")
IO.puts("  [SKIP] Rust NIF trigger_sort (data stays in Rust)")

case c_node_info do
  {_port, _} ->
    IO.puts("  [SKIP] C Node generate+sort (data stays in C)")
    IO.puts("  [SKIP] C Node trigger_sort (data stays in C)")
  nil -> :ok
end

IO.puts("Verification complete!\n")

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
if port_sort_info, do: SortingBench.PortSort.stop(port_sort_info)

case c_node_info do
  {port, c_node_name} ->
    IO.puts("\nShutting down C Node...")
    SortingBench.CNodeSort.stop(port, c_node_name)

  nil ->
    :ok
end

IO.puts("\nDone!")
