import 'package:url_launcher/url_launcher.dart';

class AppLinks {
  static final support = Uri.https(
    'mstreezy-prog.github.io',
    '/the-worship-focus/',
  );
  static final privacy = Uri.https(
    'mstreezy-prog.github.io',
    '/the-worship-focus/privacy.html',
  );

  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
