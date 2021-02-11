defmodule AppWeb.Handlers.SoybeansPrice do
  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu |> Map.put(:title, "Current Soybeans Price:\n4,300 ksh/90kg")
  end
end
