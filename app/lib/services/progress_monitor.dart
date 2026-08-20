import '../utils/exceptions.dart';

/// Monitors and summarizes progress for a series of assessment attempts.
class ProgressMonitor {
  final List<Map<String, Object?>> records;

  ProgressMonitor([List<Map<String, Object?>>? initialRecords])
      : records = initialRecords != null
            ? List<Map<String, Object?>>.from(initialRecords)
            : <Map<String, Object?>>[];

  /// Adds a new progress record.
  ///
  /// Each record must include a numeric 'score' entry.
  void addRecord(Map<String, Object?> record) {
    if (!record.containsKey('score') || record['score'] is! num) {
      throw const ValidationException(
        'Each progress record must include a numeric "score" field.',
      );
    }
    records.add(Map<String, Object?>.from(record));
  }
}
