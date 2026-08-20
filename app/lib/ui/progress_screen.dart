import 'package:flutter/material.dart';

import '../data/categories.dart';
import '../models/category.dart';
import '../models/phoneme_target.dart';
import '../services/progress_report_exporter.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';
import '../utils/exceptions.dart';
import 'assign_modal.dart';
import 'widgets/score_ring.dart';

/// Progress tab: a Learner view (overall score, stars, per-family accuracy
/// bars, recent practice) and a Caregiver view (stats, assigned
/// practice, full attempt records). The segmented toggle picks the view.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.session});

  final SessionState session;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late UserRole _view;

  @override
  void initState() {
    super.initState();
    _view = widget.session.role;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('progress-screen'),
      children: [
        _ViewToggle(
          selected: _view,
          onChanged: (value) => setState(() => _view = value),
        ),
        Expanded(
          child: _view == UserRole.learner
              ? _LearnerView(session: widget.session)
              : _CaregiverView(session: widget.session),
        ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            _ToggleButton(
              emoji: '\u{1F388}',
              label: 'Learner',
              selected: selected == UserRole.learner,
              onTap: () => onChanged(UserRole.learner),
            ),
            const SizedBox(width: 6),
            _ToggleButton(
              emoji: '\u{1F9D1}\u200D\u2695\uFE0F',
              label: 'Caregiver',
              selected: selected == UserRole.caregiver,
              onTap: () => onChanged(UserRole.caregiver),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Learner view
// ---------------------------------------------------------------------------

class _LearnerView extends StatelessWidget {
  const _LearnerView({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = session.averageAccuracy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Hi, ${session.name ?? 'friend'}! Here is your progress \u{1F600}',
          style: theme.textTheme.titleLarge?.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                child: Column(
                  children: [
                    ScoreRing(accuracy: average ?? 0, size: 100),
                    const SizedBox(height: 6),
                    Text(
                      'Overall accuracy',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('\u2B50',
                                style: TextStyle(fontSize: 28)),
                            Text(
                              '${session.totalStars}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stars earned',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Sound accuracy', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        _CategoryBars(session: session),
        const SizedBox(height: 20),
        Text('Recent practice', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (session.records.isEmpty)
          const _EmptyState(
            message: 'No practice yet. Tap Practice to try your first word!',
            emoji: '\u{1F3A4}',
          )
        else
          for (final record in session.records.reversed.take(6))
            _RecordTile(record: record, dense: true),
        const SizedBox(height: 16),
        Center(
          child: _ExportPdfButton(
            session: session,
            label: 'Download my report (PDF)',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (final category in session.categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _CategoryBar(
                category: category,
                accuracy: session.accuracyForCategory(category.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.accuracy});

  final SoundCategory category;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(category.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: accuracy ?? 0,
                  minHeight: 8,
                  backgroundColor: category.colorLight,
                  color: category.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          child: Text(
            accuracy == null ? '--' : '${(accuracy! * 100).round()}%',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelLarge?.copyWith(
              color: category.color,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Caregiver view
// ---------------------------------------------------------------------------

class _CaregiverView extends StatelessWidget {
  const _CaregiverView({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = session.averageAccuracy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Caregiver dashboard',
          style: theme.textTheme.titleLarge?.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealDark.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _CaregiverStat(
                label: 'Average',
                value: average == null ? '--' : '${(average * 100).round()}%',
              ),
              _CaregiverStat(label: 'Attempts', value: '${session.records.length}'),
              _CaregiverStat(label: 'Streak', value: '${session.streak}'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: _ExportPdfButton(
            session: session,
            label: 'Export PDF report',
          ),
        ),
        const SizedBox(height: 20),
        _AssignedCard(session: session),
        const SizedBox(height: 20),
        Text('Attempt records', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (session.records.isEmpty)
          const _EmptyState(
            message: 'No attempts recorded yet.',
            emoji: '\u{1F4CA}',
          )
        else
          for (final record in session.records.reversed)
            _RecordTile(record: record, dense: false),
      ],
    );
  }
}

class _CaregiverStat extends StatelessWidget {
  const _CaregiverStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.tealDark,
            ),
          ),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _AssignedCard extends StatelessWidget {
  const _AssignedCard({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assigned = [
      for (final category in session.categories)
        if (session.isAssigned(category.id)) category,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assigned practice',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('assign-button'),
                onPressed: () => _openAssignModal(context),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: const Text('Assign'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (assigned.isEmpty)
            Text(
              'Nothing assigned yet. Assign a sound family for the child to '
              'practice.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
              ),
            )
          else
            for (final category in assigned)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(category.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${category.name} \u2022 ${category.words.length} '
                        'words',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _openAssignModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AssignModal(session: session),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.dense});

  final AssessmentRecord record;
  final bool dense;

  String get _word => record.exerciseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = record.accuracyScore;
    final color = accuracy >= 0.9
        ? AppColors.ok
        : accuracy >= 0.7
            ? AppColors.warn
            : AppColors.miss;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            emojiForWord(_word),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _word,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.ink,
                  ),
                ),
                if (!dense) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${record.predictedPhonemes.join(' ')}  \u2022  '
                    '${_formatDate(record.recordedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(accuracy * 100).round()}%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}

/// Button that builds the PDF progress report (Module 5.0), saves it to
/// Downloads, and confirms the saved location in a dialog.
class _ExportPdfButton extends StatelessWidget {
  const _ExportPdfButton({required this.session, required this.label});

  final SessionState session;
  final String label;

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ProgressReportExporter.exportToPdf(session);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Report saved!'),
          content: Text(
            'Your PDF progress report is ready.\n\nSaved at:\n$path',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on EchoVoiceException catch (error) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const ValueKey('export-pdf-button'),
      onPressed: () => _export(context),
      icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.tealDark,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.emoji});

  final String message;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
