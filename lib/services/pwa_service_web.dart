// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

class PwaService {
  static final StreamController<bool> _controller = StreamController<bool>.broadcast();
  static bool _initialized = false;

  static bool get isPwaSupported => true;

  static bool get isStandalone {
    try {
      final mq = html.window.matchMedia('(display-mode: standalone)');
      return mq.matches;
    } catch (_) {
      return false;
    }
  }

  static void init() {
    if (_initialized) return;
    _initialized = true;

    html.window.addEventListener('pwa-installable', (_) {
      _controller.add(true);
    });
    html.window.addEventListener('pwa-installed', (_) {
      _controller.add(false);
    });
  }

  static Stream<bool> get installableStream {
    init();
    return _controller.stream;
  }

  static bool get canInstallNow {
    try {
      if (isStandalone) return false;
      return js.context.hasProperty('_canInstallPwa') &&
          js.context['_canInstallPwa'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> promptInstall() async {
    try {
      if (js.context.hasProperty('installPadCarePwa')) {
        final result = await js.context.callMethod('installPadCarePwa');
        return result == true;
      }
    } catch (_) {}
    return false;
  }
}
