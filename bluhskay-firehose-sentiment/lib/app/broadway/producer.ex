defmodule App.Broadway.Producer do
  @behaviour Broadway.Producer

  alias Broadway.Message

  def start_link(_argse) do
    GenStage.start_link(__MODULE__, [])
  end

  def init(_opts) do
    {:producer, {[], 0}}
  end

  def handle_demand(demand, state) do
    do_handle_demand(demand, state)
  end

  defp do_handle_demand(new_demand, {events, pending_demand}) do
    total_demand = new_demand + pending_demand - length(events)

    new_events = App.Buffer.get_events(total_demand)
    all_events = new_events ++ events
    met_demand = length(all_events)

    if met_demand >= total_demand do
      messages =
        Enum.map(all_events, fn event ->
          %Message{data: event, acknowledger: Broadway.NoopAcknowledger.init()}
        end)

      {:noreply, messages, {[], 0}}
    else
      :timer.sleep(250)
      do_handle_demand(0, {all_events, max(total_demand - met_demand, 0)})
    end
  end
end
