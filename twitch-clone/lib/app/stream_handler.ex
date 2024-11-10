defmodule App.StreamHandler do
  @moduledoc """
  An implementation of `Membrane.RTMPServer.ClienHandlerBehaviour` compatible with the
  `Membrane.RTMP.Source` element.
  """

  @behaviour Membrane.RTMPServer.ClientHandler

  defstruct [:controlling_process]

  @impl true
  def handle_init(opts) do
    %{
      source_pid: nil,
      buffered: [],
      app: nil,
      stream_key: nil,
      controlling_process: opts.controlling_process
    }
  end

  @impl true
  def handle_connected(connected_msg, state) do
    %{state | app: connected_msg.app}
  end

  @impl true
  def handle_stream_published(publish_msg, state) do
    expected_stream_key = Application.get_env(:app, :stream_key)

    if publish_msg.stream_key == expected_stream_key do
      App.StreamState.set_live(true)
      %{state | stream_key: publish_msg.stream_key}
    else
      nil
    end
  end

  @impl true
  def handle_info({:send_me_data, source_pid}, state) do
    buffers_to_send = Enum.reverse(state.buffered)
    state = %{state | source_pid: source_pid, buffered: []}
    Enum.each(buffers_to_send, fn buffer -> send_data(state.source_pid, buffer) end)
    state
  end

  @impl true
  def handle_info(_other, state) do
    state
  end

  @impl true
  def handle_data_available(payload, state) do
    if state.source_pid do
      :ok = send_data(state.source_pid, payload)
      state
    else
      %{state | buffered: [payload | state.buffered]}
    end
  end

  @impl true
  def handle_end_of_stream(state) do
    if state.source_pid != nil, do: send_eos(state.source_pid)
    App.StreamState.set_live(false)
    state
  end

  defp send_data(pid, payload) do
    send(pid, {:data, payload})
    :ok
  end

  defp send_eos(pid) do
    send(pid, :end_of_stream)
    :ok
  end
end
