import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/z_selectable_tile.dart';

class JournalModePickerSheet extends StatefulWidget {
  const JournalModePickerSheet({super.key});

  @override
  State<JournalModePickerSheet> createState() => _JournalModePickerSheetState();
}

class _JournalModePickerSheetState extends State<JournalModePickerSheet> {
  bool _remember = false;

  Future<void> _pick(String mode) async {
    if (_remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('journal_mode', mode);
    }
    if (mounted) Navigator.of(context).pop(mode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How do you want to journal?',
              style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ZSelectableTile(
              isSelected: false,
              showCheckIndicator: false,
              onTap: () => _pick('diary'),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, size: 28),
                  const SizedBox(width: AppDimens.spaceMd),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Write yourself',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: colors.textPrimary),
                      ),
                      Text(
                        'Free-form text entry with tags',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ZSelectableTile(
              isSelected: false,
              showCheckIndicator: false,
              onTap: () => _pick('conversational'),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 28),
                  const SizedBox(width: AppDimens.spaceMd),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk to Coach',
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: colors.textPrimary),
                      ),
                      Text(
                        'Guided reflective conversation',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Switch.adaptive(
                  value: _remember,
                  activeTrackColor: colors.primary,
                  activeThumbColor: colors.primary,
                  onChanged: (v) => setState(() => _remember = v),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'Remember my choice',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
