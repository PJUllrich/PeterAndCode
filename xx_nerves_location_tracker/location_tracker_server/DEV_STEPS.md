1. Create LiveView project
2. Add `leaflet` with `npm i leaflet --save`. If errors, make sure to use Node 14.
3. Add `file-loader` with `npm i file-loader --save-dev`
4. Add leaflet-css with `@import "./../node_modules/leaflet/dist/leaflet.css";` in `app.scss`
5. Add `file-loader` to `webpack.config.js` with: 
```js
{
  test: /\.(gif|svg|jpg|png)$/,
  loader: "file-loader",
},
```

6. Reset HTML and Body css with:
```css
html,
body,
.lv-container {
  width: 100%;
  height: 100%;
  margin: 0;
}
```
1. Find Map Tile provider of your liking: https://leaflet-extras.github.io/leaflet-providers/preview/
   

2. Create div with id `map`.
3. Give height, and width to div in `app.scss`
4. Initialize the map with:
```js
import L from "leaflet";

const map = L.map("map").setView([50.93, 6.96], 13);

L.tileLayer("https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png", {
  attribution:
    '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
}).addTo(map);
```

Add a circle to the map with 
```js
L.circle([point.longitude, point.latitude], {
      color: "red",
      fillColor: "#f03",
      fillOpacity: 1,
      radius: 5,
    }).addTo(this.map);
```

## Now, let's set up the LiveView
1. Add a `handle_info` function which accepts `{:add_point, longitude, latitude}`
2. Log the PID, parse it from string to pid, and send messages to it.
3. Subscribe the LiveView to the PubSub with: `Phoenix.PubSub.subscribe(LocationTrackerServer.PubSub, "location_points")`
4. Send a message to it via the PubSub
5. Send a message to it via JavaScript
```js
let socket = new Socket("/socket", {params: {token: "channel_token"}})
socket.connect()

let channel = socket.channel("locations:sending")
channel.join()
    .receive("ok", ({messages}) => console.log("catching up", messages) )
    .receive("error", ({reason}) => console.log("failed join", reason) )
    .receive("timeout", () => console.log("Networking issue. Still waiting..."))

channel.push("add_point", {longitude: 50.96, latitude: 6.97})
```