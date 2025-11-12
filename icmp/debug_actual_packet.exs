import Bitwise

# The actual packet from your latest output
header = <<69, 0, 12, 0, 0, 0, 0, 0, 119, 1, 190, 49, 172, 217, 23, 206, 192, 168, 0, 92>>

defmodule Checksum do
  import Bitwise
  
  def checksum(data), do: checksum(data, 0)
  
  defp checksum(<<val::16, rest::bytes>>, sum) do
    IO.puts("  Adding: 0x#{String.pad_leading(Integer.to_string(val, 16), 4, "0")} -> sum = 0x#{Integer.to_string(sum + val, 16)}")
    checksum(rest, sum + val)
  end
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)
  
  defp checksum(<<>>, sum) do
    IO.puts("  Final sum before folding: 0x#{Integer.to_string(sum, 16)}")
    <<left::16, right::16>> = <<sum::32>>
    IO.puts("  High 16 bits: 0x#{String.pad_leading(Integer.to_string(left, 16), 4, "0")}")
    IO.puts("  Low 16 bits:  0x#{String.pad_leading(Integer.to_string(right, 16), 4, "0")}")
    result = left + right
    IO.puts("  Sum: 0x#{Integer.to_string(result, 16)}")
    complemented = bnot(result) &&& 0xFFFF
    IO.puts("  Complemented: 0x#{String.pad_leading(Integer.to_string(complemented, 16), 4, "0")}")
    <<complemented::16>>
  end
end

IO.puts("Analyzing packet header:")
IO.puts("Header: #{inspect(header, limit: :infinity)}")
IO.puts("\nStep-by-step calculation:")
result = Checksum.checksum(header)
IO.puts("\nFinal result: #{inspect(result)}")
IO.puts("Should be: <<0, 0>>")

# Now let's verify what the CORRECT checksum should be
IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Calculating what the checksum SHOULD be:")
<<before::bytes-size(10), _old_checksum::16, after_part::bytes-size(8)>> = header
header_zeroed = <<before::bytes-size(10), 0::16, after_part::bytes-size(8)>>
IO.puts("Header with checksum zeroed: #{inspect(header_zeroed, limit: :infinity)}")

correct_checksum = Checksum.checksum(header_zeroed)
<<high, low>> = correct_checksum
IO.puts("\nCorrect checksum: #{inspect(correct_checksum)} (0x#{String.pad_leading(Integer.to_string(high, 16), 2, "0")}#{String.pad_leading(Integer.to_string(low, 16), 2, "0")})")
IO.puts("Packet has:       0xBE31")

# Double check by parsing the hex manually
IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Manual word-by-word breakdown:")
for i <- 0..9 do
  <<_skip::bytes-size(i*2), word::16, _rest::bytes>> = header
  IO.puts("  Word #{i}: 0x#{String.pad_leading(Integer.to_string(word, 16), 4, "0")}")
end
