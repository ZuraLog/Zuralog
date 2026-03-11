/// New Chat Screen — Tab 2 (Coach) root screen.
///
/// Opens to a fresh empty conversation. Shows personalized suggested prompt
/// chips when empty, integration context banner, and chat input with voice
/// and attachment support. Drawer accessible via hamburger icon or swipe.
///
/// Phase 10: Full production implementation with haptics, onboarding tooltip,
/// conversation drawer, quick actions sheet, and skeleton loading state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/speech/speech_providers.dart';
import 'package:zuralog/core/speech/speech_state.dart';
import 'package:zuralog/core/theme/app_assets.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_picker_sheet.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_preview_bar.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/quick_log_sheet.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── NewChatScreen ─────────────────────────────────────────────────────────────

/// Coach tab root — new conversation entry point.
///
/// When no conversation is active, renders the branded welcome state with
/// prompt suggestion chips. Input field + send / voice / attachment buttons
/// are always visible at the bottom.
class NewChatScreen extends ConsumerStatefulWidget {
  /// Creates the [NewChatScreen].
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _openDrawer(BuildContext ctx) {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ConversationDrawer(),
    );
  }

  void _openQuickActions(BuildContext ctx) {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _QuickActionsSheet(
        onActionTap: (prompt) {
          Navigator.of(sheetCtx).pop();
          if (prompt.isNotEmpty) {
            _inputCtrl.text = prompt;
            _sendMessage();
          } else {
            _inputFocus.requestFocus();
          }
        },
      ),
    );
  }

  void _sendMessage({List<Map<String, String>> rawAttachments = const []}) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && rawAttachments.isEmpty) return;
    ref.read(hapticServiceProvider).medium();

    // Read current coach preferences.
    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;

    ref.read(analyticsServiceProvider).capture(
      event: 'coach_message_sent',
      properties: {'source': 'new_chat', 'char_count': text.length},
    );
    _inputCtrl.clear();

    // Generate a temp ID for this new conversation so we can navigate
    // immediately. The server will assign a real UUID and the ChatThreadScreen
    // will swap it once the ConversationCreated event arrives.
    final tempId = 'new_${DateTime.now().millisecondsSinceEpoch}';

    // Attachments cannot be uploaded here because there is no conversation ID
    // yet — the backend requires a real UUID
    // (`/api/v1/chat/{conversationId}/attachments`). Raw file paths are stored
    // in [PendingMessage.rawAttachments] and [ChatThreadScreen] uploads them
    // once the server assigns the real conversation UUID.
    ref.read(pendingFirstMessageProvider(tempId).notifier).state = PendingMessage(
      text: text,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
      rawAttachments: rawAttachments,
    );

    context.pushNamed(
      RouteNames.coachThread,
      pathParameters: {'id': tempId},
    );
  }

  void _onSuggestionTap(String text) {
    ref.read(hapticServiceProvider).light();
    ref
        .read(analyticsServiceProvider)
        .capture(
          event: 'coach_suggestion_tapped',
          properties: {'suggestion_text': text},
        );
    _inputCtrl.text = text;
    _inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for metric deep-link prefill text set by the Data tab.
    ref.listen<String?>(coachPrefillProvider, (_, prefill) {
      if (prefill != null && prefill.isNotEmpty) {
        _inputCtrl.text = prefill;
        _inputFocus.requestFocus();
        // Clear the provider so it is not re-applied on subsequent rebuilds.
        ref.read(coachPrefillProvider.notifier).state = null;
      }
    });

    // Handle prefill value that was set before this build cycle ran
    // (e.g., navigating from Data/Insight tab to Coach tab).
    final pendingPrefill = ref.read(coachPrefillProvider);
    if (pendingPrefill != null && pendingPrefill.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Only apply if the field is still empty (don't overwrite user input).
        if (_inputCtrl.text.isEmpty) {
          _inputCtrl.text = pendingPrefill;
          _inputFocus.requestFocus();
        }
        ref.read(coachPrefillProvider.notifier).state = null;
      });
    }

    final suggestionsAsync = ref.watch(coachPromptSuggestionsProvider);
    final suggestedPromptsEnabled = ref.watch(suggestedPromptsEnabledProvider);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Coach',
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _openDrawer(context),
          tooltip: 'Conversations',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            onPressed: () => _openQuickActions(context),
            tooltip: 'Quick Actions',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Empty State Body ───────────────────────────────────────────────
          Expanded(
            child: suggestionsAsync.when(
              loading: () => _CoachEmptyState(
                onSuggestionTap: _onSuggestionTap,
                suggestions: const [],
                suggestedPromptsEnabled: suggestedPromptsEnabled,
                isLoading: true,
              ),
              error: (e, _) => _CoachEmptyState(
                onSuggestionTap: _onSuggestionTap,
                suggestions: const [],
                suggestedPromptsEnabled: suggestedPromptsEnabled,
              ),
              data: (suggestions) => _CoachEmptyState(
                onSuggestionTap: _onSuggestionTap,
                suggestions: suggestions,
                suggestedPromptsEnabled: suggestedPromptsEnabled,
              ),
            ),
          ),
          const _IntegrationContextBanner(),
          // ── Input Bar ──────────────────────────────────────────────────────
          _ChatInputBar(
            controller: _inputCtrl,
            focusNode: _inputFocus,
            onSend: ({rawAttachments = const []}) =>
                _sendMessage(rawAttachments: rawAttachments),
          ),
          // Push the input bar above the frosted nav bar.
          // AppShell(extendBody: true) injects the nav bar height into
          // MediaQuery.padding.bottom — this SizedBox consumes exactly that
          // inset so the Column doesn't underlap the nav bar.
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── _CoachEmptyState ──────────────────────────────────────────────────────────

