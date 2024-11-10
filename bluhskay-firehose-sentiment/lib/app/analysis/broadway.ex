defmodule App.Analysis.Broadway do
  use Broadway

  require Logger

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(App.Analysis.Broadway,
      name: BroadwayBlueskeyAnalysis,
      producer: [
        module: {App.Analysis.Broadway.Producer, []},
        concurrency: 1
      ],
      processors: [
        filter: [concurrency: 1]
      ],
      batchers: [
        analyis: [concurrency: 1, batch_size: 10]
      ]
    )
  end

  @impl true
  def handle_message(:filter, message, _context) do
    case message.data do
      %{"record" => %{"langs" => ["en"], "text" => text}} ->
        Message.put_data(message, fn _data -> text end)

      _ ->
        Message.failed(message, "Non-english post")
    end
  end

  @impl true
  def handle_batch(:analysis, messages, _batch_info, _context) do
    IO.inspect(messages)
    messages
  end
end
