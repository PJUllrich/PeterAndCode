defmodule Stocks.ResourceTemplates.StockProfile do
  @behaviour EMCP.ResourceTemplate

  @impl EMCP.ResourceTemplate
  def uri_template, do: "stocks:///profile/{symbol}"

  @impl EMCP.ResourceTemplate
  def name, do: "stock_profile"

  @impl EMCP.ResourceTemplate
  def description, do: "Company profile for a stock symbol including name, industry, and market cap"

  @impl EMCP.ResourceTemplate
  def mime_type, do: "application/json"

  @impl EMCP.ResourceTemplate
  def read(_conn, "stocks:///profile/" <> symbol) do
    symbol = String.upcase(symbol)
    api_key = Application.fetch_env!(:stocks, :finnhub_api_key)
    url = "https://finnhub.io/api/v1/stock/profile2?symbol=#{symbol}&token=#{api_key}"

    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: %{"name" => _} = body}} ->
        {:ok, JSON.encode!(body)}

      {:ok, %Req.Response{status: 200, body: _}} ->
        {:error, "Unknown symbol: #{symbol}"}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  def read(_conn, _uri), do: {:error, "Resource not found"}
end
