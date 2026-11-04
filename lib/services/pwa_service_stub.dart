// Native fallback for PWA operations
class PwaService {
  static bool get isPwaSupported => false;
  static bool get isStandalone => true;
  static bool get canInstallNow => false;
  static Stream<bool> get installableStream => Stream.value(false);

  static Future<bool> promptInstall() async => false;
}
