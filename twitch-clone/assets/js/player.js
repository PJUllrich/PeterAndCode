import { VidstackPlayer, VidstackPlayerLayout } from "vidstack/global/player";

export default {
  async mounted() {
    const src = this.el.dataset.source;
    const player = await VidstackPlayer.create({
      target: this.el,
      src: src,
      viewType: "video",
      streamType: "live",
      liveEdgeTolerance: 10,
      load: "eager",
      logLevel: "warn",
      crossOrigin: true,
      playsInline: true,
      layout: new VidstackPlayerLayout(),
    });

    // player.seekToLiveEdge();
  },
};
