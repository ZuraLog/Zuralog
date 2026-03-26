import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/progress/presentation/journal_mode_picker_sheet.dart';

class JournalEntryRouter extends ConsumerStatefulWidget {
  const JournalEntryRouter({super.key});

  @override
  ConsumerState<JournalEntryRouter> createState() => _JournalEntryRouterState();
}

class _JournalEntryRouterState extends ConsumerState<JournalEntryRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('journal_mode');

    if (!mounted) return;

    if (mode == 'diary') {
      context.push(RouteNames.journalDiaryPath);
      return;
    }
    if (mode == 'conversational') {
      _openConversationalMode();
      return;
    }

    // No preference saved — show picker
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const JournalModePickerSheet(),
    );

    if (!mounted) return;

    if (chosen == 'diary') {
      context.push(RouteNames.journalDiaryPath);
    } else if (chosen == 'conversational') {
      _openConversationalMode();
    }
  }

  void _openConversationalMode() {
    // Will be wired in Task 14. For now, fall back to diary.
    context.push(RouteNames.journalDiaryPath);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
