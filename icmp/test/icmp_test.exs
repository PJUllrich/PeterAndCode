defmodule IcmpTest do
  use ExUnit.Case
  doctest Icmp

  test "greets the world" do
    assert Icmp.hello() == :world
  end
end
