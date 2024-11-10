defmodule App.Buffer do
  use GenServer

  @buffer_size 10_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_events(demand) do
    GenServer.call(__MODULE__, {:get_events, demand})
  end

  def insert_event(event) do
    GenServer.cast(__MODULE__, {:insert, event})
  end

  def init(_opts) do
    buffer = RingBuffer.new(@buffer_size)
    {:ok, buffer}
  end

  def handle_cast({:insert, event}, buffer) do
    buffer = RingBuffer.put(buffer, event)
    {:noreply, buffer}
  end

  def handle_call({:get_events, demand}, _from, buffer) do
    {events, buffer} =
      Enum.reduce_while(1..demand//1, {[], buffer}, fn _idx, {events, buffer} ->
        case RingBuffer.take(buffer) do
          {nil, buffer} -> {:halt, {events, buffer}}
          {event, buffer} -> {:cont, {[event | events], buffer}}
        end
      end)

    {:reply, events, buffer}
  end
end
