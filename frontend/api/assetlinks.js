/**
 * Vercel serverless function to serve Android Digital Asset Links.
 * Reachable at: /.well-known/assetlinks.json (via vercel.json rewrite)
 *
 * Required for Android App Links verification so that deep links like
 * https://app.disciplefy.in/fellowship/join/:token open the app instead
 * of the browser.
 */
module.exports = (req, res) => {
  const assetlinks = [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: 'com.disciplefy.bible_study',
        // Both certificates must be listed.
        //
        // Play App Signing re-signs the app with the app signing key, so that
        // is the certificate on the build users install. Builds signed with the
        // upload key directly (internal app sharing, locally built release
        // APKs) present a different certificate and fail verification unless it
        // is listed too — App Links then silently open in the browser.
        sha256_cert_fingerprints: [
          // Play app signing key
          '24:DE:DC:91:28:77:35:DB:6F:54:FF:B0:83:FA:43:3B:AC:6E:C3:51:EA:51:56:06:72:8A:E8:86:81:FC:BE:69',
          // Upload key (android/app/upload-keystore.jks)
          '24:74:AC:DD:4F:B4:1D:2C:E1:A4:0E:2C:63:DE:00:0D:49:77:83:57:BF:A8:CE:E7:CE:78:2D:C9:24:DF:03:2F',
        ],
      },
    },
  ];

  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.status(200).json(assetlinks);
};
