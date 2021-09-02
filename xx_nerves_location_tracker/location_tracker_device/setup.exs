 VintageNet.configure(
    "ppp0",
    %{
      type: VintageNetMobile,
      vintage_net_mobile: %{
        modem: VintageNetMobile.Modem.Waveshare800,
        service_providers: [%{apn: "sipgate"}],
        at_tty: "ttyAMA0",
        ppp_tty: "ttyAMA0"
      }
    }
  )
