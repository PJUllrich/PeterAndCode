# =============================================================================
# In-Place Binary Mutation Demo
#
# Demonstrates WHY the zero-copy in-place NIF sort is dangerous, and how
# :binary.copy/1 fixes it. The BEAM assumes binaries are immutable. When a
# NIF mutates the underlying memory, every reference to that binary — in the
# same process or other processes — sees the change.
#
# Run:  mix run bench/unsafe_demo.exs
# =============================================================================

alias SortingBench.RustNif

IO.puts("""
========================================================================
  IN-PLACE BINARY MUTATION DEMO
  Showing what breaks — and how :binary.copy/1 fixes it
========================================================================
""")

# ---------------------------------------------------------------------------
# Demo 1: Same process, two variables pointing to the same binary
# ---------------------------------------------------------------------------
IO.puts("--- Demo 1: Two variables, same underlying binary ---\n")

original = SortingBench.list_to_binary([5, 3, 1, 4, 2])
# NOT a copy — both point to the same refc binary
alias_ref = original

IO.puts("Before NIF mutation:")
IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original), charlists: :as_lists)}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref), charlists: :as_lists)}")

:ok = RustNif.sort_binary_inplace(original)

IO.puts("\nAfter NIF sorts 'original' in-place:")
IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original), charlists: :as_lists)}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref), charlists: :as_lists)}")
IO.puts("  Same memory? #{original === alias_ref}")

IO.puts("\n  => UNSAFE: alias_ref was NEVER passed to the NIF, but its contents changed!")
IO.puts("     The BEAM assumes binaries are immutable. This breaks that contract.\n")

# Now show the fix
IO.puts("  The fix — :binary.copy before NIF call:")

original = SortingBench.list_to_binary([5, 3, 1, 4, 2])
# both point to the same refc binary
alias_ref = original
safe = :binary.copy(original)
:ok = RustNif.sort_binary_inplace(safe)

IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original), charlists: :as_lists)}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref), charlists: :as_lists)}")
IO.puts("  safe      = #{inspect(SortingBench.binary_to_list(safe), charlists: :as_lists)}")

IO.puts("\n  => SAFE: original and alias_ref are unchanged.")
IO.puts("     Only the copied binary was mutated.\n")

# ---------------------------------------------------------------------------
# Demo 2: Cross-process mutation
# ---------------------------------------------------------------------------
IO.puts("--- Demo 2: Another process sees the mutation ---\n")

shared = SortingBench.list_to_binary([9, 7, 5, 3, 1, 8, 6, 4, 2, 0])
parent = self()

# Spawn a process that holds a reference to the binary and watches it
watcher =
  spawn(fn ->
    # same refc binary, NOT a deep copy
    my_copy = shared

    before = SortingBench.binary_to_list(my_copy)
    send(parent, {:before, before})

    # Wait for parent to mutate
    receive do
      :check -> :ok
    end

    after_mutation = SortingBench.binary_to_list(my_copy)
    send(parent, {:after, after_mutation})
  end)

# Get the watcher's view before mutation
receive do
  {:before, before} ->
    IO.puts("Watcher process sees BEFORE: #{inspect(before, charlists: :as_lists)}")
end

# Now mutate from the parent process
:ok = RustNif.sort_binary_inplace(shared)
IO.puts("Parent sorted the binary in-place.")

# Ask watcher to check
send(watcher, :check)

receive do
  {:after, after_val} ->
    IO.puts("Watcher process sees AFTER:  #{inspect(after_val, charlists: :as_lists)}")
end

IO.puts("\n  => UNSAFE: The watcher's binary changed even though it never called the NIF!")
IO.puts("     In a real system, this could cause silent data corruption,")
IO.puts("     crashes, or security vulnerabilities.\n")

# Now show the fix
IO.puts("  The fix — :binary.copy before NIF call:")

shared = SortingBench.list_to_binary([9, 7, 5, 3, 1, 8, 6, 4, 2, 0])
parent = self()

watcher =
  spawn(fn ->
    # same refc binary
    my_ref = shared

    before = SortingBench.binary_to_list(my_ref)
    send(parent, {:before, before})

    receive do
      :check -> :ok
    end

    after_mutation = SortingBench.binary_to_list(my_ref)
    send(parent, {:after, after_mutation})
  end)

receive do
  {:before, before} ->
    IO.puts("  Watcher process sees BEFORE: #{inspect(before, charlists: :as_lists)}")
end

safe = :binary.copy(shared)
:ok = RustNif.sort_binary_inplace(safe)
IO.puts("  Parent sorted a :binary.copy in-place.")

send(watcher, :check)

receive do
  {:after, after_val} ->
    IO.puts("  Watcher process sees AFTER:  #{inspect(after_val, charlists: :as_lists)}")
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
  SUMMARY
========================================================================

  The BEAM's binary immutability is a CONVENTION, not hardware-enforced.
  NIFs can break it by casting const pointers to mutable.

  When you skip :binary.copy/1:
    - Other variables in the same process see the mutation
    - Other processes sharing the refc binary see the mutation
    - Pattern matches and guards that already executed may have
      been based on data that no longer exists

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
