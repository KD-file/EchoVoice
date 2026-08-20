import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echovoice/services/tflite_asr_model.dart';

/// Builds a flat [numFrames] x [vocabSize] logit buffer in which each frame
/// scores [1.0] for its chosen class and [0.0] everywhere else, so argmax is
/// unambiguous.
Float32List _logitsForFrames(
  List<int> frameClasses, {
  required int vocabSize,
}) {
  final logits = Float32List(frameClasses.length * vocabSize);
  for (var frame = 0; frame < frameClasses.length; frame++) {
    logits[frame * vocabSize + frameClasses[frame]] = 1.0;
  }
  return logits;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeCtcLogits', () {
    // Small vocab: 3 phonemes plus a trailing blank (index 3).
    const vocabSize = 4;
    const blank = 3;
    const vocab = ['s', 'k', 'i', '<blank>'];

    test('removes blanks and returns the argmax symbol per segment', () {
      // s k _ i -> "s", "k", "i"
      final logits = _logitsForFrames([0, 1, blank, 2], vocabSize: vocabSize);
      expect(
        decodeCtcLogits(
          logits,
          numFrames: 4,
          vocabSize: vocabSize,
          blankIndex: blank,
          vocab: vocab,
        ),
        ['s', 'k', 'i'],
      );
    });

    test('collapses consecutive repeats of the same symbol', () {
      // s s s _ k -> "s", "k"
      final logits = _logitsForFrames([0, 0, 0, blank, 1], vocabSize: vocabSize);
      expect(
        decodeCtcLogits(
          logits,
          numFrames: 5,
          vocabSize: vocabSize,
          blankIndex: blank,
          vocab: vocab,
        ),
        ['s', 'k'],
      );
    });

    test('keeps a repeated symbol when a blank separates it', () {
      // s s _ s -> "s", "s"
      final logits = _logitsForFrames([0, 0, blank, 0], vocabSize: vocabSize);
      expect(
        decodeCtcLogits(
          logits,
          numFrames: 4,
          vocabSize: vocabSize,
          blankIndex: blank,
          vocab: vocab,
        ),
        ['s', 's'],
      );
    });

    test('returns an empty list when every frame is blank', () {
      final logits = _logitsForFrames([blank, blank, blank], vocabSize: vocabSize);
      expect(
        decodeCtcLogits(
          logits,
          numFrames: 3,
          vocabSize: vocabSize,
          blankIndex: blank,
          vocab: vocab,
        ),
        isEmpty,
      );
    });

    test('handles leading and trailing blanks', () {
      // _ s _ _ -> "s"
      final logits = _logitsForFrames([blank, 0, blank, blank], vocabSize: vocabSize);
      expect(
        decodeCtcLogits(
          logits,
          numFrames: 4,
          vocabSize: vocabSize,
          blankIndex: blank,
          vocab: vocab,
        ),
        ['s'],
      );
    });

    test('decodes the full exported vocabulary', () {
      // Frames targeting a consonant and a vowel from the real phoneme set:
      // 'tʃ' (index 15), 'ʃ' (index 12), blank (index 34), 'æ' (index 27).
      final fullVocab = [
        'p', 'b', 't', 'd', 'k', 'g', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ',
        'ʒ', 'h', 'tʃ', 'dʒ', 'm', 'n', 'ŋ', 'l', 'r', 'w', 'j', 'i', 'ɪ',
        'e', 'æ', 'ʌ', 'ɑ', 'ɔ', 'o', 'u', 'ʊ', '<blank>',
      ];
      final logits = _logitsForFrames([15, 12, 34, 27], vocabSize: 35);
      expect(
        decodeCtcLogits(
          logits,
          numFrames: 4,
          vocabSize: 35,
          blankIndex: 34,
          vocab: fullVocab,
        ),
        ['tʃ', 'ʃ', 'æ'],
      );
    });

    test('rejects a vocab list that does not match vocabSize', () {
      expect(
        () => decodeCtcLogits(
          _logitsForFrames([0], vocabSize: 4),
          numFrames: 1,
          vocabSize: 4,
          blankIndex: 3,
          vocab: ['s', 'k'], // only 2 of 4
        ),
        throwsArgumentError,
      );
    });

    test('rejects an out-of-range blank index', () {
      expect(
        () => decodeCtcLogits(
          _logitsForFrames([0], vocabSize: 4),
          numFrames: 1,
          vocabSize: 4,
          blankIndex: 4, // == vocabSize
          vocab: vocab,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PhonemeSet', () {
    test('parses the bundled phoneme_set.json artifact', () async {
      final json = jsonDecode(
        await rootBundle.loadString(kPhonemeSetAssetPath),
      ) as Map<String, dynamic>;
      final phonemeSet = PhonemeSet.fromJson(json);
      expect(phonemeSet.vocabSize, 35); // 34 phonemes + blank channel.
      expect(phonemeSet.blankIndex, 34);
      expect(phonemeSet.blankToken, '<blank>');
      expect(phonemeSet.fullSymbols, hasLength(35));
      expect(phonemeSet.fullSymbols[34], '<blank>');
      expect(phonemeSet.fullSymbols, contains('tʃ'));
      expect(phonemeSet.fullSymbols, contains('θ'));
    });

    test('rejects a blank_index that is not the final channel', () {
      expect(
        () => PhonemeSet.fromJson({
          'phonemes': ['a', 'b'],
          'blank_index': 0,
          'blank_token': '<blank>',
        }),
        throwsFormatException,
      );
    });
  });
}
