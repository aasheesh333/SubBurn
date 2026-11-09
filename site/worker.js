// Static site for the Play Store listing: landing page + privacy policy +
// public CDN fallback files. The assets binding serves ./public.
export default {
  async fetch(request, env) {
    return env.ASSETS.fetch(request);
  },
};
