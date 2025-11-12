import Bitwise

# The actual header from your debug output
header = <<69, 0, 12, 0, 0, 0, 0, 0, 119, 1, 207, 175, 142, 251, 36, 46, 192, 168, 0, 92>>

# Current checksum implementation
defmodule ChecksumTest do
  import Bitwise
  
  def checksum(data), do: checksum(data, 0)
  
  defp checksum(<<val::16, rest::bytes>>, sum) do
    IO.puts("Adding 0x#{Integer.to_string(val, 16)} (sum now: 0x#{Integer.to_string(sum + val, 16)})")
    checksum(rest, sum + val)
  end
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)
  
  defp checksum(<<>>, sum) do
    IO.puts("Final sum: 0x#{Integer.to_string(sum, 16)}")
    <<left::16, right::16>> = <<sum::32>>
    IO.puts("Left (high 16): 0x#{Integer.to_string(left, 16)}")
    IO.puts("Right (low 16): 0x#{Integer.to_string(right, 16)}")
    IO.puts("Left + Right: 0x#{Integer.to_string(left + right, 16)}")
    result = bnot(left + right) &&& 0xFFFF
    IO.puts("NOT(Left + Right): 0x#{Integer.to_string(result, 16)}")
    <<result::16>>
  end
end

IO.puts("Verifying checksum calculation:")
IO.puts("================================")
result = ChecksumTest.checksum(header)
IO.puts("Result: #{inspect(result)}")

# Let's also manually verify: the checksum should make the sum of all words equal to 0xFFFF
IO.puts("\n=== Manual verification ===")
words = for <<word::16 <- header>>, do: word
IO.puts("Words: #{inspect(Enum.map(words, fn w -> "0x#{Integer.to_string(w, 16)}" end))}")
sum = Enum.sum(words)
IO.puts("Sum of all words: 0x#{Integer.to_string(sum, 16)}")
folded = (sum &&& 0xFFFF) + (sum >>> 16)
IO.puts("After folding carries: 0x#{Integer.to_string(folded, 16)}")
folded = (folded &&& 0xFFFF) + (folded >>> 16)
IO.puts("After second fold: 0x#{Integer.to_string(folded, 16)}")
IO.puts("Should be 0xFFFF for valid checksum")
