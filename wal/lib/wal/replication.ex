defmodule Wal.Replication do
  use Postgrex.ReplicationConnection

  require Logger

  def start_link(_opts) do
    config = Wal.Repo.config()

    # Automatically reconnect if we lose connection.
    extra_opts = [
      auto_reconnect: true
    ]

    Postgrex.ReplicationConnection.start_link(
      __MODULE__,
      :ok,
      extra_opts ++ config
    )
  end

  @impl Postgrex.ReplicationConnection
  def init(:ok) do
    {:ok, %{messages: [], relations: %{}}}
  end

  @impl Postgrex.ReplicationConnection
  def handle_connect(state) do
    query =
      """
      START_REPLICATION SLOT postgrex
      LOGICAL 0/0
      (proto_version '1', publication_names 'postgrex_publication')
      """

    Logger.debug(query)
    {:stream, query, [], state}
  end

  # Primary Keep Alive Message
  # https://www.postgresql.org/docs/current/protocol-replication.html#PROTOCOL-REPLICATION-PRIMARY-KEEPALIVE-MESSAGE
  @impl Postgrex.ReplicationConnection
  def handle_data(<<?k, wal_end::64, _server_time::64, should_reply::8>>, state) do
    messages =
      case should_reply do
        # Standby Status Update
        # https://www.postgresql.org/docs/current/protocol-replication.html#PROTOCOL-REPLICATION-STANDBY-STATUS-UPDATE
        1 -> [<<?r, wal_end + 1::64, wal_end + 1::64, wal_end + 1::64, current_time()::64, 0>>]
        0 -> []
      end

    Logger.debug("Responding to keep alive: #{should_reply} - #{inspect(messages)}")

    {:noreply, messages, state}
  end

  # XLogData
  # https://www.postgresql.org/docs/current/protocol-replication.html#PROTOCOL-REPLICATION-STANDBY-STATUS-UPDATE
  def handle_data(<<?w, raw_lsn::64, latest_lsn::64, _server_time::64, payload::bytes>>, state) do
    payload = Wal.Decoder.parse(payload)
    {:ok, lsn} = Postgrex.ReplicationConnection.encode_lsn(raw_lsn)
    {:ok, latest_lsn} = Postgrex.ReplicationConnection.encode_lsn(latest_lsn)

    message = %{
      lsn: lsn,
      latest_lsn: latest_lsn,
      type: payload.type,
      payload: payload
    }

    Logger.debug(message)
    state = handle_message(message, state)

    {:noreply, state}
  end

  # When a RELATION message arrives, store its structure in memory.
  defp handle_message(
         %{type: :relation, payload: %{relation_id: relation_id} = relation} = _message,
         %{relations: relations} = state
       ) do
    %{state | relations: Map.put(relations, relation_id, relation)}
  end

  # When a COMMIT message arrives, apply the changes.
  defp handle_message(
         %{type: :commit} = _message,
         %{messages: messages, relations: relations} = state
       ) do
    changes =
      Enum.reduce(messages, [], fn message, acc ->
        if message.type in [:insert, :update, :delete] do
          relation = Map.fetch!(relations, message.payload.relation_id)

          data =
            relation.columns
            |> Enum.zip(message.payload.data)
            |> Map.new(fn {%{name: name}, %{value: value}} ->
              {name, value}
            end)

          change = %{
            lsn: message.lsn,
            type: message.type,
            table: relation.relation_name,
            data: data
          }

          [change | acc]
        else
          acc
        end
      end)

    IO.inspect(changes, label: "Changes")

    %{state | messages: []}
  end

  defp handle_message(message, %{messages: messages} = state) do
    %{state | messages: [message | messages]}
  end

  @epoch DateTime.to_unix(~U[2000-01-01 00:00:00Z], :microsecond)
  defp current_time, do: System.os_time(:microsecond) - @epoch
end
