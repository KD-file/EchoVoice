import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/attempt_outcome.dart';
import '../models/phoneme_target.dart';
import '../services/asr_pipeline.dart';
import '../services/assessment_pipeline.dart';
import '../services/demo_pipeline.dart';
import '../services/tflite_asr_model.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';
import '../utils/exceptions.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/score_ring.dart';

/// The practice exercise: the target word, a listen button, the target
/// phonemes, and the big record button. After an attempt the result card
/// (score ring, message, per-phoneme status) appears inline so the child
/// can try again or move to the next word.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.session});

  final SessionState session;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final SyntheticPcmRecorder _recorder = SyntheticPcmRecorder();
  final ScrollController _scrollController = ScrollController();
  Timer? _recordTimer;
  Timer? _autoStopTimer;
  bool _recording = false;
  double _elapsedSeconds = 0.0;
  AttemptOutcome? _outcome;
  int _attemptNumber = 0;

  /// Safety net: if the child does not tap "Done speaking", the demo
  /// recording stops on its own and still scores the attempt.
  static const Duration _autoStopAfter = Duration(seconds: 6);

  bool get _showCelebration =>
      _outcome != null && _outcome!.result.accuracyScore >= 0.9;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _autoStopTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final exercise = widget.session.currentExercise;
    if (exercise == null || _recording) {
      return;
    }
    setState(() {
      _recording = true;
      _elapsedSeconds = 0.0;
      _outcome = null;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!mounted) {
          return;
        }
        setState(() => _elapsedSeconds += 0.1);
      },
    );

    // Safety net: if the child does not tap "Done speaking", the demo
    // recording stops on its own and still scores the attempt.
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_autoStopAfter, _stopRecording);
  }

  Future<void> _stopRecording() async {
    if (!_recording) {
      return;
    }
    _recordTimer?.cancel();
    _recordTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    setState(() => _recording = false);

    final exercise = widget.session.currentExercise;
    if (exercise == null) {
      return;
    }

    try {
      final pcm = _recorder.capture();
      final model = await asrModelLoader(exercise.targets);
      final assessor = OnDeviceAssessor(model: model);
      final result = assessor.assess(pcm: pcm, exercise: exercise);
      final outcome = await widget.session.recordAttempt(
        result: result,
        exercise: exercise,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _outcome = outcome;
        _attemptNumber += 1;
      });
      _revealResult();
    } on EchoVoiceException catch (error) {
      _showMessage(error.message);
    }
  }

  /// Scrolls the result card into view after an attempt.
  void _revealResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _playPrompt() async {
    final exercise = widget.session.currentExercise;
    if (exercise == null || !widget.session.soundEnabled) {
      return;
    }
    widget.session.feedback.playSound('prompt_${exercise.displayWord}');
    _showMessage(
      'Listen\u2026 say "${exercise.displayWord}" like the robot! \u{1F916}',
    );
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on PlatformException {
      // No prompt audio in this environment; silently ignore.
    }
  }

  void _tryAgain() {
    setState(() => _outcome = null);
  }

  void _nextWord() {
    setState(() => _outcome = null);
    widget.session.nextExercise();
  }

  /// Asks before finishing the session, then returns to the practice home
  /// with the score and feedback already shown on the result card.
  Future<void> _finishPractice() async {
    final stars = widget.session.starsForExercise(
      widget.session.currentExercise?.exerciseId ?? '',
    );
    final leave = await confirmLeave(
      context,
      title: 'Done practicing?',
      message: stars > 0
          ? 'You earned $stars star${stars == 1 ? '' : 's'} this round. '
              'Great work!'
          : 'You can keep going or come back later. Great work!',
      confirmLabel: 'Finish',
      emoji: '\u{1F389}',
    );
    if (leave && mounted) {
      setState(() => _outcome = null);
      widget.session.goHome();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.session.currentExercise;
    final category = widget.session.currentCategory;
    final outcome = _outcome;

    if (exercise == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        ListView(
          key: const ValueKey('exercise-screen'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (category != null)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: category.colorLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: category.color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${category.emoji} ${category.name}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: category.color,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Tap the button and say it:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                exercise.displayWord,
                key: const ValueKey('target-word'),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final target in exercise.targets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.tealLight),
                      ),
                      child: Text(
                        target.ipaSymbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: _RecordButton(
                recording: _recording,
                elapsedSeconds: _elapsedSeconds,
                onTap: _recording ? _stopRecording : _startRecording,
              ),
            ),
            if (_recording) ...[
              const SizedBox(height: 14),
              Center(
                child: FilledButton.icon(
                  key: const ValueKey('done-speaking-button'),
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Done speaking'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: widget.session.soundEnabled ? _playPrompt : null,
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(
                  widget.session.soundEnabled ? 'Listen' : 'Sound is off',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.tealDark,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
                  disabledForegroundColor: AppColors.inkSoft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (outcome != null) ...[
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * value,
                    child: child,
                  ),
                ),
                child: _ResultCard(
                  outcome: outcome,
                  stars: widget.session.starsForExercise(exercise.exerciseId),
                  onTryAgain: _tryAgain,
                  onNext: _nextWord,
                  onDone: _finishPractice,
                ),
              ),
            ],
          ],
        ),
        if (_showCelebration)
          _CelebrationOverlay(key: ValueKey('celebration-$_attemptNumber')),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.elapsedSeconds,
    required this.onTap,
  });

  final bool recording;
  final double elapsedSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = recording ? AppColors.coralDark : AppColors.coral;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: recording ? 176 : 160,
              height: recording ? 176 : 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: recording ? 0.25 : 0.18),
              ),
            ),
            InkWell(
              key: const ValueKey('record-button'),
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  recording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          recording
              ? 'Listening\u2026 ${elapsedSeconds.toStringAsFixed(1)}s'
              : 'Say it!',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.outcome,
    required this.stars,
    required this.onTryAgain,
    required this.onNext,
    required this.onDone,
  });

  final AttemptOutcome outcome;
  final int stars;
  final VoidCallback onTryAgain;
  final VoidCallback onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = outcome.result;

    return Container(
      key: const ValueKey('result-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final ring = ScoreRing(accuracy: result.accuracyScore, size: 110);
              final feedback = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Text(
                          i < stars ? '\u2B50' : '\u2606',
                          style: const TextStyle(fontSize: 22),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FeedbackBanner(outcome: outcome),
                ],
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ring),
                    const SizedBox(height: 14),
                    feedback,
                  ],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 16),
                  Expanded(child: feedback),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            result.predicted.isEmpty
                ? 'You said: (nothing heard)'
                : 'You said: ${result.predicted.join(' ')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final op in result.alignment)
                _PhonemeStatusChip(
                  op: op,
                  targets: outcome.exercise.targets,
                  predicted: result.predicted,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTryAgain,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Try again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Next word'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('done-practicing-button'),
              onPressed: onDone,
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: const Text('Done practicing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent caregiver-facing feedback banner shown right after an attempt
/// (Module 4.0 Generate Feedback). Color and emoji follow the score tier so
/// the child gets immediate, positive visual reinforcement.
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.outcome});

  final AttemptOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = outcome.result.accuracyScore;
    final Color color;
    final String emoji;
    if (accuracy >= 0.9) {
      color = AppColors.ok;
      emoji = '\u{1F389}';
    } else if (accuracy >= 0.7) {
      color = AppColors.warn;
      emoji = '\u{1F642}';
    } else if (accuracy >= 0.5) {
      color = AppColors.warn;
      emoji = '\u{1F4AA}';
    } else {
      color = AppColors.coral;
      emoji = '\u{1F504}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              outcome.feedbackMessage,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-shot celebration burst shown over the exercise when the child scores
/// 0.9+ (3 stars). It fades and floats upward once, then leaves the widgets
/// untouched so the result card stays tappable.
class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Opacity(
              opacity: (1.0 - value).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -90 * value),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\u2B50', style: TextStyle(fontSize: 44)),
                          SizedBox(width: 8),
                          Text('\u{1F389}', style: TextStyle(fontSize: 56)),
                          SizedBox(width: 8),
                          Text('\u2B50', style: TextStyle(fontSize: 44)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amberDark.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Amazing! \u{1F31F}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhonemeStatusChip extends StatelessWidget {
  const _PhonemeStatusChip({
    required this.op,
    required this.targets,
    required this.predicted,
  });

  final AlignmentOp op;
  final List<PhonemeTarget> targets;
  final List<String> predicted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String symbol;
    final String icon;
    final Color color;

    switch (op.opType) {
      case AlignmentOpType.match:
        symbol = _targetSymbol(op.targetIndex);
        icon = '\u2713';
        color = AppColors.ok;
      case AlignmentOpType.substitution:
        symbol = _targetSymbol(op.targetIndex);
        icon = '\u2248';
        color = AppColors.warn;
      case AlignmentOpType.insertion:
        symbol = _targetSymbol(op.targetIndex);
        icon = '\u2717';
        color = AppColors.miss;
      case AlignmentOpType.deletion:
        final index = op.predictedIndex ?? -1;
        symbol =
            index >= 0 && index < predicted.length ? predicted[index] : '+';
        icon = '\u002B';
        color = AppColors.miss;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$symbol $icon',
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _targetSymbol(int index) {
    if (index < 0 || index >= targets.length) {
      return '-';
    }
    return targets[index].ipaSymbol;
  }
}
