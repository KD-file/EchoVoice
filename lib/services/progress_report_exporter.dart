import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/category.dart';
import '../models/phoneme_target.dart';
import '../state/session_state.dart';
import '../utils/exceptions.dart';
import 'report_save_stub.dart'
    if (dart.library.io) 'report_save_io.dart'
    if (dart.library.js_interop) 'report_save_web.dart' as report_save;

/// Module 5.0 — Monitor Progress: exports a printable PDF report from the
/// current [SessionState] (learner snapshot + per-category accuracy + full
/// attempt records) so caregivers and SLPs can share progress with the
/// clinic. Mirrors the summary shown on the Progress tab.
///
/// The report is written to the user's Downloads folder (falling back to an
/// `exports/` folder under the working directory when Downloads is not
/// available), and the absolute path of the saved file is returned so the
/// UI can reveal it to the user.
class ProgressReportExporter {
  /// Palette lifted from the app theme (AppColors) so the report matches the
  /// on-screen design.
  static const PdfColor _teal = PdfColor.fromInt(0xFF1F8A70);
  static const PdfColor _tealDark = PdfColor.fromInt(0xFF0E5C48);
  static const PdfColor _tealLight = PdfColor.fromInt(0xFFDFF4EE);
  static const PdfColor _ink = PdfColor.fromInt(0xFF2B3A3A);
  static const PdfColor _inkSoft = PdfColor.fromInt(0xFF5B6B6A);
  static const PdfColor _amber = PdfColor.fromInt(0xFFFFC857);
  static const PdfColor _ok = PdfColor.fromInt(0xFF2E9E6B);
  static const PdfColor _warn = PdfColor.fromInt(0xFFF29E4C);
  static const PdfColor _miss = PdfColor.fromInt(0xFFF0595A);

  /// IPA symbols the default PDF fonts cannot render, mapped to readable
  /// English spellings so the report stays legible in any PDF viewer.
  static const Map<String, String> _ipaReadable = {
    'θ': 'th',
    'ð': 'dh',
    'ʃ': 'sh',
    'ʒ': 'zh',
    'tʃ': 'ch',
    'dʒ': 'j',
    'ŋ': 'ng',
    'æ': 'a',
    'ɪ': 'i',
    'ʌ': 'u',
    'ɑ': 'a',
    'ɔ': 'o',
    'ʊ': 'u',
  };

  /// Builds and saves the PDF report, returning the absolute file path.
  ///
  /// Throws [LocalStorageException] when the document cannot be written
  /// (including on platforms without a file system, such as the web).
  static Future<String> exportToPdf(
    SessionState session, {
    String? directory,
  }) async {
    if (!session.isOnboarded) {
      throw const ValidationException(
        'Cannot export a progress report before the learner profile is set.',
      );
    }

    final dir = directory ?? report_save.defaultDirectoryPath();
    final filePath = '$dir${report_save.pathSeparator()}${_fileName(session)}';
    try {
      final bytes = await buildDocument(session).save();
      await report_save.writeBytes(filePath, bytes);
      return filePath;
    } on Object catch (e) {
      throw LocalStorageException(
        'Failed to export the progress report to "$filePath".',
        cause: e,
      );
    }
  }

