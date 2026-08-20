import 'package:flutter/material.dart';

/// Who is looking at the app right now: the child practicing (learner) or
/// the caregiver reviewing progress and configuring practice.
enum UserRole { learner, caregiver }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.learner => 'Learner',
        UserRole.caregiver => 'Caregiver',
      };
}

/// A single word within a [SoundCategory], with the emoji the child sees on
/// the practice card. [exerciseId] maps to the matching [Exercise] in the
/// exercise library so the assessment pipeline stays untouched.
class CategoryWord {
  final String exerciseId;
  final String word;
  final String emoji;

  const CategoryWord({
    required this.exerciseId,
    required this.word,
    required this.emoji,
  });
}

/// A sound family shown on the practice home grid (e.g. "Popping Sounds"
/// for /p/ and /b/). Words are grouped by the phonemes a child is working
/// on, which is how the caregiver assigns practice.
class SoundCategory {
  final String id;
  final String name;
  final String tagline;
  final String emoji;
  final Color color;
  final Color colorLight;
  final List<CategoryWord> words;

  const SoundCategory({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.color,
    required this.colorLight,
    required this.words,
  });
}
