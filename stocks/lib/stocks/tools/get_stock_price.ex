defmodule Stocks.Tools.GetStockPrice do
  @behaviour EMCP.Tool

  @impl EMCP.Tool
  def name, do: "GetStockPrice"

  @impl EMCP.Tool
  def description,
    do: "Returns the current stock price for a given stock identifier (ticker symbol)"

  @impl EMCP.Tool
  def input_schema do
    %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "The stock ticker symbol, e.g. AAPL, GOOGL, MSFT"}
      },
      required: [:symbol]
    }
  end

  @impl EMCP.Tool
  def call(_conn, %{"symbol" => symbol}) do
    symbol = String.upcase(symbol)

    case Stocks.StockPrice.fetch(symbol) do
      {:ok, price} ->
        EMCP.Tool.response([
          %{"type" => "text", "text" => "The current stock price of #{symbol} is $#{price}"}
        ])

      {:error, reason} ->
        EMCP.Tool.error("Failed to fetch stock price for #{symbol}: #{reason}")
    end
  end
end
