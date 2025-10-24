defmodule Wal.Replication do
  use Postgrex.ReplicationConnection

  require Logger

  def start_link(_opts) do
    config = Wal.Repo.config()

    # Automatically reconnect if we lose connection.
    extra_opts = [
      auto_reconnect: true
    ]

    Postgrex.ReplicationConnection.start_link(__MODULE__, :ok, extra_opts ++ config)
  end

  @impl Postgrex.ReplicationConnection
  def init(:ok) do
    {:ok, %{step: :disconnected}}
  end

  @impl Postgrex.ReplicationConnection
  def handle_connect(state) do
    query =
      "START_REPLICATION SLOT postgrex LOGICAL 0/0 (proto_version '4', publication_names 'postgrex_publication')"

    Logger.debug(query)
    {:stream, query, [], %{state | step: :streaming}}
  end

  @impl Postgrex.ReplicationConnection
  # Primary Keep Alive Message
  # https://www.postgresql.org/docs/current/protocol-replication.html#PROTOCOL-REPLICATION-PRIMARY-KEEPALIVE-MESSAGE
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
  def handle_data(<<?w, wal_start::64, wal_end::64, _server_time::64, payload::bytes>>, state) do
    message = parse_payload(payload)
    IO.inspect([to_lsn(wal_start), to_lsn(wal_end), message])
    {:noreply, state}
  end

  @epoch DateTime.to_unix(~U[2000-01-01 00:00:00Z], :microsecond)
  defp current_time, do: System.os_time(:microsecond) - @epoch

  defp to_lsn(integer) when is_integer(integer) do
    <<xlogid::32, xrecoff::32>> = <<integer::64>>

    left = xlogid |> Integer.to_string(16) |> String.upcase()
    right = xrecoff |> Integer.to_string(16) |> String.upcase()

    "#{left}/#{right}"
  end

  # Begin
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-BEGIN
  defp parse_payload(<<?B, lsn_end::64, _timestamp::64, tx_id::32>>) do
    %{type: :begin, lsn_end: to_lsn(lsn_end), tx_id: tx_id}
  end

  # Commit
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-COMMIT
  defp parse_payload(<<?C, _flags::8, lsn::64, lsn_end::64, _timestamp::64>>) do
    %{type: :commit, lsn: to_lsn(lsn), lsn_end: to_lsn(lsn_end)}
  end

  # Insert
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-INSERT
  # Without transaction_id because
  defp parse_payload(<<?I, oid::32, ?N, tuple_data::bytes>>) do
    %{type: :insert, oid: oid, data: parse_tuple_data(tuple_data)}
  end

  defp parse_payload(<<identifier::binary-size(1), rest::bytes>>) do
    Logger.warning("Unhandled message: #{identifier} - #{inspect(rest)}")
    nil
  end

  # TupleData
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-TUPLEDATA
  defp parse_tuple_data(<<_column_count::16, data::bytes>>) do
    parse_column(0, [], data)
  end

  defp parse_column(_idx, columns, <<>>), do: Enum.reverse(columns)

  defp parse_column(idx, columns, data) do
    <<type::binary-size(1), length::32, value::bytes-size(length), data::bytes>> = data

    type =
      case type do
        <<?n>> -> :null
        <<?u>> -> :toasted
        <<?t>> -> :text
        <<?b>> -> :binary
      end

    column = %{idx: idx, type: type, length: length, value: value}
    parse_column(idx + 1, [column | columns], data)
  end
end
