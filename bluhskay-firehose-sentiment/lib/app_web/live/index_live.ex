defmodule AppWeb.IndexLive do
  use AppWeb, :live_view

  alias App.Datapoints

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex space-x-2">
        <.link patch={~p"/?#{[tab: :datapoints]}"}>Datapoints</.link>
        <.link patch={~p"/?#{[tab: :averages]}"}>Averages</.link>
      </div>
      <div id="graph" phx-hook="EChart" phx-update="ignore" class="w-full h-[400px]" />
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Timestamp
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Average
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Sum
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Count
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Edit</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white" id="datapoints" phx-update="stream">
                  <tr :for={{id, datapoint} <- @streams.datapoints} id={id}>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= datapoint.inserted_at %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= datapoint.average %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= datapoint.sum %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= datapoint.count %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:datapoints, dom_id: fn dp -> to_string(dp.inserted_at) end)
     |> stream(:datapoints, [])
     |> stream_configure(:averages, dom_id: fn dp -> to_string(dp.datetime) end)
     |> stream(:averages, [])}
  end

  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "datapoints")

    case tab do
      "datapoints" ->
        {:noreply, setup_datapoints(socket)}

      "averages" ->
        {:noreply, setup_averages(socket)}
    end
  end

  def handle_info({:datapoint, datapoint}, socket) do
    {:noreply,
     socket |> push_items([datapoint], "datapoints") |> stream_insert(:datapoints, datapoint)}
  end

  defp setup_datapoints(socket) do
    items =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(App.PubSub, "new-datapoint")
        Datapoints.list_datapoints()
      else
        []
      end

    push_items(socket, items, "datapoints", true)
  end

  defp setup_averages(socket) do
    items =
      if connected?(socket) do
        Phoenix.PubSub.unsubscribe(App.PubSub, "new-datapoint")
        Datapoints.get_average_per_minute()
      else
        []
      end

    push_items(socket, items, "averages", true)
  end

  defp push_items(socket, items, name, reset \\ false) do
    socket = if reset, do: push_event(socket, "reset-" <> name, %{}), else: socket
    push_event(socket, name, %{items: items})
  end
end
