export default {
  async fetch(request, env) {
    // Serve static admin Vite build
    return env.ASSETS.fetch(request);
  }
}
