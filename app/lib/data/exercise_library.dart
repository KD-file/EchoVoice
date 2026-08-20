import '../models/phoneme_target.dart';

/// Weight given to a phoneme based on how challenging it typically is in
/// speech-sound-disorder therapy. Fricatives/affricates are hardest, so they
/// pull the most weight in the weighted accuracy score.
double _difficultyWeight(String symbol) {
  if (const {'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'tʃ', 'dʒ'}
      .contains(symbol)) {
    return 0.9;
  }
  if (const {'l', 'r', 'w', 'j'}.contains(symbol)) {
    return 0.8;
  }
  if (const {'m', 'n', 'ŋ'}.contains(symbol)) {
    return 0.6;
  }
  if (const {'p', 'b', 't', 'd', 'k', 'g'}.contains(symbol)) {
    return 0.6;
  }
  return 0.5; // vowels
}

Exercise _exercise(String word, List<String> phonemes) {
  return Exercise(
    exerciseId: word,
    displayWord: word,
    targets: [
      for (var i = 0; i < phonemes.length; i++)
        PhonemeTarget(
          ipaSymbol: phonemes[i],
          expectedPosition: i,
          difficultyWeight: _difficultyWeight(phonemes[i]),
        ),
    ],
  );
}

/// The default exercise library: one exercise per word in the ML corpus
/// lexicon (ml/echovoice_ml/lexicon.py). IPA sequences must stay in sync with
/// that table and with the phoneme inventory (phoneme_map.PHONEME_SET).
List<Exercise> defaultExerciseLibrary() {
  return [
    _exercise('sun', ['s', 'ʌ', 'n']),
    _exercise('see', ['s', 'i']),
    _exercise('sit', ['s', 'ɪ', 't']),
    _exercise('sea', ['s', 'i']),
    _exercise('ship', ['ʃ', 'ɪ', 'p']),
    _exercise('shop', ['ʃ', 'ɑ', 'p']),
    _exercise('cheese', ['tʃ', 'i', 'z']),
    _exercise('jam', ['dʒ', 'æ', 'm']),
    _exercise('jump', ['dʒ', 'ʌ', 'm', 'p']),
    _exercise('fan', ['f', 'æ', 'n']),
    _exercise('van', ['v', 'æ', 'n']),
    _exercise('thumb', ['θ', 'ʌ', 'm']),
    _exercise('this', ['ð', 'ɪ', 's']),
    _exercise('fish', ['f', 'ɪ', 'ʃ']),
    _exercise('zoo', ['z', 'u']),
    _exercise('shoes', ['ʃ', 'u', 'z']),
    _exercise('red', ['r', 'e', 'd']),
    _exercise('bed', ['b', 'e', 'd']),
    _exercise('cat', ['k', 'æ', 't']),
    _exercise('dog', ['d', 'ɔ', 'g']),
    _exercise('pig', ['p', 'ɪ', 'g']),
    _exercise('goat', ['g', 'o', 't']),
    _exercise('ball', ['b', 'ɔ', 'l']),
    _exercise('lip', ['l', 'ɪ', 'p']),
    _exercise('moon', ['m', 'u', 'n']),
    _exercise('nose', ['n', 'o', 'z']),
    _exercise('tree', ['t', 'r', 'i']),
    _exercise('key', ['k', 'i']),
    _exercise('car', ['k', 'ɑ', 'r']),
    _exercise('look', ['l', 'ʊ', 'k']),
    _exercise('book', ['b', 'ʊ', 'k']),
    _exercise('clock', ['k', 'l', 'ɑ', 'k']),
  ];
}
