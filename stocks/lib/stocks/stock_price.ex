defmodule Stocks.StockPrice do
  @doc """
  Fetches the current stock price for the given ticker symbol.

  Returns `{:ok, price_string}` or `{:error, reason}`.
  """
  def fetch(symbol) do
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{symbol}?interval=1d&range=1d"

    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_price(body)

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp parse_price(%{
         "chart" => %{
           "result" => [%{"meta" => %{"regularMarketPrice" => price}} | _]
         }
       }) do
    {:ok, :erlang.float_to_binary(price / 1, decimals: 2)}
  end

  defp parse_price(_body) do
    {:error, "unexpected response format"}
  end
end
