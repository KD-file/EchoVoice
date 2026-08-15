import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:echovoice/models/phoneme_target.dart';
import 'package:echovoice/services/asr_pipeline.dart';
import 'package:echovoice/utils/exceptions.dart';

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
