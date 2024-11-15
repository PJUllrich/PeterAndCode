defmodule FluxWeb.TableLive do
  use FluxWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.table>
      <.table_head>
        <:col>Lead</:col>
        <:col>Stage</:col>
        <:col>Contact</:col>
      </.table_head>
      <.table_body class="divide-y-2 divide-gray-100">
        <.table_row :for={lead <- @leads} class="hover:bg-gray-700">
          <:cell><%= lead.name %></:cell>
          <:cell><%= lead.status %></:cell>
          <:cell><%= lead.contact %></:cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, :leads, [
       %{name: "Foobar", status: :contacted, contact: "+12345678901"},
       %{name: "Foobar", status: :contacted, contact: "+12345678901"},
       %{name: "Foobar", status: :contacted, contact: "+12345678901"},
       %{name: "Foobar", status: :contacted, contact: "+12345678901"}
     ])}
  end
end
