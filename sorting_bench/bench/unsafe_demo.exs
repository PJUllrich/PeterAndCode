# =============================================================================
# UNSAFE In-Place Binary Mutation Demo
#
# Demonstrates WHY the zero-copy in-place NIF sort is dangerous.
# The BEAM assumes binaries are immutable. When a NIF mutates the
# underlying memory, every reference to that binary — in the same
# process, other processes, sub-binaries — sees the change.
#
# Run:  mix run bench/unsafe_demo.exs
# =============================================================================

alias SortingBench.RustNif

IO.puts("""
========================================================================
  UNSAFE BINARY MUTATION DEMO
  Showing what happens when a NIF mutates a "shared" refc binary
========================================================================
""")

# ---------------------------------------------------------------------------
# Demo 1: Same process, two variables pointing to the same binary
# ---------------------------------------------------------------------------
IO.puts("--- Demo 1: Two variables, same underlying binary ---\n")

original = SortingBench.list_to_binary([5, 3, 1, 4, 2])
alias_ref = original  # NOT a copy — both point to the same refc binary

IO.puts("Before NIF mutation:")
IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original))}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref))}")

:ok = RustNif.sort_binary_inplace(original)

IO.puts("\nAfter NIF sorts 'original' in-place:")
IO.puts("  original  = #{inspect(SortingBench.binary_to_list(original))}")
IO.puts("  alias_ref = #{inspect(SortingBench.binary_to_list(alias_ref))}")
IO.puts("  Same memory? #{original === alias_ref}")

IO.puts("\n  => alias_ref was NEVER passed to the NIF, but its contents changed!")
IO.puts("     The BEAM assumes binaries are immutable. This breaks that contract.\n")

# ---------------------------------------------------------------------------
# Demo 2: Sub-binary corruption
# ---------------------------------------------------------------------------
IO.puts("--- Demo 2: Sub-binary sees mutation ---\n")

big = SortingBench.list_to_binary([100, 50, 75, 25, 1])

# Take a sub-binary (first 3 elements = 24 bytes). The BEAM optimizes this
# as a pointer into the original binary, NOT a copy.
<<sub::binary-size(24), _rest::binary>> = big

IO.puts("Before NIF mutation:")
IO.puts("  big = #{inspect(SortingBench.binary_to_list(big))}")
IO.puts("  sub (first 3 elements) = #{inspect(SortingBench.binary_to_list(sub))}")

:ok = RustNif.sort_binary_inplace(big)

IO.puts("\nAfter NIF sorts 'big' in-place:")
IO.puts("  big = #{inspect(SortingBench.binary_to_list(big))}")
IO.puts("  sub (first 3 elements) = #{inspect(SortingBench.binary_to_list(sub))}")

IO.puts("\n  => The sub-binary now contains DIFFERENT values than before!")
IO.puts("     It points into the same memory that was sorted.\n")

# ---------------------------------------------------------------------------
# Demo 3: Cross-process mutation
# ---------------------------------------------------------------------------
IO.puts("--- Demo 3: Another process sees the mutation ---\n")

shared = SortingBench.list_to_binary([9, 7, 5, 3, 1, 8, 6, 4, 2, 0])
parent = self()

# Spawn a process that holds a reference to the binary and watches it
watcher = spawn(fn ->
  my_copy = shared  # same refc binary, NOT a deep copy

  before = SortingBench.binary_to_list(my_copy)
  send(parent, {:before, before})

  # Wait for parent to mutate
  receive do :check -> :ok end

  after_mutation = SortingBench.binary_to_list(my_copy)
  send(parent, {:after, after_mutation})
end)

# Get the watcher's view before mutation
receive do {:before, before} ->
  IO.puts("Watcher process sees BEFORE: #{inspect(before)}")
end

# Now mutate from the parent process
:ok = RustNif.sort_binary_inplace(shared)
IO.puts("Parent sorted the binary in-place.")

# Ask watcher to check
send(watcher, :check)

receive do {:after, after_val} ->
  IO.puts("Watcher process sees AFTER:  #{inspect(after_val)}")
end

IO.puts("\n  => The watcher's binary changed even though it never called the NIF!")
IO.puts("     In a real system, this could cause silent data corruption,")
IO.puts("     crashes, or security vulnerabilities.\n")

# ---------------------------------------------------------------------------
# Demo 4: The safe alternative — :binary.copy/1
# ---------------------------------------------------------------------------
IO.puts("--- Demo 4: The safe alternative — :binary.copy/1 ---\n")

original2 = SortingBench.list_to_binary([5, 3, 1, 4, 2])
safe_copy = :binary.copy(original2)  # Deep copy — new refc binary

IO.puts("Before NIF mutation:")
IO.puts("  original2 = #{inspect(SortingBench.binary_to_list(original2))}")
IO.puts("  safe_copy = #{inspect(SortingBench.binary_to_list(safe_copy))}")

:ok = RustNif.sort_binary_inplace(safe_copy)

IO.puts("\nAfter NIF sorts 'safe_copy' in-place:")
IO.puts("  original2 = #{inspect(SortingBench.binary_to_list(original2))}")
IO.puts("  safe_copy = #{inspect(SortingBench.binary_to_list(safe_copy))}")

IO.puts("\n  => original2 is UNCHANGED because :binary.copy/1 created")
IO.puts("     a separate refc binary with its own memory.\n")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
IO.puts("""
========================================================================
  SUMMARY
========================================================================

  The BEAM's binary immutability is a CONVENTION, not hardware-enforced.
  NIFs can break it by casting const pointers to mutable.

  When you skip :binary.copy/1:
    - Other variables in the same process see the mutation
    - Sub-binaries see corrupted data
    - Other processes sharing the refc binary see the mutation
    - Pattern matches and guards that already executed may have
      been based on data that no longer exists

  The benchmark uses :binary.copy/1 in before_each to ensure each
  iteration gets a sole-reference binary that's safe to mutate.
  In production, you should NEVER use in-place mutation unless you
  can guarantee exclusive ownership.
""")
