defmodule TrackerWeb.HomeLive do
  use TrackerWeb, :live_view

  require Logger

  @update_interval :timer.seconds(1)
  @max_planes 5

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Start the plane update timer
      Process.send_after(self(), :update_planes, @update_interval)
    end

    {:ok, assign(socket, :planes, generate_initial_planes())}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen w-full">
      <div id="map" class="h-full w-full" phx-hook="PlaneMap"></div>
    </div>
    """
  end

  def handle_info(:update_planes, socket) do
    Logger.info("Updating planes")
    planes = socket.assigns.planes

    updated_planes =
      planes
      |> update_plane_positions()
      |> maybe_add_new_plane()

    # Push updates for all planes
    socket =
      Enum.reduce(updated_planes, socket, fn {id, plane}, socket ->
        if plane_moved?(planes[id], plane) do
          push_event(socket, "plane_update", %{
            id: id,
            lat: plane.lat,
            lng: plane.lng,
            direction: plane.direction,
            flight_info: plane.flight_info
          })
        else
          socket
        end
      end)

    Process.send_after(self(), :update_planes, @update_interval)

    {:noreply, assign(socket, :planes, updated_planes)}
  end

  defp generate_initial_planes do
    1..@max_planes
    |> Enum.map(fn i ->
      id = "plane_#{i}"
      {lat, lng} = random_coordinates()
      direction = random_direction()
      flight_info = generate_flight_info()

      plane = %{
        lat: lat,
        lng: lng,
        direction: direction,
        flight_info: flight_info,
        speed_kmh: Enum.random(400..900),
        last_update: System.monotonic_time(:millisecond)
      }

      {id, plane}
    end)
    |> Enum.into(%{})
  end

  defp update_plane_positions(planes) do
    current_time = System.monotonic_time(:millisecond)

    planes
    |> Enum.map(fn {id, plane} ->
      time_diff = current_time - plane.last_update

      # Calculate new position based on speed and direction
      new_position =
        calculate_new_position(
          plane.lat,
          plane.lng,
          plane.direction,
          plane.speed_kmh,
          time_diff
        )

      # Sometimes change direction slightly
      new_direction =
        if :rand.uniform() < 0.1 do
          adjust_direction(plane.direction)
        else
          plane.direction
        end

      updated_plane = %{
        plane
        | lat: new_position.lat,
          lng: new_position.lng,
          direction: new_direction,
          last_update: current_time
      }

      {id, updated_plane}
    end)
    |> Enum.into(%{})
  end

  defp maybe_add_new_plane(planes) do
    # Occasionally remove old planes and add new ones
    if map_size(planes) < @max_planes and :rand.uniform() < 0.05 do
      new_id = "plane_#{System.unique_integer([:positive])}"
      {lat, lng} = random_coordinates()
      direction = random_direction()
      flight_info = generate_flight_info()

      new_plane = %{
        lat: lat,
        lng: lng,
        direction: direction,
        flight_info: flight_info,
        speed_kmh: Enum.random(400..900),
        last_update: System.monotonic_time(:millisecond)
      }

      Map.put(planes, new_id, new_plane)
    else
      planes
    end
  end

  defp plane_moved?(old_plane, new_plane) when is_nil(old_plane), do: true

  defp plane_moved?(old_plane, new_plane) do
    lat_diff = abs(old_plane.lat - new_plane.lat)
    lng_diff = abs(old_plane.lng - new_plane.lng)
    dir_diff = abs(old_plane.direction - new_plane.direction)

    # Consider it moved if position changed by more than 0.001 degrees or direction by more than 5 degrees
    lat_diff > 0.001 or lng_diff > 0.001 or dir_diff > 5
  end

  defp calculate_new_position(lat, lng, direction, speed_kmh, time_diff_ms) do
    # Convert time to hours
    time_hours = time_diff_ms / (1000 * 60 * 60)

    # Distance traveled in km
    distance_km = speed_kmh * time_hours

    # Convert to approximate degrees (rough approximation)
    # 1 degree latitude ≈ 111 km
    # 1 degree longitude ≈ 111 km * cos(latitude)
    lat_change = distance_km * :math.cos(direction * :math.pi() / 180) / 111

    lng_change =
      distance_km * :math.sin(direction * :math.pi() / 180) /
        (111 * :math.cos(lat * :math.pi() / 180))

    %{
      lat: lat + lat_change,
      lng: lng + lng_change
    }
  end

  defp adjust_direction(current_direction) do
    # Adjust direction by -30 to +30 degrees
    adjustment = Enum.random(-30..30)
    new_direction = current_direction + adjustment

    cond do
      new_direction < 0 -> new_direction + 360
      new_direction >= 360 -> new_direction - 360
      true -> new_direction
    end
  end

  defp random_coordinates(center_lat \\ 52.1518, center_lng \\ 4.4811, radius \\ 0.3) do
    lat = center_lat + (:rand.uniform() - 0.5) * radius
    lng = center_lng + (:rand.uniform() - 0.5) * radius
    {lat, lng}
  end

  defp random_direction do
    Enum.random(0..359)
  end

  defp generate_flight_info do
    flight_number = "#{Enum.random(1000..9999)}"
    altitude = Enum.random(15000..40000)
    speed = Enum.random(400..600)

    %{
      flightNumber: flight_number,
      altitude: altitude,
      speed: speed
    }
  end
end
