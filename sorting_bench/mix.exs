defmodule SortingBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :sorting_bench,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Rust NIF integration
      {:rustler, "~> 0.36"},

      # Benchmarking
      {:benchee, "~> 1.3"},
      {:benchee_html, "~> 1.0"},

      # Nx (numerical computing) — two backends benchmarked
      {:nx, "~> 0.9"},
      {:exla, "~> 0.9"},

      # Explorer (Polars-backed DataFrames)
      {:explorer, "~> 0.10"}
    ]
  end
end
