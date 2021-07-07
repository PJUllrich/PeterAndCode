defmodule WaveshareHat.Calling do
  @moduledoc """
  Includes helper functions for calling.
  """

  import WaveshareHat.Utils

  @doc """
  Enable (1) or disable (0) CLIP notifications.
  """
  def set_clip(pid, status) when status in [0, 1] do
    write(pid, "AT+CLIP=#{status}")
  end

  @doc """
  Start a phone call with a given number.
  """
  def call_phone(pid, number), do: write(pid, "ATD#{number};")

  @doc """
  Answer an incoming phone call.
  """
  def answer_phone(pid), do: write(pid, "ATA")

  @doc """
  Hang up on the currently active phone call.
  """
  def hang_up(pid), do: write(pid, "ATH")
end
