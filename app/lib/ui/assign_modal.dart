import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/session_state.dart';
import '../ui/app_theme.dart';

/// Bottom sheet where the caregiver picks which sound families the child should
/// practice. Saving replaces the assigned set.
class AssignModal extends StatefulWidget {
  const AssignModal({super.key, required this.session});

  final SessionState session;

  @override
  State<AssignModal> createState() => _AssignModalState();
}

class _AssignModalState extends State<AssignModal> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.session.assignedCategoryIds};
  }

  void _toggle(SoundCategory category) {
    setState(() {
      if (_selected.contains(category.id)) {
        _selected.remove(category.id);
      } else {
        _selected.add(category.id);
      }
    });
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    widget.session.assignCategories(_selected);
    Navigator.of(context).pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _selected.isEmpty
                ? 'Practice assignment cleared.'
                : 'Assigned ${_selected.length} family'
                    '${_selected.length == 1 ? '' : 'ies'} to practice!',
          ),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Assign practice',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Pick the sound families for ${widget.session.name ?? 'the '
                    'child'} to practice.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              for (final category in widget.session.categories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _CategoryCheckTile(
                    category: category,
                    selected: _selected.contains(category.id),
                    onTap: () => _toggle(category),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Save'
                        : 'Assign ${_selected.length} family'
                            '${_selected.length == 1 ? '' : 'ies'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCheckTile extends StatelessWidget {
  const _CategoryCheckTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SoundCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? category.colorLight : const Color(0xFFF3FAF7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? category.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${category.tagline} \u2022 ${category.words.length} '
                      'words',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? category.color : Colors.transparent,
                  border: Border.all(
                    color: selected ? category.color : AppColors.inkSoft,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
