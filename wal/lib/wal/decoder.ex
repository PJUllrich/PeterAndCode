defmodule Wal.Decoder do
  @moduledoc """
  Parses raw `XLogData` messages into maps.
  """

  require Logger

  # Begin
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-BEGIN
  def parse(<<?B, lsn_end::64, _timestamp::64, tx_id::32>>) do
    %{type: :begin, lsn_end: to_lsn(lsn_end), tx_id: tx_id}
  end

  # Commit
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-COMMIT
  def parse(<<?C, _flags::8, lsn::64, lsn_end::64, _timestamp::64>>) do
    %{type: :commit, commit_lsn: to_lsn(lsn), tx_end_lsn: to_lsn(lsn_end)}
  end

  # Relation
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-RELATION
  def parse(<<?R, relation_id::32, rest::bytes>>) do
    # Strings in XLogData messages are Null/Zero-separated
    [namespace, relation_name, rest] = String.split(rest, <<0>>, parts: 3)
    <<replica_identity_setting::8, _column_count::16, columns::bytes>> = rest

    # https://www.postgresql.org/docs/current/catalog-pg-class.html#CATALOG-PG-CLASS
    replica_identity_setting =
      case replica_identity_setting do
        ?d -> :default
        ?n -> :nothing
        ?f -> :all_columns
        ?i -> :index
      end

    columns = parse_relation_columns(columns)

    %{
      type: :relation,
      relation_id: relation_id,
      namespace: namespace,
      relation_name: relation_name,
      replica_identity_setting: replica_identity_setting,
      columns: columns
    }
  end

  # Insert
  # Without transaction_id because we are not streaming transactions
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-INSERT
  def parse(<<?I, relation_id::32, ?N, tuple_data::bytes>>) do
    %{type: :insert, relation_id: relation_id, data: parse_tuple_data(tuple_data)}
  end

  def parse(<<identifier::binary-size(1), rest::bytes>>) do
    Logger.warning("Unhandled message: #{identifier} - #{inspect(rest)}")
    nil
  end

  # TupleData
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-TUPLEDATA
  defp parse_tuple_data(<<_column_count::16, data::bytes>>) do
    parse_tuple_data_column(data)
  end

  defp parse_tuple_data_column(data, columns \\ [])
  defp parse_tuple_data_column(<<>>, columns), do: Enum.reverse(columns)

  defp parse_tuple_data_column(data, columns) do
    <<type::binary-size(1), length::32, value::bytes-size(length), data::bytes>> = data

    type =
      case type do
        <<?n>> -> :null
        <<?u>> -> :toasted
        <<?t>> -> :text
        <<?b>> -> :binary
      end

    column = %{type: type, length: length, value: value}
    parse_tuple_data_column(data, [column | columns])
  end

  # Relation Columns
  # https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html#PROTOCOL-LOGICALREP-MESSAGE-FORMATS-RELATION
  defp parse_relation_columns(data, columns \\ [])
  defp parse_relation_columns(<<>>, columns), do: Enum.reverse(columns)

  defp parse_relation_columns(data, columns) do
    <<flag::8, data::bytes>> = data

    [column_name, <<data_type_oid::32, type_modifier::32, data::bytes>>] =
      String.split(data, <<0>>, parts: 2)

    column = %{
      flag: flag,
      name: column_name,
      data_type_oid: data_type_oid,
      type_modifier: type_modifier
    }

    parse_relation_columns(data, [column | columns])
  end

  defp to_lsn(lsn_int) when is_integer(lsn_int) do
    <<xlogid::32, xrecoff::32>> = <<lsn_int::64>>

    file_id = xlogid |> Integer.to_string(16) |> String.upcase()
    offset = xrecoff |> Integer.to_string(16) |> String.upcase()

    "#{file_id}/#{offset}"
  end
end
