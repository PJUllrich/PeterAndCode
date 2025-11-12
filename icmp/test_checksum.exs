# Test the checksum function with a known example
# IPv4 header example from RFC 1071
data = <<
  0x45, 0x00, 0x00, 0x73,  # Version/IHL, ToS, Total Length
  0x00, 0x00, 0x40, 0x00,  # ID, Flags/Offset
  0x40, 0x11, 0x00, 0x00,  # TTL, Protocol, Checksum (zeroed)
  0xC0, 0xA8, 0x00, 0x01,  # Source IP
  0xC0, 0xA8, 0x00, 0xC7   # Dest IP
>>

# Current implementation
defmodule CurrentChecksum do
  import Bitwise
  
  def checksum(data), do: checksum(data, 0)
  
  defp checksum(<<val::16, rest::bytes>>, sum), do: checksum(rest, sum + val)
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)
  
  defp checksum(<<>>, sum) do
    <<left::16, right::16>> = <<sum::32>>
    <<bnot(left + right)::big-integer-size(16)>>
  end
end

# Fixed implementation with proper carry handling
defmodule FixedChecksum do
  import Bitwise
  
  def checksum(data), do: checksum(data, 0)
  
  defp checksum(<<val::16, rest::bytes>>, sum), do: checksum(rest, sum + val)
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)
  
  defp checksum(<<>>, sum) do
    # Fold carries from 32-bit sum to 16-bit
    sum = (sum &&& 0xFFFF) + (sum >>> 16)
    # Add carry again if needed (can happen at most once more)
    sum = (sum &&& 0xFFFF) + (sum >>> 16)
    # Take one's complement
    <<bnot(sum) &&& 0xFFFF::16>>
  end
end

IO.puts("Current checksum: #{inspect(CurrentChecksum.checksum(data))}")
IO.puts("Fixed checksum:   #{inspect(FixedChecksum.checksum(data))}")

# The correct checksum for this header should be 0xB861
IO.puts("Expected:         <<184, 97>> (0xB861)")
