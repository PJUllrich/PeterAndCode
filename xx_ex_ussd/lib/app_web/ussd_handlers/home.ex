defmodule AppWeb.Handlers.Home do
  alias AppWeb.Handlers.{MaizePrice, SoybeansPrice, SesameSeedsPrice}
  @behaviour ExUssd.Handler
  def handle_menu(menu, _api_parameters) do
    menu
    |> Map.put(
      :title,
      "Welcome to PriceWatch.\nWhich commodity prices do you want to see?"
    )
    |> Map.put(
      :menu_list,
      [
        ExUssd.Menu.render(name: "Maize", handler: MaizePrice),
        ExUssd.Menu.render(name: "Soybeans", handler: SoybeansPrice),
        ExUssd.Menu.render(name: "Sesame seeds", handler: SesameSeedsPrice)
      ]
    )
  end
end
