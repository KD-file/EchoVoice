import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/phoneme_target.dart';

/// Emoji shown on the word card for each word in the exercise library.
const Map<String, String> _wordEmoji = {
  'sun': '☀️',
  'see': '👀',
  'sit': '🪑',
  'sea': '🌊',
  'ship': '⛵',
  'shop': '🛍️',
  'cheese': '🧀',
  'jam': '🍯',
  'jump': '🦘',
  'fan': '🪭',
  'van': '🚐',
  'thumb': '👍',
  'this': '👈',
  'fish': '🐟',
  'zoo': '🦓',
  'shoes': '👟',
  'red': '🔴',
  'bed': '🛏️',
  'cat': '🐱',
  'dog': '🐶',
  'pig': '🐷',
  'goat': '🐐',
  'ball': '⚽',
  'lip': '👄',
  'moon': '🌙',
  'nose': '👃',
  'tree': '🌳',
  'key': '🔑',
  'car': '🚗',
  'look': '👀',
  'book': '📖',
  'clock': '🕰️',
};

/// Each sound family lists the words that contain the family's phonemes,
/// pulled from the exercise library by exercise id.
class _CategorySeed {
  const _CategorySeed({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.color,
    required this.colorLight,
    required this.words,
  });

  final String id;
  final String name;
  final String tagline;
  final String emoji;
  final Color color;
  final Color colorLight;
  final List<String> words;
}

const _seeds = [
  _CategorySeed(
    id: 'popping',
    name: 'Popping Sounds',
    tagline: 'P \u00B7 B',
    emoji: '\u{1F4A5}',
    color: Color(0xFF1F8A70),
    colorLight: Color(0xFFDFF4EE),
    words: ['pig', 'bed', 'ball', 'book', 'cheese'],
  ),
  _CategorySeed(
    id: 'hissing',
    name: 'Hissing Sounds',
    tagline: 'S \u00B7 Z \u00B7 Sh',
    emoji: '\u{1F40D}',
    color: Color(0xFF2E9E6B),
    colorLight: Color(0xFFE3F6EA),
    words: ['sun', 'see', 'sit', 'sea', 'ship', 'shop', 'zoo', 'shoes'],
  ),
  _CategorySeed(
    id: 'tapping',
    name: 'Tapping Sounds',
    tagline: 'T \u00B7 D',
    emoji: '\u{1F9B6}',
    color: Color(0xFFF29E4C),
    colorLight: Color(0xFFFFF1E0),
    words: ['tree', 'dog', 'cat', 'goat', 'red'],
  ),
  _CategorySeed(
    id: 'rolling',
    name: 'Rolling Sounds',
    tagline: 'R',
    emoji: '\u{1F300}',
    color: Color(0xFF7A5AF8),
    colorLight: Color(0xFFECE7FF),
    words: ['red', 'tree', 'car', 'key'],
  ),
  _CategorySeed(
    id: 'smooth',
    name: 'Smooth Sounds',
    tagline: 'L \u00B7 N',
    emoji: '\u{1F426}',
    color: Color(0xFFF0595A),
    colorLight: Color(0xFFFFE9E9),
    words: ['lip', 'look', 'moon', 'nose', 'ball', 'clock'],
  ),
];

/// Builds the five practice sound families from the exercise library,
/// keeping every [CategoryWord.exerciseId] resolvable against [library].
List<SoundCategory> buildCategories(List<Exercise> library) {
  return [
    for (final seed in _seeds)
      SoundCategory(
        id: seed.id,
        name: seed.name,
        tagline: seed.tagline,
        emoji: seed.emoji,
        color: seed.color,
        colorLight: seed.colorLight,
        words: [
          for (final word in seed.words)
            CategoryWord(
              exerciseId: word,
              word: word,
              emoji: _wordEmoji[word] ?? '\u{2728}',
            ),
        ],
      ),
  ];
}

/// Convenience lookup so screens can turn an exercise id into an emoji
/// without owning the category data.
String emojiForWord(String exerciseId) => _wordEmoji[exerciseId] ?? '\u{2728}';
