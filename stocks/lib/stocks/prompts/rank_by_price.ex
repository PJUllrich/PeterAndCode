defmodule Stocks.Prompts.RankByPrice do
  @behaviour EMCP.Prompt

  @impl EMCP.Prompt
  def name, do: "rank_by_price"

  @impl EMCP.Prompt
  def description, do: "Fetches stock prices for given symbols, ranks them by price, and calculates percentage differences between consecutive entries"

  @impl EMCP.Prompt
  def arguments do
    [
      %{name: "symbols", description: "Comma-separated stock ticker symbols (e.g. AAPL,NVDA,MSFT,GOOGL,AMZN)", required: true}
    ]
  end

  @impl EMCP.Prompt
  def template(_conn, %{"symbols" => symbols}) do
    %{
      "description" => "Rank stocks by price with percentage differences",
      "messages" => [
        %{
          "role" => "user",
          "content" => %{
            "type" => "text",
            "text" =>
              "Fetch the stock prices for these symbols: #{symbols}. " <>
                "Rank them by stock price from highest to lowest. " <>
                "Then calculate the percentage difference from each element to the next: " <>
                "from the 1st to the 2nd, the 2nd to the 3rd, and so on. " <>
                "Present the results in a clear table format."
          }
        }
      ]
    }
  end
end
