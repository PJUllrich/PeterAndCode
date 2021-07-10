defmodule WaveshareHat.GNSS do
  @moduledoc """
  Includes helper functions for GNSS (GPS etc.) functionality.
  """
  import WaveshareHat.Utils

  @doc """
  Turn the GPS  module On (1) or Off (0)
  """
  def set_on_or_off(pid, state) when state in [0, 1] do
    write(pid, "AT+CGNSPWR=#{state}")
  end

  @doc """
  Returns the current GPS status.
  """
  def get_status(pid) do
    write(pid, "AT+CGPSSTATUS")
  end

  @doc """
  Enquire about the current baud rate of the GPS.
  """
  def get_baud_rate(pid) do
    write(pid, "AT+CGNSIPR?")
  end

  @doc """
  Set the baud rate of the GPS.
  """
  def set_baud_rate(pid, rate) when is_integer(rate) and rate >= 0 do
    write(pid, "AT+CGNSIPR=#{rate}")
  end

  @doc """
  Enable (1) or disable (0) sending new gps location data from the WaveshareHat via UART connecton.

  The output will be according to the [NMEA description](https://navspark.mybigcommerce.com/content/NMEA_Format_v0.1.pdf).
  """
  def set_send_gps_data_to_uart(pid, state) when state in [0, 1] do
    write(pid, "AT+CGNSTST=#{state}")
  end

  @doc """
  Returns the GNSS navigation information parsed from NMEA sentences.
  """
  def get_gps_information(pid) do
    write(pid, "AT+CGNSINF")
  end
end
