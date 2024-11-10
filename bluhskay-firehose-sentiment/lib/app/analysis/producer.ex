defmodule App.Analysis.Broadway.Producer do
  @behaviour Broadway.Producer

  def start_link(_argse) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def put_event(event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:put, event}, timeout)
  end

  def init(_opts) do
    {:producer, [], buffer_size: 10_000, buffer_keep: :first}
  end

  def handle_call({:put, event}, _from, state) do
    # Dispatch immediately
    {:reply, :ok, [event], state}
  end

  def handle_demand(_demand, state) do
    # We don't care about the demand
    {:noreply, [], state}
  end
end
