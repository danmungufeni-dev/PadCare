import 'dart:io';

void main() async {
  final buildDir = Directory('build/web');
  if (!await buildDir.exists()) {
    stderr.writeln('build/web directory not found. Please run flutter build web first.');
    exit(1);
  }

  // Ensure apk is available in web dir if present in apk_output
  final apkSource = File('apk_output/app-release.apk');
  final apkTarget = File('${buildDir.path}/padcare.apk');
  if (await apkSource.exists() && (!await apkTarget.exists() || (await apkTarget.length() == 0))) {
    try {
      await apkSource.copy(apkTarget.path);
      stdout.writeln('Copied padcare.apk into build/web for direct downloads');
    } catch (_) {}
  }

  Future<void> handleRequest(HttpRequest request) async {
    try {
      var reqPath = request.uri.path;
      if (reqPath.startsWith('/PadCare')) {
        reqPath = reqPath.substring('/PadCare'.length);
      }
      if (reqPath.isEmpty || reqPath == '/') {
        reqPath = '/index.html';
      }

      reqPath = Uri.decodeComponent(reqPath);
      if (reqPath.contains('..')) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
        return;
      }

      var file = File('${buildDir.path}$reqPath');
      if (!await file.exists()) {
        file = File('${buildDir.path}/index.html');
      }

      final ext = file.path.split('.').last.toLowerCase();
      final mime = _mimeTypes[ext] ?? 'application/octet-stream';

      request.response
        ..headers.set('Content-Type', mime)
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..headers.set('Cache-Control', 'no-cache');

      if (ext == 'apk') {
        request.response.headers.set('Content-Disposition', 'attachment; filename="padcare.apk"');
      }

      await request.response.addStream(file.openRead());
      await request.response.close();
    } catch (e) {
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Error: $e')
          ..close();
      } catch (_) {}
    }
  }

  // Bind to 5000 and 8080 so both ports work interchangeably
  final ports = [5000, 8080];
  for (final port in ports) {
    try {
      final s = await HttpServer.bind(InternetAddress.anyIPv4, port);
      stdout.writeln('PadCare Web Server live at http://localhost:$port');
      s.listen(handleRequest);
    } catch (e) {
      stderr.writeln('Could not bind port $port: $e');
    }
  }
}

const _mimeTypes = {
  'apk': 'application/vnd.android.package-archive',
  'html': 'text/html; charset=utf-8',
  'js': 'application/javascript; charset=utf-8',
  'mjs': 'application/javascript; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'wasm': 'application/wasm',
  'otf': 'font/otf',
  'ttf': 'font/ttf',
  'woff': 'font/woff',
  'woff2': 'font/woff2',
};
