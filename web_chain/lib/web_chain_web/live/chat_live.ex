defmodule WebChainWeb.ChatLive do
  use WebChainWeb, :live_view

  alias WebChain.Claude

  alias Phoenix.LiveView.AsyncResult

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:messages, [])
     |> assign(link: nil, async_result: %AsyncResult{})}
  end

  def handle_event("submit", %{"message" => %{"message" => message}}, socket) do
    link = socket.assigns.link

    socket =
      if link == nil do
        socket
        |> summarize(message)
        |> assign(link: message, chain: nil)
      else
        send_message_to_llm(socket, message)
      end

    socket = socket |> add_message(message, true) |> assign(:async_result, AsyncResult.loading())

    {:noreply, socket}
  end

  def handle_info({:chat_response, updated_chain, %LangChain.MessageDelta{} = delta}, socket) do
    socket =
      socket
      |> add_message(delta.content, false)
      |> assign(:chain, updated_chain)

    socket =
      if delta.status == :complete do
        socket
        |> add_message("\n\n\n\n\n\n\n", false)
        |> assign(:async_result, AsyncResult.ok(nil))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_async(:article, {:ok, summary}, socket) do
    socket =
      start_async(socket, :response, fn ->
        Claude.summarize(summary.article_text, callback_handler())
      end)

    {:noreply, socket}
  end

  def handle_async(:response, {:ok, {updated_chain, response}}, socket) do
    socket =
      socket
      |> add_message(response.content, false)
      |> assign(async_result: AsyncResult.ok(nil), chain: updated_chain)

    {:noreply, socket}
  end

  defp callback_handler() do
    live_view_pid = self()

    %{
      on_llm_new_delta: fn model, delta ->
        send(live_view_pid, {:chat_response, model, delta})
      end
    }
  end

  defp summarize(socket, link) do
    start_async(socket, :article, fn -> Readability.summarize(link) end)
  end

  defp send_message_to_llm(socket, message) do
    chain = socket.assigns.chain

    start_async(socket, :response, fn ->
      Claude.add_message(message, callback_handler(), chain)
    end)
  end

  defp add_message(socket, message, user_message? \\ false) do
    stream_insert(socket, :messages, %{
      id: System.unique_integer([:positive]),
      content: message,
      user_message?: user_message?
    })
  end
end
