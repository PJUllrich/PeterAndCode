defmodule VintageNetMobile.Modem.Waveshare800 do
  @moduledoc """
  Sierra Wireless HL8548 modem

  https://source.sierrawireless.com/resources/airprime/hardware_specs_user_guides/airprime_hl8548_and_hl8548-g_product_technical_specification/

  The Sierra Wireless HL8548 is an industrial grade Embedded Wireless Module
  that provides voice and data connectivity on GPRS, EDGE, WCDMA, HSDPA and
  HSUPA networks.

  Here's an example configuration:

  ```elixir
  VintageNet.configure(
    "ppp0",
    %{
      type: VintageNetMobile,
      vintage_net_mobile: %{
        modem: VintageNetMobile.Modem.SierraHL8548,
        service_providers: [%{apn: "BROADBAND"}]
      }
    }
  )
  ```
  """

  # Useful references:
  #  * AT commands - https://source.sierrawireless.com/resources/airprime/software/airprime_hl6_and_hl8_series_at_commands_interface_guide

  @behaviour VintageNetMobile.Modem

  alias VintageNetMobile.{ExChat, SignalMonitor, PPPDConfig, Chatscript}
  alias VintageNetMobile.Modem.Utils
  alias VintageNet.Interface.RawConfig

  @impl true
  def normalize(config) do
    config
    |> Utils.require_a_service_provider()
  end

  @impl true
  def add_raw_config(raw_config, %{vintage_net_mobile: mobile} = _config, opts) do
    ifname = raw_config.ifname

    service_provider = hd(mobile.service_providers)
    files = [{Chatscript.path(ifname, opts), chatscript(service_provider)}]
    at_tty = Map.get(mobile, :at_tty, "ttyUSB2")
    ppp_tty = Map.get(mobile, :ppp_tty, "ttyUSB3")

    child_specs = [
      {ExChat, [tty: at_tty, speed: 115_200]},
      {SignalMonitor, [ifname: ifname, tty: at_tty]}
    ]

    %RawConfig{
      raw_config
      | files: files,
        child_specs: child_specs
    }
    |> PPPDConfig.add_child_spec(ppp_tty, 115_200, opts)
  end

    defp chatscript(service_provider) do
      pdp_index = 1
    [
      """
      # Custom prologue
      "" +++
      OK AT
      OK ATH
      OK ATZ
      OK ATQ0
      """,
      Chatscript.set_pdp_context(pdp_index, service_provider),
      """
      # Set the Network APN
      OK AT+CSTT="#{service_provider.apn}"

      # Bring up wireless connection with GPRS
      OK AT+CIICR
      """,
      Chatscript.connect()
    ]
    |> IO.iodata_to_binary()
  end
end
