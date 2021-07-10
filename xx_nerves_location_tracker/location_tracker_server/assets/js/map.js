import L, { point } from "leaflet";

export default {
  initMap() {
    this.map = L.map("map").setView([50.93, 6.96], 13);

    L.tileLayer(
      "https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png",
      {
        attribution:
          '&copy; <a href="https://stadiamaps.com/">Stadia Maps</a>, &copy; <a href="https://openmaptiles.org/">OpenMapTiles</a> &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors',
      }
    ).addTo(this.map);
  },
  addPoints(points) {
    points.forEach((point) => {
      L.circle([point.latitude, point.longitude], {
        color: "red",
        fillColor: "#f03",
        fillOpacity: 1,
        radius: 5,
      }).addTo(this.map);
    });
  },
  mounted() {
    this.initMap();
    this.handleEvent("add_points", ({ points }) => {
      this.addPoints(points);
    });
  },
};
