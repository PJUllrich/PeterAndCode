// Map initialization and plane management module
let map = null;
let planeMarkers = [];
let planesById = new Map(); // Track planes by ID

// Wait for Leaflet to be available
function waitForLeaflet() {
  return new Promise((resolve) => {
    if (window.L) {
      resolve();
      return;
    }

    const checkL = () => {
      if (window.L) {
        resolve();
      } else {
        setTimeout(checkL, 50);
      }
    };
    checkL();
  });
}

// Plane icon HTML template with proper SVG airplane
function createPlaneIcon(rotation = 0) {
  const svgIcon = `
    <svg width="48" height="48" viewBox="0 0 24 24" style="transform: rotate(${rotation}deg);">
      <defs>
        <linearGradient id="planeGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:#3b82f6"/>
          <stop offset="50%" style="stop-color:#2563eb"/>
          <stop offset="100%" style="stop-color:#1e40af"/>
        </linearGradient>
      </defs>
      <!-- Plane fuselage -->
      <ellipse cx="12" cy="12" rx="1.5" ry="8" fill="url(#planeGradient)" stroke="#1e40af" stroke-width="0.3"/>
      <!-- Main wings -->
      <ellipse cx="12" cy="10" rx="7" ry="1.5" fill="url(#planeGradient)" stroke="#1e40af" stroke-width="0.3"/>
      <!-- Tail wings -->
      <ellipse cx="12" cy="16" rx="3" ry="1" fill="url(#planeGradient)" stroke="#1e40af" stroke-width="0.3"/>
      <!-- Cockpit -->
      <ellipse cx="12" cy="6" rx="1" ry="2" fill="#1e40af"/>
      <!-- Navigation lights -->
      <circle cx="5" cy="10" r="0.5" fill="#ef4444"/>
      <circle cx="19" cy="10" r="0.5" fill="#22c55e"/>
    </svg>
  `;

  return window.L.divIcon({
    html: svgIcon,
    className: "plane-marker",
    iconSize: [48, 48],
    iconAnchor: [24, 24],
  });
}

// Add or update a plane on the map by ID
function addOrUpdatePlane(id, lat, lng, direction, planeData) {
  // Check if plane already exists
  if (planesById.has(id)) {
    return updatePlaneLocation(id, lat, lng, direction, planeData);
  }

  // Create new plane
  const flightInfo = planeData;
  const planeIcon = createPlaneIcon(direction);
  const marker = window.L.marker([lat, lng], { icon: planeIcon });

  // Add tooltip with flight information
  const tooltipContent = `
    <div class="plane-tooltip">
      <strong>${flightInfo.flightNumber || id}</strong><br>
      ${flightInfo.origin || "Unknown"} → ${flightInfo.destination || "Unknown"}<br>
      Alt: ${(flightInfo.altitude || 0).toLocaleString()}ft<br>
      Speed: ${flightInfo.speed || 0} kts
    </div>
  `;

  marker.bindTooltip(tooltipContent, {
    permanent: false,
    direction: "top",
    offset: [0, -10],
    className: "custom-tooltip",
  });

  marker.addTo(map);
  planeMarkers.push(marker);

  // Store flight info, direction, and ID on marker
  marker.flightInfo = flightInfo;
  marker.direction = direction;
  marker.planeId = id;

  // Track in our ID map
  planesById.set(id, marker);

  return marker;
}

// Update existing plane location and data
function updatePlaneLocation(id, lat, lng, direction, planeData) {
  const marker = planesById.get(id);
  if (!marker) {
    console.warn(`Plane with ID ${id} not found`);
    return null;
  }

  // Update position
  marker.setLatLng([lat, lng]);

  // Update direction if changed
  if (direction !== undefined && direction !== marker.direction) {
    marker.direction = direction;
    const newIcon = createPlaneIcon(direction);
    marker.setIcon(newIcon);
  }

  // Update flight data if provided
  marker.flightInfo = { ...marker.flightInfo, ...planeData };

  // Update tooltip
  const tooltipContent = `
      <div class="plane-tooltip">
        <strong>${marker.flightInfo.flightNumber || id}</strong><br>
        Alt: ${(marker.flightInfo.altitude || 0).toLocaleString()}ft<br>
        Speed: ${marker.flightInfo.speed || 0} kts
      </div>
    `;
  marker.setTooltipContent(tooltipContent);

  return marker;
}

// Remove a plane by ID
function removePlane(id) {
  const marker = planesById.get(id);
  if (marker) {
    map.removeLayer(marker);
    const index = planeMarkers.indexOf(marker);
    if (index > -1) {
      planeMarkers.splice(index, 1);
    }
    planesById.delete(id);
    return true;
  }
  return false;
}

// Get plane by ID
function getPlane(id) {
  return planesById.get(id);
}

// Get all plane IDs
function getAllPlaneIds() {
  return Array.from(planesById.keys());
}

// Legacy function - now uses ID-based system
function addPlaneMarker(lat, lng, direction) {
  const id = `plane_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  return addOrUpdatePlane(id, lat, lng, direction);
}

// Add multiple random planes with unique IDs
function addRandomPlanes(count = 10) {
  for (let i = 0; i < count; i++) {
    const [lat, lng] = getRandomCoordinates();
    const direction = getRandomDirection();
    const id = `random_plane_${i + 1}`;
    addOrUpdatePlane(id, lat, lng, direction);
  }
}

// Clear all plane markers
function clearPlanes() {
  planeMarkers.forEach((marker) => {
    map.removeLayer(marker);
  });
  planeMarkers = [];
  planesById.clear();
}

// Initialize the map
async function initializeMap() {
  const mapElement = document.getElementById("map");
  if (!mapElement) {
    console.error("Map element not found");
    return;
  }

  // Wait for Leaflet to be available
  await waitForLeaflet();

  // Initialize Leaflet map centered on Leiden, The Netherlands
  map = window.L.map("map").setView([52.1518, 4.4811], 12);

  // Add OpenStreetMap tiles
  window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map);

  console.log("Map initialized, ready for planes");
}

// Note: Map initialization is now handled by the LiveView hook
// This ensures proper coordination between LiveView and the map

// Export functions for global access
window.PlaneMap = {
  initialize: initializeMap,
  addPlane: addPlaneMarker, // Legacy function
  addOrUpdatePlane: addOrUpdatePlane, // New ID-based function
  updatePlane: updatePlaneLocation,
  removePlane: removePlane,
  getPlane: getPlane,
  getAllPlaneIds: getAllPlaneIds,
  clearPlanes: clearPlanes,
};
