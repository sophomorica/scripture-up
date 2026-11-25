import 'package:url_launcher/url_launcher.dart';

/// The About strip's Seminary Sidekick link, on the hub link scheme
/// (standards/LINKS.md §1): source `scripture-up`, medium `promo-strip`,
/// campaign `ecosystem-strip`, content = the destination product.
final Uri sidekickPromoUri = Uri.https('seminarysidekick.com', '/', const {
  'utm_source': 'scripture-up',
  'utm_medium': 'promo-strip',
  'utm_campaign': 'ecosystem-strip',
  'utm_content': 'sidekick',
});

/// Opens [uri] in the browser, outside the app. Returns false when the
/// phone cannot open it; the strip then does nothing.
Future<bool> openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
