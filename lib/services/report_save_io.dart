import 'dart:io';

/// File-system backend for [ProgressReportExporter] (desktop/mobile).
String defaultDirectoryPath() {
  final home = Platform.environment['USERPROFILE'];
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
