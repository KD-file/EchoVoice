import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:echovoice/models/phoneme_target.dart';
import 'package:echovoice/services/asr_pipeline.dart';
import 'package:echovoice/utils/exceptions.dart';

/// Builds 16-bit little-endian PCM for a 440 Hz tone at 0.5 amplitude,
/// using numpy-compatible quantization (truncate `sample * 32767`, clip).
/// Matches `_write_wav` in `backend/tests/test_features.py`.
Uint8List _pcmTone440Hz({int fs = 16000, double seconds = 1.0}) {
  final n = (fs * seconds).round();
  final pcm = Uint8List(n * 2);
  final data = ByteData.view(pcm.buffer);
  for (var i = 0; i < n; i++) {
    final t = i / fs;
    var v = (0.5 * math.sin(2 * math.pi * 440 * t) * 32767).toInt();
    if (v < -32768) v = -32768;
    if (v > 32767) v = 32767;
    data.setInt16(i * 2, v, Endian.little);
  }
  return pcm;
}

void main() {
  group('AcousticFeatureExtractor', () {
    final extractor = AcousticFeatureExtractor();

    test('throws AudioCaptureException on empty audio buffer', () {
      expect(
        () => extractor.extractMelSpectrogram(
          Uint8List(0),
          sampleRateHz: 16000,
        ),
        throwsA(isA<AudioCaptureException>()),
      );
    });

    test('throws ArgumentError on unsupported sample rate', () {
      final fakeAudio = Uint8List(16000 * 2); // ~1s at 16kHz, 16-bit
      expect(
        () => extractor.extractMelSpectrogram(fakeAudio, sampleRateHz: 12345),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws AudioCaptureException when audio is too short', () {
      final tooShort = Uint8List(16000 * 2 ~/ 10); // ~100ms at 16kHz
      expect(
        () => extractor.extractMelSpectrogram(tooShort, sampleRateHz: 16000),
        throwsA(isA<AudioCaptureException>()),
      );
    });

    test('accepts a valid, in-range recording', () {
      final validAudio = Uint8List(16000 * 2); // ~1s at 16kHz, 16-bit
      final result = extractor.extractMelSpectrogram(
        validAudio,
        sampleRateHz: 16000,
      );
      expect(result, isA<Float32List>());
    });

    test('produces the fixed [800, 80] feature tensor shape', () {
      final result = extractor.extractMelSpectrogram(
        _pcmTone440Hz(),
        sampleRateHz: 16000,
      );
      expect(result.length, kEchoVoiceMaxFrames * kEchoVoiceNumMelBins);
      // Frames beyond the 98 real frames of a 1s recording are zero-padded,
      // matching `features.extract_to_buffer`.
      for (var i = 98 * kEchoVoiceNumMelBins; i < result.length; i++) {
        expect(result[i], 0.0);
      }
    });

    test('matches the Python feature contract on a 440 Hz tone', () {
      // Reference produced by backend/echovoice_ml/features.py
      // (extract_to_buffer) on the identical PCM; float32 log-mel values.
      const cells = <String, double>{
        '0:5': -4.651619911193848,
        '0:20': -7.51694917678833,
        '0:40': -13.734251022338867,
        '0:55': -13.81359577178955,
        '0:79': -13.767382621765137,
        '10:5': -4.651619911193848,
        '50:20': -7.51694917678833,
        '90:40': -13.734251022338867,
        '97:5': -4.7604594230651855,
        '97:20': -7.4206743240356445,
        '97:40': -13.619684219360352,
        '97:55': -13.806933403015137,
        '97:79': -13.73795223236084,
      };
      final result = extractor.extractMelSpectrogram(
        _pcmTone440Hz(),
        sampleRateHz: 16000,
      );
      cells.forEach((key, expected) {
        final parts = key.split(':');
        final frame = int.parse(parts[0]);
        final bin = int.parse(parts[1]);
        expect(result[frame * kEchoVoiceNumMelBins + bin], closeTo(expected, 0.05));
      });
      // Sum of the full padded tensor, cross-checked against numpy.
      final total = result.fold<double>(0.0, (acc, v) => acc + v);
      expect(total, closeTo(-80290.671875, 50));
    });

    test('resamples 8 kHz audio and matches the Python contract', () {
      // 1s 440 Hz tone captured at 8 kHz. The Dart extractor must linearly
      // resample to 16 kHz (features._resample_linear) before STFT. Reference
      // produced by: read_wav -> _resample_linear(s, 8000, 16000) ->
      // extract_to_buffer.
      const cells = <String, double>{
        '0:5': -4.663034915924072,
        '0:20': -7.537626266479492,
        '0:40': -13.699701309204102,
        '0:55': -13.811271667480469,
        '0:79': -3.1581079959869385,
        '10:5': -4.665998935699463,
        '10:20': -7.539926052093506,
        '10:40': -13.701236724853516,
        '10:55': -13.8116455078125,
        '10:79': -3.6122615337371826,
        '50:5': -4.672568321228027,
        '50:20': -7.542702674865723,
        '50:40': -13.702434539794922,
        '50:55': -13.812323570251465,
        '50:79': -7.841701507568359,
        '90:5': -4.67057466506958,
        '90:20': -7.53518533706665,
        '90:40': -13.695868492126465,
        '90:55': -13.811729431152344,
        '90:79': -3.488814115524292,
        '97:5': -4.778811931610107,
        '97:20': -7.438739776611328,
        '97:40': -13.588728904724121,
        '97:55': -13.804421424865723,
        '97:79': -3.178561210632324,
      };
      final result = extractor.extractMelSpectrogram(
        _pcmTone440Hz(fs: 8000),
        sampleRateHz: 8000,
      );
      cells.forEach((key, expected) {
        final parts = key.split(':');
        final frame = int.parse(parts[0]);
        final bin = int.parse(parts[1]);
        expect(result[frame * kEchoVoiceNumMelBins + bin], closeTo(expected, 0.05));
      });
      final total = result.fold<double>(0.0, (acc, v) => acc + v);
      expect(total, closeTo(-79620.8046875, 50));
    });

    test('concentrates energy in the 440 Hz mel band', () {
      final result = extractor.extractMelSpectrogram(
        _pcmTone440Hz(),
        sampleRateHz: 16000,
      );
      final row = Float32List.sublistView(
        result,
        50 * kEchoVoiceNumMelBins,
        (50 + 1) * kEchoVoiceNumMelBins,
      );
      var peakBin = 0;
      for (var m = 1; m < row.length; m++) {
        if (row[m] > row[peakBin]) peakBin = m;
      }
      // 440 Hz sits in mel bin ~13 of 80 for the 80-7600 Hz filterbank.
      expect(peakBin, inInclusiveRange(10, 17));
    });
  });

  group('PhonemeAligner', () {
    final aligner = PhonemeAligner();

    PhonemeTarget target(String symbol, int pos) => PhonemeTarget(
          ipaSymbol: symbol,
          expectedPosition: pos,
          difficultyWeight: 1.0,
        );

    test('returns all matches for a perfect sequence', () {
      final ops = aligner.align(
        ['s', 'ʌ', 'n'],
        [target('s', 0), target('ʌ', 1), target('n', 2)],
      );
      expect(
        ops.map((op) => op.opType),
        [
          AlignmentOpType.match,
          AlignmentOpType.match,
          AlignmentOpType.match,
        ],
      );
      expect(ops.map((op) => op.targetIndex), [0, 1, 2]);
    });

    test('marks a differing symbol as substitution', () {
      final ops = aligner.align(
        ['s', 'i'],
        [target('s', 0), target('u', 1)],
      );
      expect(ops[0].opType, AlignmentOpType.match);
      expect(ops[1].opType, AlignmentOpType.substitution);
      expect(ops[1].predictedIndex, 1);
      expect(ops[1].targetIndex, 1);
    });

    test('flags an extra predicted symbol as deletion', () {
      final ops = aligner.align(
        ['s', 't', 'o', 'p'],
        [target('s', 0), target('o', 1), target('p', 2)],
      );
      final types = ops.map((op) => op.opType);
      expect(
        types.where((t) => t == AlignmentOpType.deletion).length,
        1,
      );
      expect(ops[0].opType, AlignmentOpType.match);
    });

    test('flags a missing predicted symbol as insertion', () {
      final ops = aligner.align(
        ['s', 'o', 'p'],
        [target('s', 0), target('t', 1), target('o', 2), target('p', 3)],
      );
      final types = ops.map((op) => op.opType);
      expect(
        types.where((t) => t == AlignmentOpType.insertion).length,
        1,
      );
    });

    test('scores an empty prediction as all insertions', () {
      final ops = aligner.align(
        [],
        [target('s', 0), target('ʌ', 1), target('n', 2)],
      );
      expect(ops.length, 3);
      expect(
        ops.every((op) => op.opType == AlignmentOpType.insertion),
        isTrue,
      );
      expect(ops.every((op) => op.predictedIndex == null), isTrue);
    });

    test('throws PhonemeAlignmentException on empty target', () {
      expect(
        () => aligner.align(['s'], []),
        throwsA(isA<PhonemeAlignmentException>()),
      );
    });

    test('prefers substitution over delete plus insert', () {
      final ops = aligner.align(['a'], [target('b', 0)]);
      expect(ops.length, 1);
      expect(ops[0].opType, AlignmentOpType.substitution);
    });

    test('keeps predicted indices within range', () {
      final predicted = ['k', 'æ', 't'];
      final targets = [target('k', 0), target('ʌ', 1), target('t', 2)];
      final ops = aligner.align(predicted, targets);
      expect(ops.length, 3);
      for (final op in ops) {
        if (op.predictedIndex != null) {
          expect(op.predictedIndex, inInclusiveRange(0, predicted.length - 1));
        }
      }
    });
  });

  group('PronunciationScorer', () {
    final scorer = PronunciationScorer();

    test('throws PhonemeAlignmentException on empty alignment', () {
      expect(
        () => scorer.computeAccuracyScore([]),
        throwsA(isA<PhonemeAlignmentException>()),
      );
    });

    test('computes accuracy as fraction of matches', () {
      final alignment = [
        AlignmentOp(
            predictedIndex: 0, targetIndex: 0, opType: AlignmentOpType.match),
        AlignmentOp(
            predictedIndex: 1,
            targetIndex: 1,
            opType: AlignmentOpType.substitution),
      ];
      expect(scorer.computeAccuracyScore(alignment), 0.5);
    });
  });
}
