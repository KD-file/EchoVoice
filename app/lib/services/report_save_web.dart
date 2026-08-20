import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web backend for [ProgressReportExporter]: instead of writing to a
/// filesystem (which does not exist in the browser), the PDF bytes are
/// pushed through a Blob URL and the browser downloads the file to the
/// user's Downloads folder.
String defaultDirectoryPath() => 'EchoVoice';

String pathSeparator() => '/';

Future<void> writeBytes(String path, List<int> bytes) async {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob(
    [data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = path.split('/').last;
  anchor.click();
  web.URL.revokeObjectURL(url);
  await Future<void>.delayed(Duration.zero);
}
