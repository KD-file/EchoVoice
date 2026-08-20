/// Stub used when `dart:io` is unavailable (web). Progress-report export is
/// not supported there; the error is translated to a [LocalStorageException]
/// by [ProgressReportExporter].
String defaultDirectoryPath() => '.';

String pathSeparator() => '/';

Future<void> writeBytes(String path, List<int> bytes) async {
  throw UnsupportedError(
    'Exporting progress reports is not supported on this platform.',
  );
}
