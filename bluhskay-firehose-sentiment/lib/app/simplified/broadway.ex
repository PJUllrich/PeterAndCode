defmodule App.Simplified.Broadway do
  use Broadway

  require Logger

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(App.Simplified.Broadway,
      name: BroadwayBlueskeySimplified,
      producer: [
        module: {App.Simplified.Producer, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        default: [concurrency: 1, batch_size: 15]
      ],
      partition_by: &partition/1
    )
  end

  def partition(_msg), do: Enum.random([0, 1])

  @impl true
  def handle_message(:default, %Message{data: {:text, event}} = message, _context) do
    case Jason.decode(event) do
      {:ok, %{"commit" => %{"record" => %{"langs" => ["en"], "text" => text}}}} ->
        Message.put_data(message, text)

      {:ok, _message} ->
        Message.failed(message, "Non-english post")

      {:error, reason} ->
        Logger.error(inspect(reason))
        Message.failed(message, "Decoding error")
    end
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    # serving = if batch_info.partition == 0, do: BertServing1, else: BertServing2

    posts = Enum.map(messages, & &1.data)
    {time, result} = :timer.tc(fn -> Nx.Serving.batched_run(BertServing, posts) end)
    IO.inspect(time / 1_000_000)

    sum =
      Enum.reduce(result, 0, fn %{predictions: predictions}, acc ->
        top_score = predictions |> Enum.sort_by(& &1.score, :desc) |> hd()

        case top_score.label do
          "POS" -> acc + 1
          "NEU" -> acc
          "NEG" -> acc - 1
        end
      end)

    App.Dumper.add(sum, length(posts))

    messages
  end
end
