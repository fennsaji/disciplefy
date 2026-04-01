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
        sha256_cert_fingerprints: [
          'C0:55:BD:BE:B3:3E:8E:47:17:50:97:C7:88:60:88:DA:CA:11:86:0A:3D:8C:F8:D3:DE:FE:C2:53:E0:3D:2D:BE',
        ],
      },
    },
  ];

  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.status(200).json(assetlinks);
};
