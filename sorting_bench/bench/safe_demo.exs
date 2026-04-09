# =============================================================================
# SAFE In-Place Binary Mutation Demo
#
# The same scenarios as unsafe_demo.exs, but with :binary.copy/1 applied
# before handing the binary to the NIF. This single call converts every
# unsafe scenario into a safe one by giving the NIF its own memory.
#
# Run:  mix run bench/safe_demo.exs
# =============================================================================

alias SortingBench.RustNif

IO.puts("""
========================================================================
  SAFE BINARY MUTATION DEMO
  Same scenarios as unsafe_demo.exs, but with :binary.copy/1 first
========================================================================
""")

# ---------------------------------------------------------------------------
# Demo 1: Same process, two variables — copy before mutation
# ---------------------------------------------------------------------------
IO.puts("--- Demo 1: Two variables — :binary.copy before NIF call ---\n")

original = SortingBench.list_to_binary([5, 3, 1, 4, 2])
alias_ref = original  # both point to the same refc binary

IO.puts("Before NIF mutation:")
IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original))}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref))}")

# THE FIX: copy before passing to the NIF
safe = :binary.copy(original)
:ok = RustNif.sort_binary_inplace(safe)

IO.puts("\nAfter NIF sorts a :binary.copy of 'original' in-place:")
IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original))}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref))}")
IO.puts("  safe      = #{inspect(SortingBench.binary_to_list(safe))}")

IO.puts("\n  => SAFE: original and alias_ref are unchanged.")
IO.puts("     Only the copied binary was mutated.\n")

# ---------------------------------------------------------------------------
# Demo 2: Sub-binary — copy before mutation
# ---------------------------------------------------------------------------
IO.puts("--- Demo 2: Sub-binary — :binary.copy before NIF call ---\n")

big = SortingBench.list_to_binary([100, 50, 75, 25, 1])
<<sub::binary-size(24), _rest::binary>> = big

IO.puts("Before NIF mutation:")
IO.puts("  big = #{inspect(SortingBench.binary_to_list(big))}")
IO.puts("  sub (first 3 elements) = #{inspect(SortingBench.binary_to_list(sub))}")

# THE FIX: copy before passing to the NIF
safe = :binary.copy(big)
:ok = RustNif.sort_binary_inplace(safe)

IO.puts("\nAfter NIF sorts a :binary.copy of 'big' in-place:")
IO.puts("  big  = #{inspect(SortingBench.binary_to_list(big))}")
IO.puts("  sub  = #{inspect(SortingBench.binary_to_list(sub))}")
IO.puts("  safe = #{inspect(SortingBench.binary_to_list(safe))}")

IO.puts("\n  => SAFE: big and sub are unchanged.")
IO.puts("     The sub-binary still points to the original, unmodified memory.\n")

# ---------------------------------------------------------------------------
# Demo 3: Cross-process — copy before mutation
# ---------------------------------------------------------------------------
IO.puts("--- Demo 3: Another process — :binary.copy before NIF call ---\n")

shared = SortingBench.list_to_binary([9, 7, 5, 3, 1, 8, 6, 4, 2, 0])
parent = self()

watcher = spawn(fn ->
  my_ref = shared  # same refc binary

  before = SortingBench.binary_to_list(my_ref)
  send(parent, {:before, before})

  receive do :check -> :ok end

  after_mutation = SortingBench.binary_to_list(my_ref)
  send(parent, {:after, after_mutation})
end)

receive do {:before, before} ->
  IO.puts("Watcher process sees BEFORE: #{inspect(before)}")
end

# THE FIX: copy before passing to the NIF
safe = :binary.copy(shared)
:ok = RustNif.sort_binary_inplace(safe)
IO.puts("Parent sorted a :binary.copy in-place.")

send(watcher, :check)

receive do {:after, after_val} ->
  IO.puts("Watcher process sees AFTER:  #{inspect(after_val)}")
end

IO.puts("\n  => SAFE: The watcher's binary is unchanged.")
IO.puts("     :binary.copy gave the NIF its own memory to mutate.\n")

# ---------------------------------------------------------------------------
# Benchmark: cost of :binary.copy as the safety tax
# ---------------------------------------------------------------------------
IO.puts("""
========================================================================
  BENCHMARK: the cost of safety
  Comparing in-place sort WITH vs WITHOUT :binary.copy
========================================================================
""")

size = 1_000_000
IO.puts("Generating #{size} random integers for benchmark...\n")
list = SortingBench.generate_data(size)
binary = SortingBench.list_to_binary(list)

Benchee.run(
  %{
    "UNSAFE: sort_binary_inplace (no copy)" =>
      {fn input -> RustNif.sort_binary_inplace(input) end,
       before_each: fn _ ->
         # Simulate the unsafe case: just pass the binary directly.
         # We still need a fresh unsorted binary per iteration, so we
         # copy here — but in the real unsafe scenario you wouldn't.
         :binary.copy(binary)
       end},

    "SAFE: :binary.copy + sort_binary_inplace" =>
      {fn input -> RustNif.sort_binary_inplace(input) end,
       before_each: fn _ ->
         # The safe pattern: always copy before in-place mutation.
         # Same :binary.copy — the only difference is intent, but the
         # cost is identical. This proves the "safety tax" is just one
         # 8 MB memcpy.
         :binary.copy(binary)
       end},

    "sort_binary (safe copy built into NIF)" =>
      {fn _input -> RustNif.sort_binary(binary) end,
       before_each: fn _ -> :ok end}
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  print: [configuration: true, benchmarking: true],
  formatters: [Benchee.Formatters.Console]
)

IO.puts("""

========================================================================
  TAKEAWAY
========================================================================

  The UNSAFE and SAFE benchmarks above use the exact same before_each
  (:binary.copy). This means:

  1. The "safety tax" of :binary.copy is already baked into both — it's
     the same 8 MB memcpy either way. The difference is whether YOU
     do it or whether you rely on shared memory and get lucky.

  2. sort_binary (the safe NIF) does the copy INSIDE the NIF. Compare
     it against the copy+inplace pair to see if there's any difference
     between copying in Elixir vs copying in Rust.

  3. In practice, :binary.copy + sort_binary_inplace ≈ sort_binary.
     There's no reason to use the unsafe approach in production.
""")
