import Bitwise

# Wikipedia example - IPv4 header (20 bytes)
# Header checksum is 0xb861 at bytes 10-11
header = <<
  0x45, 0x00, 0x00, 0x73,  # Version/IHL, ToS, Total Length
  0x00, 0x00, 0x40, 0x00,  # Identification, Flags/Offset
  0x40, 0x11, 0xb8, 0x61,  # TTL, Protocol, Checksum (0xb861)
  0xc0, 0xa8, 0x00, 0x01,  # Source IP
  0xc0, 0xa8, 0x00, 0xc7   # Dest IP
>>

defmodule Checksum do
  import Bitwise
  
  def checksum(data), do: checksum(data, 0)
  
  defp checksum(<<val::16, rest::bytes>>, sum), do: checksum(rest, sum + val)
  defp checksum(<<val::8>>, sum), do: checksum(<<val, 0>>, sum)
  
  defp checksum(<<>>, sum) do
    <<left::16, right::16>> = <<sum::32>>
    <<bnot(left + right)::big-integer-size(16)>>
  end
end

# Also test with proper carry folding
defmodule ChecksumFixed do
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

IO.puts("Wikipedia IPv4 Header Checksum Test")
IO.puts("====================================")
IO.puts("Header with checksum 0xb861 included:")
IO.puts(inspect(header, limit: :infinity))

result1 = Checksum.checksum(header)
result2 = ChecksumFixed.checksum(header)

IO.puts("\nCurrent implementation result: #{inspect(result1)}")
IO.puts("Fixed implementation result:   #{inspect(result2)}")
IO.puts("\nExpected: <<0, 0>>")
IO.puts("Test #{if result1 == <<0, 0>>, do: "PASSED ✓", else: "FAILED ✗"} (current)")
IO.puts("Test #{if result2 == <<0, 0>>, do: "PASSED ✓", else: "FAILED ✗"} (fixed)")

# Let's also verify by computing the checksum from scratch
header_zeroed = <<
  0x45, 0x00, 0x00, 0x73,
  0x00, 0x00, 0x40, 0x00,
  0x40, 0x11, 0x00, 0x00,  # Checksum zeroed
  0xc0, 0xa8, 0x00, 0x01,
  0xc0, 0xa8, 0x00, 0xc7
>>

computed1 = Checksum.checksum(header_zeroed)
computed2 = ChecksumFixed.checksum(header_zeroed)

IO.puts("\n--- Computing checksum from scratch (with checksum field = 0) ---")
IO.puts("Current implementation: #{inspect(computed1)}")
IO.puts("Fixed implementation:   #{inspect(computed2)}")
IO.puts("Expected: <<184, 97>> (0xb861)")
