/// Journal Settings Screen — preferred journalling mode.
///
/// Lets the user choose whether tapping "Write" on the Progress screen opens
/// the diary editor (they type) or the AI coach chat (they talk). Stored in
/// SharedPreferences under the key `journal_mode`.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Journal Settings screen — choose the default journalling mode.
///
/// Reads [SharedPreferences] key `journal_mode` on init and writes back on
/// every selection change. Falls back to `'diary'` when the key is absent.
class JournalSettingsScreen extends StatefulWidget {
  /// Creates a [JournalSettingsScreen].
  const JournalSettingsScreen({super.key});

  @override
  State<JournalSettingsScreen> createState() => _JournalSettingsScreenState();
}

class _JournalSettingsScreenState extends State<JournalSettingsScreen> {
  // ── State ──────────────────────────────────────────────────────────────────

  /// Current mode — `null` while the preference is still loading.
  String? _mode;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _mode = prefs.getString('journal_mode'));
  }

  Future<void> _setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('journal_mode', mode);
    if (!mounted) return;
    setState(() => _mode = mode);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Journal'),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section label ────────────────────────────────────────────
            Text(
              'Preferred mode',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // ── Mode toggle ──────────────────────────────────────────────
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'diary',
                  label: Text('Write yourself'),
                ),
                ButtonSegment(
                  value: 'conversational',
                  label: Text('Talk to Coach'),
                ),
              ],
              selected: {_mode ?? 'diary'},
              onSelectionChanged: (selection) => _setMode(selection.first),
            ),

            const SizedBox(height: AppDimens.spaceSm),

            // ── Caption ──────────────────────────────────────────────────
            Text(
              'This sets your default when tapping Write on the Progress '
              'screen. You can always switch for a single session.',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
