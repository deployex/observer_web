// Ticks down to the timestamp in data-expires (ISO 8601), purely client-side so it doesn't need
// a server round-trip every second. The server re-renders data-expires whenever a new session
// starts, which this hook picks up via updated().
const Countdown = {
  mounted() {
    this.tick();
    this.timer = setInterval(() => this.tick(), 1000);
  },

  updated() {
    this.tick();
  },

  destroyed() {
    clearInterval(this.timer);
  },

  tick() {
    const expiresAt = new Date(this.el.dataset.expires).getTime();
    const remainingMs = expiresAt - Date.now();
    const remainingSeconds = Math.max(0, Math.ceil(remainingMs / 1000));

    this.el.textContent = `${remainingSeconds}s`;
  },
};

export default Countdown;
