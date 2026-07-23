/**
 * Vercel serverless function to serve the Apple App Site Association file.
 * Reachable at: /.well-known/apple-app-site-association (via vercel.json rewrite)
 *
 * Required for iOS Universal Links so that links like
 * https://app.disciplefy.in/learning-path/:pathId open the app instead of Safari.
 *
 * Served by a function rather than a static file because the SPA rewrite in
 * vercel.json (`/(.*)` -> /index.html) would otherwise return the Flutter
 * index.html for this path. iOS requires JSON and silently disables Universal
 * Links if it receives anything else — which is exactly what was happening.
 *
 * Note: the URL must have NO .json extension and must be served without a
 * redirect. iOS fetches this at install time and caches it.
 */

const TEAM_ID = '4V6VA2U9MW';
const BUNDLE_ID = 'com.disciplefy.biblestudy';
const APP_ID = `${TEAM_ID}.${BUNDLE_ID}`;

// Paths that should open the app. Keep in sync with the Android intent filters
// in android/app/src/main/AndroidManifest.xml.
const DEEP_LINK_PATHS = ['/learning-path/*', '/fellowship/join/*'];

module.exports = (req, res) => {
  const association = {
    applinks: {
      // `details` uses the modern `components` form; `paths` is kept for
      // iOS 12 and earlier, which ignores `components`.
      details: [
        {
          appIDs: [APP_ID],
          components: DEEP_LINK_PATHS.map((path) => ({
            '/': path,
            comment: 'Opens this content directly in the app',
          })),
        },
        {
          appID: APP_ID,
          paths: DEEP_LINK_PATHS,
        },
      ],
    },
  };

  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.status(200).json(association);
};