class _CoachEmptyState extends StatefulWidget {
  const _CoachEmptyState({
    required this.suggestions,
    required this.onSuggestionTap,
    required this.suggestedPromptsEnabled,
    this.isLoading = false,
  });

  final List<PromptSuggestion> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final bool suggestedPromptsEnabled;

  /// When true, shows the pulsing logo instead of the static logo.
  final bool isLoading;

  @override
  State<_CoachEmptyState> createState() => _CoachEmptyStateState();
}

class _CoachEmptyStateState extends State<_CoachEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// Groups suggestions by their [PromptSuggestion.category] field.
  ///
  /// Suggestions with a null, empty, or blank category are placed under
  /// the `'other'` key to prevent downstream `RangeError` on empty strings.
  Map<String, List<PromptSuggestion>> _groupByCategory(
    List<PromptSuggestion> suggestions,
  ) {
    final groups = <String, List<PromptSuggestion>>{};
    for (final s in suggestions) {
      final key = (s.category?.trim().isNotEmpty == true)
          ? s.category!.toLowerCase().trim()
          : 'other';
      groups.putIfAbsent(key, () => []).add(s);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory(widget.suggestions);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimens.spaceXxl),
            // ── Brand icon / pulsing logo ──────────────────────────────────
            Center(
              child: OnboardingTooltip(
                screenKey: 'coach_new_chat',
                tooltipKey: 'welcome',
                message:
                    'Ask me anything about your health. I can see data from all your connected apps and remember our past conversations.',
                child: widget.isLoading
                    ? const _PulsingLogo()
                    : const _StaticLogo(),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Your health coach',
               style: AppTextStyles.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Ask me anything. I have full context from\nyour connected apps and health history.',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceXl),
            // ── "What I can do" capability row ────────────────────────────
            const _CapabilityRow(),
            const SizedBox(height: AppDimens.spaceXl),
            // ── Grouped suggestion cards ───────────────────────────────────
            if (widget.suggestedPromptsEnabled &&
                widget.suggestions.isNotEmpty) ...[
              for (final entry in grouped.entries) ...[
                _CategoryHeader(category: entry.key),
                const SizedBox(height: AppDimens.spaceSm),
                for (final suggestion in entry.value) ...[
                  _SuggestionCard(
                    suggestion: suggestion,
                    onTap: () => widget.onSuggestionTap(suggestion.text),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                ],
                const SizedBox(height: AppDimens.spaceSm),
              ],
            ],
            const SizedBox(height: AppDimens.spaceXl),
          ],
        ),
      ),
    );
  }
}

// ── _StaticLogo ───────────────────────────────────────────────────────────────

