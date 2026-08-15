import 'package:sqflite/sqflite.dart';

import '../models/phoneme_target.dart';
import '../utils/exceptions.dart';

/// Wraps the on-device SQLite database (D1 Progress Database in the
/// study's Data Flow Diagram / ERD). All access to the database goes
/// through this class so that query construction, error handling, and
/// resource cleanup are centralized in one place rather than repeated
/// (and potentially done inconsistently) throughout the app.
class DatabaseHelper {
  static const String _dbName = 'echovoice_progress.db';
  static const int _dbVersion = 1;

  Database? _db;

  /// Opens (or creates) the local database. Safe to call multiple times;
  /// subsequent calls reuse the already-open connection.
  Future<Database> get database async {
    if (_db != null) return _db!;
    try {
      _db = await openDatabase(
        _dbName,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE assessment_records (
              attempt_id TEXT PRIMARY KEY,
              exercise_id TEXT NOT NULL,
              recorded_at TEXT NOT NULL,
              predicted_phonemes TEXT NOT NULL,
              accuracy_score REAL NOT NULL,
              phoneme_error_rate REAL NOT NULL
            )
          ''');
        },
      );
      return _db!;
    } on Exception catch (e) {
      // Translate the low-level plugin exception into an EchoVoice-specific
      // type so callers elsewhere in the app only need to know about
      // EchoVoiceException subtypes, not sqflite's internal exception types.
      throw LocalStorageException(
        'Failed to open local database "$_dbName".',
        cause: e,
      );
    }
  }

  /// Persists an [AssessmentRecord]. Uses parameterized query arguments
  /// (never raw string interpolation into SQL) so that user- or
  /// model-derived values can never be interpreted as SQL — this is the
  /// standard defense against SQL injection, even though the values here
  /// originate on-device rather than from an external network request.
  Future<void> saveAssessmentRecord(AssessmentRecord record) async {
    final db = await database;
    try {
      await db.insert(
        'assessment_records',
        {
          'attempt_id': record.attemptId,
          'exercise_id': record.exerciseId,
          'recorded_at': record.recordedAt.toIso8601String(),
          'predicted_phonemes': record.predictedPhonemes.join(','),
          'accuracy_score': record.accuracyScore,
          'phoneme_error_rate': record.phonemeErrorRate,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Exception catch (e) {
      throw LocalStorageException(
        'Failed to save AssessmentRecord "${record.attemptId}".',
        cause: e,
      );
    }
  }

  /// Retrieves all assessment records for a given exercise, most recent
  /// first. Returns an empty list (never null) when there are no records,
  /// so callers can iterate the result without a null check.
  Future<List<Map<String, Object?>>> getRecordsForExercise(
    String exerciseId,
  ) async {
    if (exerciseId.trim().isEmpty) {
      throw const ValidationException(
        'exerciseId must not be empty when querying records.',
      );
    }
    final db = await database;
    try {
      return await db.query(
        'assessment_records',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId], // parameterized, not string-concatenated
        orderBy: 'recorded_at DESC',
      );
    } on Exception catch (e) {
      throw LocalStorageException(
        'Failed to read records for exercise "$exerciseId".',
        cause: e,
      );
    }
  }

  /// Closes the database connection and releases the resource. Should be
  /// called when the app is disposed to avoid leaking file handles.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
