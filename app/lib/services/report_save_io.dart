import 'dart:io';

/// File-system backend for [ProgressReportExporter] (desktop/mobile).
String defaultDirectoryPath() {
  // Android: try the public Downloads folder first, then fall back to
  // the app's cache directory (always writable, no permission needed).
  if (Platform.isAndroid) {
    final downloads = Directory('/storage/emulated/0/Download');
    if (downloads.existsSync()) return downloads.path;
    return Directory.systemTemp.path;
  }
  // iOS / desktop: use ~/Downloads when available.
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final downloads = Directory('$home${Platform.pathSeparator}Downloads');
    if (downloads.existsSync()) {
      return downloads.path;
    }
  }
  return '${Directory.current.path}${Platform.pathSeparator}exports';
}

String pathSeparator() => Platform.pathSeparator;

Future<void> writeBytes(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}