  /// Builds the [pw.Document] from the session. Kept public so tests can
  /// verify the report structure without touching the file system.
  static pw.Document buildDocument(SessionState session) {
    final document = pw.Document(title: 'EchoVoice Progress Report');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          _header(session),
          pw.SizedBox(height: 12),
          _learnerCard(session),
          pw.SizedBox(height: 14),
          _summarySection(session),
          pw.SizedBox(height: 14),
          _categoriesSection(session),
          pw.SizedBox(height: 14),
          _recordsSection(session),
          pw.SizedBox(height: 14),
          _footer(),
        ],
      ),
    );
    return document;
  }

  static String _fileName(SessionState session) {
    final safeName = (session.name ?? 'learner')
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final stamp = _timestamp(DateTime.now());
    return 'EchoVoice_Progress_${safeName}_$stamp.pdf';
  }

  static String _timestamp(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  static String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _readable(String symbol) => _ipaReadable[symbol] ?? symbol;

  static pw.Widget _header(SessionState session) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _teal,
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EchoVoice Progress Report',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Phoneme-level pronunciation practice',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'Generated ${_formatDate(DateTime.now())}',
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _learnerCard(SessionState session) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _tealLight,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Learner: ${session.name ?? '-'}',
            style: const pw.TextStyle(
              color: _tealDark,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Age ${session.age ?? '-'}  |  '
            'Role: ${session.role.label}',
            style: const pw.TextStyle(color: _inkSoft, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summarySection(SessionState session) {
    final average = session.averageAccuracy;
    final averageColor = average == null
        ? _inkSoft
        : average >= 0.9
            ? _ok
            : average >= 0.7
                ? _warn
                : _miss;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Summary'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _statBox(
              'Overall accuracy',
              average == null ? '--' : '${(average * 100).round()}%',
              valueColor: averageColor,
            ),
            pw.SizedBox(width: 8),
            _statBox('Attempts', '${session.records.length}'),
            pw.SizedBox(width: 8),
            _statBox('Stars', '${session.totalStars}', valueColor: _amber),
            pw.SizedBox(width: 8),
            _statBox('Streak', '${session.streak}'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Words practiced: ${session.practicedWords} of '
          '${session.categories.fold<int>(0, (sum, c) => sum + c.words.length)}',
          style: const pw.TextStyle(color: _ink, fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _statBox(
    String label,
    String value, {
    PdfColor valueColor = _tealDark,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: _tealLight, width: 1.2),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(color: _inkSoft, fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _categoriesSection(SessionState session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Accuracy by sound family'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Sound family', 'Practiced', 'Stars', 'Accuracy'],
          data: [
            for (final category in session.categories)
              _categoryRow(session, category),
          ],
          headerStyle: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: _teal),
          cellStyle: const pw.TextStyle(color: _ink, fontSize: 9.5),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          rowDecoration: const pw.BoxDecoration(
            color: PdfColors.white,
          ),
          oddRowDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF3FAF7),
          ),
        ),
        pw.SizedBox(height: 6),
        _assignedRow(session),
      ],
    );
  }

  static List<String> _categoryRow(SessionState session, SoundCategory c) {
    final accuracy = session.accuracyForCategory(c.id);
    return [
      c.name,
      '${session.practicedWordCount(c.id)}/${c.words.length}',
      '${session.starsForCategory(c.id)}',
      accuracy == null ? '--' : '${(accuracy * 100).round()}%',
    ];
  }

  static pw.Widget _assignedRow(SessionState session) {
    final assigned = [
      for (final category in session.categories)
        if (session.isAssigned(category.id)) category,
    ];
    if (assigned.isEmpty) {
      return pw.Text(
        'Assigned practice: none',
        style: const pw.TextStyle(color: _inkSoft, fontSize: 9.5),
      );
    }
    return pw.Text(
      'Assigned practice: ${assigned.map((c) => c.name).join(', ')}',
      style: const pw.TextStyle(color: _inkSoft, fontSize: 9.5),
    );
  }

  static pw.Widget _recordsSection(SessionState session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Attempt records'),
        pw.SizedBox(height: 8),
        if (session.records.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _tealLight,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              'No attempts recorded yet.',
              style: const pw.TextStyle(color: _inkSoft, fontSize: 10),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Date', 'Word', 'You said', 'Accuracy'],
            data: [
              for (var i = 0; i < session.records.length; i++)
                _recordRow(session.records[i], i + 1),
            ],
            headerStyle: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: _teal),
            cellStyle: const pw.TextStyle(color: _ink, fontSize: 9.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.6),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(2.4),
              4: const pw.FlexColumnWidth(1),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
            },
          ),
      ],
    );
  }

  static List<String> _recordRow(AssessmentRecord record, int index) {
    final accuracy = record.accuracyScore;
    final accuracyLabel = '${(accuracy * 100).round()}%';
    final said = record.predictedPhonemes.map(_readable).join(' ').trim();
    return [
      '$index',
      _formatDate(record.recordedAt),
      record.exerciseId,
      said.isEmpty ? '(nothing heard)' : said,
      accuracyLabel,
    ];
  }

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _tealLight)),
      ),
      child: pw.Text(
        'Thank you for practicing with EchoVoice!  |  '
        'Growth Journey Learning Center Inc.',
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(color: _inkSoft, fontSize: 9),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: const pw.TextStyle(
        color: _ink,
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }
}
