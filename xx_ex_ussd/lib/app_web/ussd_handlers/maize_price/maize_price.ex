defmodule AppWeb.Handlers.MaizePrice do
  alias AppWeb.Handlers.MaizePrice.{Nairobi, Thika, Mombasa, Nakuru}

  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu
    |> Map.put(:title, "Select a city")
    |> Map.put(:menu_list, [
      ExUssd.Menu.render(name: "Nairobi", handler: Nairobi),
      ExUssd.Menu.render(name: "Thika", handler: Thika),
      ExUssd.Menu.render(name: "Mombasa", handler: Mombasa),
      ExUssd.Menu.render(name: "Nakuru", handler: Nakuru)
    ])
  end
end
