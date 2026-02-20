defmodule Stocks.Finnhub do
  use GenServer

  require Logger

  defstruct [:ws, subscriptions: MapSet.new()]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(symbol) do
    GenServer.call(__MODULE__, {:subscribe, String.upcase(symbol)})
  end

  def unsubscribe(symbol) do
    GenServer.call(__MODULE__, {:unsubscribe, String.upcase(symbol)})
  end

  def list_subscriptions do
    __MODULE__
    |> GenServer.call(:list_subscriptions)
    |> Enum.sort()
  end

  # Server

  @impl GenServer
  def init(_opts) do
    {:ok, %__MODULE__{}, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    {:noreply, %{state | ws: start_websocket()}}
  end

  @impl GenServer
  def handle_call({:subscribe, symbol}, _from, state) do
    case Stocks.StockPrice.fetch(symbol) do
      {:ok, _price} ->
        send_frame(state.ws, %{"type" => "subscribe", "symbol" => symbol})
        {:reply, :ok, %{state | subscriptions: MapSet.put(state.subscriptions, symbol)}}

      {:error, reason} ->
        {:reply, {:error, "Unknown symbol #{symbol}: #{reason}"}, state}
    end
  end

  def handle_call({:unsubscribe, symbol}, _from, state) do
    send_frame(state.ws, %{"type" => "unsubscribe", "symbol" => symbol})
    {:reply, :ok, %{state | subscriptions: MapSet.delete(state.subscriptions, symbol)}}
  end

  def handle_call(:list_subscriptions, _from, state) do
    {:reply, MapSet.to_list(state.subscriptions), state}
  end

  @impl GenServer
  def handle_info({:ws_connected, ws}, state) do
    Logger.info("[Finnhub] WebSocket connected")

    Enum.each(state.subscriptions, fn symbol ->
      send_frame(ws, %{"type" => "subscribe", "symbol" => symbol})
    end)

    {:noreply, %{state | ws: ws}}
  end

  def handle_info({:ws_message, {:text, message}}, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "trade", "data" => trades}} ->
        broadcast_trades(trades)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:ws_disconnected, _code, _reason}, state) do
    Logger.warning("[Finnhub] WebSocket disconnected, reconnecting...")
    {:noreply, %{state | ws: start_websocket()}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # WebSocket

  defp start_websocket do
    parent = self()
    api_key = Application.fetch_env!(:stocks, :finnhub_api_key)
    uri = "wss://ws.finnhub.io?token=#{api_key}"

    Fresh.start_link(uri, Stocks.Finnhub.WebSocket, parent, [])
  end

  defp send_frame(ws, payload) do
    Kernel.send(ws, {:send_frame, Jason.encode!(payload)})
  end

  defp broadcast_trades(trades) do
    trades
    |> Enum.group_by(& &1["s"])
    |> Enum.each(fn {symbol, symbol_trades} ->
      latest = Enum.max_by(symbol_trades, & &1["t"])

      trade = %{
        symbol: symbol,
        price: latest["p"],
        timestamp: latest["t"],
        volume: latest["v"]
      }

      Phoenix.PubSub.broadcast(Stocks.PubSub, "stock:#{symbol}", {:stock_trade, trade})

      EMCP.Transport.StreamableHTTP.broadcast(
        EMCP.SessionStore.ETS,
        %{
          "jsonrpc" => "2.0",
          "method" => "notifications/stock_trade",
          "params" => trade
        }
      )
    end)
  end
end

defmodule Stocks.Finnhub.WebSocket do
  use Fresh

  require Logger

  @impl Fresh
  def handle_connect(_status, _headers, parent) do
    send(parent, {:ws_connected, self()})
    {:ok, parent}
  end

  @impl Fresh
  def handle_in(frame, parent) do
    send(parent, {:ws_message, frame})
    {:ok, parent}
  end

  @impl Fresh
  def handle_info({:send_frame, payload}, parent) do
    {:reply, {:text, payload}, parent}
  end

  def handle_info(_message, parent), do: {:ok, parent}

  @impl Fresh
  def handle_disconnect(code, reason, parent) do
    send(parent, {:ws_disconnected, code, reason})
    :close
  end
end
