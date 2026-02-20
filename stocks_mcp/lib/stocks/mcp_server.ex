defmodule Stocks.MCPServer do
  use EMCP.Server,
    name: "stocks",
    version: "1.0.0",
    tools: [Stocks.Tools.GetStockPrice, Stocks.Tools.SubscribeToStock, Stocks.Tools.UnsubscribeFromStock, Stocks.Tools.ListSubscriptions],
    prompts: [Stocks.Prompts.RankByPrice],
    resources: [Stocks.Resources.MarketSummary],
    resource_templates: [Stocks.ResourceTemplates.StockProfile]
end
