defmodule Tracker.Aircraft do
  @moduledoc """
  Aircraft data structure and helper functions for ADS-B data processing.
  """

  @derive {Jason.Encoder,
           only: [
             :hex,
             :flight,
             :lat,
             :lon,
             :altitude,
             :ground_speed,
             :track,
             :vertical_rate,
             :squawk,
             :emergency,
             :category,
             :last_seen,
             :distance,
             :bearing
           ]}
  defstruct [
    :hex,
    :flight,
    :lat,
    :lon,
    :altitude,
    :ground_speed,
    :track,
    :vertical_rate,
    :squawk,
    :emergency,
    :category,
    :nav_qnh,
    :nav_altitude_mcp,
    :nav_heading,
    :nic,
    :rc,
    :seen_pos,
    :seen,
    :rssi,
    :messages,
    :last_seen,
    :distance,
    :bearing
  ]

  @type t :: %__MODULE__{
          hex: String.t() | nil,
          flight: String.t() | nil,
          lat: float() | nil,
          lon: float() | nil,
          altitude: integer() | nil,
          ground_speed: float() | nil,
          track: float() | nil,
          vertical_rate: integer() | nil,
          squawk: String.t() | nil,
          emergency: String.t() | nil,
          category: String.t() | nil,
          nav_qnh: float() | nil,
          nav_altitude_mcp: integer() | nil,
          nav_heading: float() | nil,
          nic: integer() | nil,
          rc: integer() | nil,
          seen_pos: float() | nil,
          seen: float() | nil,
          rssi: float() | nil,
          messages: integer() | nil,
          last_seen: integer() | nil,
          distance: float() | nil,
          bearing: float() | nil
        }

  @doc """
  Creates a new Aircraft struct from parsed ADS-B data.
  """
  def new(data) when is_map(data) do
    %__MODULE__{
      hex: Map.get(data, "hex"),
      flight: clean_flight(Map.get(data, "flight")),
      lat: Map.get(data, "lat"),
      lon: Map.get(data, "lon"),
      altitude: Map.get(data, "altitude"),
      ground_speed: Map.get(data, "gs"),
      track: Map.get(data, "track"),
      vertical_rate: Map.get(data, "baro_rate"),
      squawk: Map.get(data, "squawk"),
      emergency: Map.get(data, "emergency"),
      category: Map.get(data, "category"),
      nav_qnh: Map.get(data, "nav_qnh"),
      nav_altitude_mcp: Map.get(data, "nav_altitude_mcp"),
      nav_heading: Map.get(data, "nav_heading"),
      nic: Map.get(data, "nic"),
      rc: Map.get(data, "rc"),
      seen_pos: Map.get(data, "seen_pos"),
      seen: Map.get(data, "seen"),
      rssi: Map.get(data, "rssi"),
      messages: Map.get(data, "messages"),
      last_seen: :os.system_time(:second)
    }
  end

  @doc """
  Updates an existing Aircraft struct with new data, preserving existing values
  when new data is nil.
  """
  def update(%__MODULE__{} = aircraft, data) when is_map(data) do
    %__MODULE__{
      aircraft
      | # hex should never change
        hex: aircraft.hex,
        flight: clean_flight(Map.get(data, "flight")) || aircraft.flight,
        lat: Map.get(data, "lat") || aircraft.lat,
        lon: Map.get(data, "lon") || aircraft.lon,
        altitude: Map.get(data, "altitude") || aircraft.altitude,
        ground_speed: Map.get(data, "gs") || aircraft.ground_speed,
        track: Map.get(data, "track") || aircraft.track,
        vertical_rate: Map.get(data, "baro_rate") || aircraft.vertical_rate,
        squawk: Map.get(data, "squawk") || aircraft.squawk,
        emergency: Map.get(data, "emergency") || aircraft.emergency,
        category: Map.get(data, "category") || aircraft.category,
        nav_qnh: Map.get(data, "nav_qnh") || aircraft.nav_qnh,
        nav_altitude_mcp: Map.get(data, "nav_altitude_mcp") || aircraft.nav_altitude_mcp,
        nav_heading: Map.get(data, "nav_heading") || aircraft.nav_heading,
        nic: Map.get(data, "nic") || aircraft.nic,
        rc: Map.get(data, "rc") || aircraft.rc,
        seen_pos: Map.get(data, "seen_pos") || aircraft.seen_pos,
        seen: Map.get(data, "seen") || aircraft.seen,
        rssi: Map.get(data, "rssi") || aircraft.rssi,
        messages: Map.get(data, "messages") || aircraft.messages,
        last_seen: :os.system_time(:second)
    }
  end

  @doc """
  Checks if the aircraft has valid position data (lat/lon).
  """
  def has_position?(%__MODULE__{lat: lat, lon: lon}) do
    is_number(lat) and is_number(lon)
  end

  @doc """
  Checks if the aircraft data is considered fresh based on last_seen timestamp.
  Aircraft data older than the specified seconds is considered stale.
  """
  def is_fresh?(%__MODULE__{last_seen: last_seen}, max_age_seconds \\ 30) do
    current_time = :os.system_time(:second)
    current_time - last_seen <= max_age_seconds
  end

  @doc """
  Calculates distance and bearing from a reference point to the aircraft.
  Returns updated aircraft struct with distance and bearing fields populated.
  """
  def calculate_distance_and_bearing(%__MODULE__{} = aircraft, ref_lat, ref_lon)
      when is_number(ref_lat) and is_number(ref_lon) do
    case {aircraft.lat, aircraft.lon} do
      {lat, lon} when is_number(lat) and is_number(lon) ->
        distance = haversine_distance(ref_lat, ref_lon, lat, lon)
        bearing = calculate_bearing(ref_lat, ref_lon, lat, lon)
        %{aircraft | distance: distance, bearing: bearing}

      _ ->
        aircraft
    end
  end

  def calculate_distance_and_bearing(%__MODULE__{} = aircraft, _ref_lat, _ref_lon) do
    aircraft
  end

  @doc """
  Returns a human-readable category description for the aircraft category code.
  """
  def category_description(nil), do: "Unknown"
  def category_description("A0"), do: "No ADS-B Emitter Category Information"
  def category_description("A1"), do: "Light (< 15500 lbs)"
  def category_description("A2"), do: "Small (15500 to 75000 lbs)"
  def category_description("A3"), do: "Large (75000 to 300000 lbs)"
  def category_description("A4"), do: "High Vortex Large (aircraft such as B-757)"
  def category_description("A5"), do: "Heavy (> 300000 lbs)"
  def category_description("A6"), do: "High Performance (> 5g acceleration and 400 kts)"
  def category_description("A7"), do: "Rotorcraft"
  def category_description("B0"), do: "No ADS-B Emitter Category Information"
  def category_description("B1"), do: "Glider / sailplane"
  def category_description("B2"), do: "Lighter-than-air"
  def category_description("B3"), do: "Parachutist / Skydiver"
  def category_description("B4"), do: "Ultralight / hang-glider / paraglider"
  def category_description("B5"), do: "Reserved"
  def category_description("B6"), do: "Unmanned Aerial Vehicle"
  def category_description("B7"), do: "Space / Trans-atmospheric vehicle"
  def category_description("C0"), do: "No ADS-B Emitter Category Information"
  def category_description("C1"), do: "Surface Vehicle – Emergency Vehicle"
  def category_description("C2"), do: "Surface Vehicle – Service Vehicle"
  def category_description("C3"), do: "Point Obstacle (includes tethered balloons)"
  def category_description("C4"), do: "Cluster Obstacle"
  def category_description("C5"), do: "Line Obstacle"
  def category_description("C6"), do: "Reserved"
  def category_description("C7"), do: "Reserved"
  def category_description(_), do: "Unknown Category"

  # Private helper functions

  defp clean_flight(nil), do: nil

  defp clean_flight(flight) when is_binary(flight) do
    flight
    |> String.trim()
    |> case do
      "" -> nil
      cleaned -> cleaned
    end
  end

  # Haversine formula for calculating distance between two points on Earth
  defp haversine_distance(lat1, lon1, lat2, lon2) do
    # Convert degrees to radians
    lat1_rad = deg_to_rad(lat1)
    lon1_rad = deg_to_rad(lon1)
    lat2_rad = deg_to_rad(lat2)
    lon2_rad = deg_to_rad(lon2)

    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a =
      :math.pow(:math.sin(dlat / 2), 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) * :math.pow(:math.sin(dlon / 2), 2)

    c = 2 * :math.asin(:math.sqrt(a))

    # Earth's radius in kilometers
    earth_radius = 6371.0
    earth_radius * c
  end

  # Calculate bearing from point 1 to point 2
  defp calculate_bearing(lat1, lon1, lat2, lon2) do
    lat1_rad = deg_to_rad(lat1)
    lat2_rad = deg_to_rad(lat2)
    dlon_rad = deg_to_rad(lon2 - lon1)

    y = :math.sin(dlon_rad) * :math.cos(lat2_rad)

    x =
      :math.cos(lat1_rad) * :math.sin(lat2_rad) -
        :math.sin(lat1_rad) * :math.cos(lat2_rad) * :math.cos(dlon_rad)

    bearing_rad = :math.atan2(y, x)
    bearing_deg = rad_to_deg(bearing_rad)

    # Normalize to 0-360 degrees
    case bearing_deg do
      b when b < 0 -> b + 360
      b -> b
    end
  end

  defp deg_to_rad(deg), do: deg * :math.pi() / 180
  defp rad_to_deg(rad), do: rad * 180 / :math.pi()
end
