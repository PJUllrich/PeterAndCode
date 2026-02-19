defmodule Stocks.Tools.ListSubscriptions do
  @behaviour EMCP.Tool

  @impl EMCP.Tool
  def name, do: "ListSubscriptions"

  @impl EMCP.Tool
  def description,
    do: "Lists all stock symbols currently subscribed to for real-time price updates"

  @impl EMCP.Tool
  def input_schema do
    %{
      type: :object,
      properties: %{}
    }
  end

  @impl EMCP.Tool
  def call(_conn, _params) do
    symbols = Stocks.Finnhub.list_subscriptions()

    case symbols do
      [] ->
        EMCP.Tool.response([
          %{"type" => "text", "text" => "No active stock subscriptions"}
        ])

      symbols ->
        list = Enum.join(symbols, ", ")

        EMCP.Tool.response([
          %{"type" => "text", "text" => "Currently subscribed to: #{list}"}
        ])
    end
  end
end
