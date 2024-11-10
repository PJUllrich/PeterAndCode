defmodule App.StreamState do
  use Agent

  @me __MODULE__

  @initial_state %{
    live: false
  }

  # Starts a new Agent process with an initial state.
  def start_link(_args) do
    Agent.start_link(fn -> @initial_state end, name: @me)
  end

  def set_live(live) do
    state =
      Agent.get_and_update(@me, fn state ->
        state = Map.put(state, :live, live)
        {state, state}
      end)

    Phoenix.PubSub.broadcast!(App.PubSub, "stream-state", {:changed, state})
  end

  def get_state(), do: Agent.get(@me, fn state -> state end)
end
