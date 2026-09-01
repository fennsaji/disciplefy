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
          '24:DE:DC:91:28:77:35:DB:6F:54:FF:B0:83:FA:43:3B:AC:6E:C3:51:EA:51:56:06:72:8A:E8:86:81:FC:BE:69',
        ],
      },
    },
  ];

  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  res.status(200).json(assetlinks);
};
