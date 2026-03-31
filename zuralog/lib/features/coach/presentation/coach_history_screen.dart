/// Coach Tab — Full-screen conversation history page.
///
/// Replaces the bottom-sheet drawer with a dedicated page that slides in from
/// the left. Supports search filtering and new conversation creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── CoachHistoryScreen ────────────────────────────────────────────────────────

class CoachHistoryScreen extends ConsumerStatefulWidget {
  const CoachHistoryScreen({
    super.key,
    required this.onConversationTap,
    required this.onNewConversation,
  });

  final void Function(String conversationId) onConversationTap;
  final VoidCallback onNewConversation;

  @override
  ConsumerState<CoachHistoryScreen> createState() => _CoachHistoryScreenState();
}

class _CoachHistoryScreenState extends ConsumerState<CoachHistoryScreen> {
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
    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Conversations',
        showProfileAvatar: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            ref.read(hapticServiceProvider).light();
            Navigator.of(context).pop();
          },
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
            tooltip: 'Search conversations',
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              ref.read(hapticServiceProvider).light();
              widget.onNewConversation();
              Navigator.of(context).pop();
            },
            tooltip: 'New conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _isSearching
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.inputBackground,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusInput,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        autofocus: true,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: AppTextStyles.bodyLarge.copyWith(
                            color: colors.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceSm,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colors.textTertiary,
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
          Divider(height: 1, color: colors.border),
          Expanded(
            child: conversationsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: colors.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load conversations',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textTertiary,
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
                            color: colors.textTertiary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          Text(
                            'No conversations yet',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Text(
                            'Start a new chat to get started',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textTertiary,
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
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          Text(
                            'No conversations match your search',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: colors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceSm,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: AppDimens.spaceMd,
                    color: colors.border,
                  ),
                  itemBuilder: (_, i) => _CoachConversationTile(
                    conversation: filtered[i],
                    onTap: () {
                      ref.read(hapticServiceProvider).light();
                      widget.onConversationTap(filtered[i].id);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CoachConversationTile ────────────────────────────────────────────────────

class _CoachConversationTile extends StatelessWidget {
  const _CoachConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      title: Text(
        conversation.title,
        style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: conversation.preview != null
          ? Text(
              conversation.preview!,
              style:
                  AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        _formatDate(conversation.updatedAt),
        style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
      ),
    );
  }
}
