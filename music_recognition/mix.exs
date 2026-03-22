defmodule MusicRecognition.MixProject do
  use Mix.Project

  def project do
    [
      app: :music_recognition,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MusicRecognition.Application, []}
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.9"},
      {:explorer, "~> 0.10"},
      {:exla, "~> 0.9"},
      {:jason, "~> 1.4"}
    ]
  end
end