class _StaticLogo extends StatelessWidget {
  const _StaticLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SvgPicture.asset(
          AppAssets.logoSvg,
          colorFilter: const ColorFilter.mode(
            AppColors.primary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

// ── _PulsingLogo ──────────────────────────────────────────────────────────────

/// Animated logo that pulses (scale 1.0 → 1.05) while suggestions are loading.
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SvgPicture.asset(
            AppAssets.logoSvg,
            colorFilter: const ColorFilter.mode(
              AppColors.primary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

// ── _CapabilityRow ────────────────────────────────────────────────────────────

/// Horizontal row of 3 capability icons: Analyze, Plan, Track.
class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.insights_rounded, label: 'Analyze'),
      (icon: Icons.edit_note_rounded, label: 'Plan'),
      (icon: Icons.trending_up_rounded, label: 'Track'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items
          .map(
            (item) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 24, color: AppColors.primary),
                const SizedBox(height: AppDimens.spaceXs),
                 Text(
                   item.label,
                   style: AppTextStyles.bodySmall.copyWith(
                     color: AppColors.textTertiary,
                   ),
                 ),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ── _CategoryHeader ───────────────────────────────────────────────────────────

/// Small header with a colored dot and category name label.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFromString(category);
    // Guard against empty string: category is normalised by _groupByCategory
    // but _CategoryHeader is also defensive on its own.
    final label = category.isEmpty
        ? 'Other'
        : category[0].toUpperCase() + category.substring(1);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          label,
           style: AppTextStyles.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── _SuggestionCard ───────────────────────────────────────────────────────────

/// Full-width card with a left colored border for a prompt suggestion.
///
/// Haptic feedback is intentionally omitted here — the caller's [onTap]
/// callback (routed through [_NewChatScreenState._onSuggestionTap]) already
/// fires a light haptic, so a second `ConsumerWidget` element is unnecessary.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final PromptSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = categoryColorFromString(
      suggestion.category?.trim().toLowerCase() ?? 'other',
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderDark, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left colored accent border
              Container(width: 4, color: borderColor),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceMd,
                  ),
                   child: Text(
                     suggestion.text,
                     style: AppTextStyles.bodyLarge.copyWith(
                       color: AppColors.textSecondary,
                     ),
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

// ── _IntegrationContextBanner ─────────────────────────────────────────────────

/// Compact, dismissible banner shown above the input bar that surfaces which
/// apps the AI has access to for the current session.
///
/// Returns [SizedBox.shrink] when no integrations are connected or after the
/// user taps the dismiss button. Dismissal is ephemeral (session only).
class _IntegrationContextBanner extends ConsumerStatefulWidget {
  const _IntegrationContextBanner();

  @override
  ConsumerState<_IntegrationContextBanner> createState() =>
      _IntegrationContextBannerState();
}

class _IntegrationContextBannerState
    extends ConsumerState<_IntegrationContextBanner> {
  bool _dismissed = false;

  void _dismiss() => setState(() => _dismissed = true);

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final integrationsState = ref.watch(integrationsProvider);
    final connected = integrationsState.integrations
        .where((i) => i.status == IntegrationStatus.connected)
        .toList();

    if (connected.isEmpty) return const SizedBox.shrink();

    // Build the label: list all names when ≤2, otherwise first two + "+N more".
    final String namesLabel;
    if (connected.length <= 2) {
      namesLabel = connected.map((i) => i.name).join(', ');
    } else {
      final first2 = connected.take(2).map((i) => i.name).join(', ');
      final remaining = connected.length - 2;
      namesLabel = '$first2 +$remaining more';
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              'AI has access to: $namesLabel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: _dismiss,
            color: AppColors.textTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ── _ChatInputBar ─────────────────────────────────────────────────────────────

class _ChatInputBar extends ConsumerStatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called when the user taps Send.
  ///
  /// [rawAttachments] contains raw local file info (path + name) for any
  /// attachments the user added. Upload is deferred to [ChatThreadScreen]
  /// because no conversation ID exists yet at this point.
  final void Function({List<Map<String, String>> rawAttachments}) onSend;

  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
  final List<PendingAttachment> _attachments = [];

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    // Attachments cannot be uploaded here because there is no conversation ID
    // yet. Pass the raw file paths to [ChatThreadScreen], which will upload
    // them after the server assigns a real UUID via the ConversationCreated
    // event.
    final rawAttachments = _attachments
        .map((a) => {'path': a.file.path, 'name': a.name})
        .toList();

    setState(() => _attachments.clear());
    widget.onSend(rawAttachments: rawAttachments);
  }

  @override
  Widget build(BuildContext context) {
    final speechState = ref.watch(speechNotifierProvider);
    final isListening = speechState.status == SpeechStatus.listening;
    final voiceInputEnabled = ref.watch(voiceInputEnabledProvider);

    // Sync recognized text to input field.
    ref.listen<SpeechState>(speechNotifierProvider, (prev, next) {
      // Stream partial results while listening.
      if (next.recognizedText.isNotEmpty && !next.isFinal) {
        widget.controller.text = next.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
      // Commit final transcript when listening ends.
      if (prev?.isFinal == false &&
          next.isFinal &&
          next.recognizedText.isNotEmpty) {
        widget.controller.text = next.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
      // Show error snackbar.
      if (next.status == SpeechStatus.error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Microphone unavailable'),
          ),
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Attachment previews ──────────────────────────────────────────
          AttachmentPreviewBar(
            attachments: _attachments,
            onRemove: (i) => setState(() => _attachments.removeAt(i)),
          ),
          // ── Input row ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              // Small visual breathing room between the input row and the
              // bottom of the container. Nav bar clearance is handled by the
              // SizedBox added after _ChatInputBar in the parent Column.
              AppDimens.spaceSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment
                _InputIconButton(
                  icon: Icons.add_circle_outline_rounded,
                  onTap: () async {
                    if (_attachments.length >= 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maximum 3 attachments per message'),
                        ),
                      );
                      return;
                    }
                    ref.read(hapticServiceProvider).light();
                    await showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => AttachmentPickerSheet(
                        onAttachment: (attachment) {
                          setState(() => _attachments.add(attachment));
                        },
                      ),
                    );
                  },
                  tooltip: 'Attach',
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputBackgroundDark,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusInput),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      maxLines: 5,
                      minLines: 1,
                       style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Message your coach…',
                        hintStyle: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceSm,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Send / Voice
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    final hasContent = hasText || _attachments.isNotEmpty;
                    if (hasContent) {
                      return _InputIconButton(
                        icon: Icons.arrow_upward_rounded,
                        filled: true,
                        onTap: _handleSend,
                        tooltip: 'Send',
                      );
                    }
                    if (!voiceInputEnabled) {
                      return const SizedBox.shrink();
                    }
                    return _InputIconButton(
                      icon: isListening
                          ? Icons.stop_circle_rounded
                          : Icons.mic_none_rounded,
                      filled: false,
                      activeColor: isListening ? AppColors.statusError : null,
                      onTap: () async {
                        if (isListening) {
                          ref
                              .read(speechNotifierProvider.notifier)
                              .stopListening();
                          ref.read(hapticServiceProvider).light();
                        } else {
                          ref.read(hapticServiceProvider).medium();
                          // Initialize the speech engine on first use (requests
                          // microphone permission and sets up the recognizer).
                          // Subsequent calls are idempotent — the service tracks
                          // its own state and skips re-initialization when ready.
                          final notifier =
                              ref.read(speechNotifierProvider.notifier);
                          final currentStatus = ref
                              .read(speechNotifierProvider)
                              .status;
                          if (currentStatus == SpeechStatus.uninitialized) {
                            final available = await notifier.initialize();
                            if (!available) return;
                          }
                          notifier.startListening();
                        }
                      },
                      tooltip: isListening ? 'Stop listening' : 'Voice input',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  const _InputIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  /// Override icon color (e.g. red when mic is recording).
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : AppColors.inputBackgroundDark,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: activeColor ??
                (filled
                    ? AppColors.primaryButtonText
                    : AppColors.textSecondaryDark),
          ),
        ),
      ),
    );
  }
}

// ── _ConversationDrawer ───────────────────────────────────────────────────────

/// Bottom sheet listing past conversations (Conversation Drawer).
class _ConversationDrawer extends ConsumerStatefulWidget {
  const _ConversationDrawer();

  @override
  ConsumerState<_ConversationDrawer> createState() =>
      _ConversationDrawerState();
}

class _ConversationDrawerState extends ConsumerState<_ConversationDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
    String query,
  ) {
    if (query.isEmpty) return conversations;
    final lower = query.toLowerCase();
    return conversations.where((c) {
      final titleMatch = c.title.toLowerCase().contains(lower);
      final previewMatch =
          c.preview != null && c.preview!.toLowerCase().contains(lower);
      return titleMatch || previewMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(coachConversationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusCard),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Conversations', style: AppTextStyles.titleMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () {
                        setState(() => _isSearching = true);
                      },
                      tooltip: 'Search conversations',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        ref.read(hapticServiceProvider).light();
                        Navigator.of(ctx).pop();
                      },
                      tooltip: 'New conversation',
                    ),
                  ],
                ),
              ),
              // Search field — expands/collapses with AnimatedSize
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimens.spaceMd,
                          0,
                          AppDimens.spaceMd,
                          AppDimens.spaceSm,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.inputBackgroundDark,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusInput),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            autofocus: true,
                             style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Search conversations...',
                              hintStyle: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceMd,
                                vertical: AppDimens.spaceSm,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearching = false;
                                    _searchController.clear();
                                  });
                                  _searchFocus.unfocus();
                                },
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const Divider(height: 1, color: AppColors.borderDark),
              // List
              Expanded(
                child: conversationsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                   error: (e, _) => Center(
                    child: Text(
                      'Could not load conversations',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  data: (conversations) {
                    if (conversations.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: AppColors.textTertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              Text(
                                'No conversations yet',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceSm),
                              Text(
                                'Start a new chat to get started',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final filtered = _filterConversations(
                      conversations,
                      _searchController.text.trim(),
                    );

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              Text(
                                'No conversations match your search',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceSm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (context, _) => const Divider(
                        height: 1,
                        indent: AppDimens.spaceMd,
                        color: AppColors.borderDark,
                      ),
                      itemBuilder: (_, i) => _ConversationTile(
                        conversation: filtered[i],
                        onTap: () {
                          ref.read(hapticServiceProvider).light();
                          Navigator.of(ctx).pop();
                          context.pushNamed(
                            RouteNames.coachThread,
                            pathParameters: {'id': filtered[i].id},
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  Future<void> _showActionsSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.archive_outlined,
                  color: AppColors.primary,
                ),
                 title: Text('Archive', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _archiveConversation(context, ref);
                },
              ),
              const Divider(height: 1, color: AppColors.borderDark),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.statusError,
                ),
                 title: Text(
                   'Delete',
                   style: AppTextStyles.bodyLarge.copyWith(
                     color: AppColors.statusError,
                   ),
                 ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirmation(context, ref);
                },
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _archiveConversation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(coachConversationsProvider.notifier).archive(conversation.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation archived')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archive failed: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
         title: Text('Delete conversation?', style: AppTextStyles.titleMedium),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context, ref);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    ref.read(hapticServiceProvider).medium();
    try {
      await ref.read(coachConversationsProvider.notifier).delete(conversation.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showActionsSheet(context, ref),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                             style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Text(
                          _formatDate(conversation.updatedAt),
                           style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    if (conversation.preview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        conversation.preview!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _QuickActionsSheet ────────────────────────────────────────────────────────

class _QuickActionsSheet extends ConsumerWidget {
  const _QuickActionsSheet({required this.onActionTap});

  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(coachQuickActionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusCard),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                   child: Text('Quick Actions', style: AppTextStyles.titleMedium),
                ),
              ),
              const Divider(height: 1, color: AppColors.borderDark),
              Expanded(
                child: actionsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                   error: (e, _) => Center(
                    child: Text(
                      'Could not load quick actions',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  data: (actions) {
                    final totalCount = actions.length + 1; // +1 for Quick Log tile
                    return GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppDimens.spaceSm,
                            crossAxisSpacing: AppDimens.spaceSm,
                            childAspectRatio: 1.6,
                          ),
                      itemCount: totalCount,
                      itemBuilder: (gridCtx, i) {
                        if (i == actions.length) {
                          return _QuickLogTile(outerContext: ctx);
                        }
                        return _QuickActionTile(
                          action: actions[i],
                          onTap: () {
                            ref.read(hapticServiceProvider).medium();
                            ref
                                .read(analyticsServiceProvider)
                                .capture(
                                  event: 'coach_quick_action_tapped',
                                  properties: {'title': actions[i].title},
                                );
                            onActionTap(actions[i].prompt);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              IconData(action.icon, fontFamily: 'MaterialIcons'),
              size: 24,
              color: AppColors.primary,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  action.subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogTile extends ConsumerWidget {
  const _QuickLogTile({required this.outerContext});
  final BuildContext outerContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        Navigator.of(outerContext).pop(); // close quick actions sheet
        showModalBottomSheet<void>(
          context: outerContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => QuickLogSheet(
              scrollController: scrollController,
              onSubmit: (QuickLogData data) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(outerContext).showSnackBar(
                  SnackBar(
                    content: const Text('Health data logged!'),
                    backgroundColor: AppColors.surfaceDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusButtonMd,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: AppColors.categoryActivity.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(
              Icons.edit_note_rounded,
              size: 24,
              color: AppColors.categoryActivity,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Log',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Log metrics manually',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


