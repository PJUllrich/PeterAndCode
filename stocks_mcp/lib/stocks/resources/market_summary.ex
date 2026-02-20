defmodule Stocks.Resources.MarketSummary do
  @behaviour EMCP.Resource

  @impl EMCP.Resource
  def uri, do: "stocks:///market-summary"

  @impl EMCP.Resource
  def name, do: "market_summary"

  @impl EMCP.Resource
  def description, do: "A snapshot of all currently subscribed stocks with their latest prices"

  @impl EMCP.Resource
  def mime_type, do: "application/json"

  @impl EMCP.Resource
  def read(_conn) do
    symbols = Stocks.Finnhub.list_subscriptions()

    prices =
      Enum.map(symbols, fn symbol ->
        case Stocks.StockPrice.fetch(symbol) do
          {:ok, price} -> %{symbol: symbol, price: price}
          {:error, _} -> %{symbol: symbol, price: nil}
        end
      end)

    JSON.encode!(%{subscriptions: length(prices), stocks: prices})
  end
end
