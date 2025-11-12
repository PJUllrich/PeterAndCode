import Bitwise

# Reconstruct the header with checksum field zeroed
header_with_zero_checksum = <<69, 0, 12, 0, 0, 0, 0, 0, 119, 1, 0, 0, 142, 251, 36, 46, 192, 168, 0, 92>>

defmodule Checksum do
  import Bitwise
  
  def checksum(data), do: checksum(data, 0)
  
  defp checksum(<<val::16, rest::bytes>>, sum), do: checksum(rest, sum + val)
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)
  
  defp checksum(<<>>, sum) do
    sum = (sum &&& 0xFFFF) + (sum >>> 16)
    sum = (sum &&& 0xFFFF) + (sum >>> 16)
    <<bnot(sum) &&& 0xFFFF::16>>
  end
end

correct_checksum = Checksum.checksum(header_with_zero_checksum)
<<high, low>> = correct_checksum

IO.puts("Correct checksum should be: #{inspect(correct_checksum)}")
IO.puts("Hex: 0x#{Integer.to_string(high, 16)}#{String.pad_leading(Integer.to_string(low, 16), 2, "0")}")
IO.puts("But packet has: 0xCFAF")
IO.puts("\nThis suggests the packet's checksum is incorrect!")
