defmodule Stocks.Tools.UnsubscribeFromStock do
  @behaviour EMCP.Tool

  @impl EMCP.Tool
  def name, do: "UnsubscribeFromStock"

  @impl EMCP.Tool
  def description,
    do: "Unsubscribes from real-time stock price updates for a given ticker symbol"

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

    case Stocks.Finnhub.unsubscribe(symbol) do
      :ok ->
        notify_resource_updated()

        EMCP.Tool.response([
          %{"type" => "text", "text" => "Unsubscribed from real-time stock updates for #{symbol}"}
        ])

      {:error, reason} ->
        EMCP.Tool.error("Failed to unsubscribe from #{symbol}: #{inspect(reason)}")
    end
  end

  defp notify_resource_updated do
    EMCP.Transport.StreamableHTTP.broadcast(EMCP.SessionStore.ETS, %{
      "jsonrpc" => "2.0",
      "method" => "notifications/resources/updated",
      "params" => %{"uri" => "stocks:///market-summary"}
    })
  end
end
