import 'package:url_launcher/url_launcher.dart';

void openExternalUrl(String url) {
  try {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

void downloadCsvFile(String filename, String content) {
  // Native fallback / no-op
}
