/// Zuralog — Coach Feature Domain Models.
///
/// Immutable value objects used throughout the Coach tab:
/// conversations, messages, prompt suggestions, quick actions.
library;

import 'package:flutter/foundation.dart';

// ── Conversation ──────────────────────────────────────────────────────────────

/// A conversation thread between the user and the AI coach.
@immutable
class Conversation {
  /// Creates a [Conversation].
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview,
    this.messageCount = 0,
    this.isArchived = false,
  });

  /// Unique conversation identifier.
  final String id;

  /// AI-generated or user-set title.
  final String title;

  /// When the conversation was created.
  final DateTime createdAt;

  /// When the last message was added.
  final DateTime updatedAt;

  /// Short preview of the last message (for conversation list).
  final String? preview;

  /// Total number of messages in the conversation.
  final int messageCount;

  /// Whether the conversation is archived.
  final bool isArchived;

  /// Creates a copy with overridden fields.
  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? preview,
    int? messageCount,
    bool? isArchived,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preview: preview ?? this.preview,
      messageCount: messageCount ?? this.messageCount,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Chat Message ──────────────────────────────────────────────────────────────

/// The role of a message author in a conversation.
enum MessageRole {
  /// A message authored by the end user.
  user,

  /// A message authored by the AI assistant.
  assistant,

  /// A system-level confirmation card (NL logging, memory extraction, food photo).
  system,
}

/// A single message within a conversation.
@immutable
class ChatMessage {
  /// Creates a [ChatMessage].
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.attachmentUrls = const [],
  });

  /// Unique message identifier.
  final String id;

  /// The conversation this message belongs to.
  final String conversationId;

  /// Who authored the message.
  final MessageRole role;

  /// Markdown-formatted text content.
  final String content;

  /// When the message was created.
  final DateTime createdAt;

  /// Attachment preview URLs (images, PDFs).
  final List<String> attachmentUrls;

  /// Whether the message has any attachments.
  bool get hasAttachments => attachmentUrls.isNotEmpty;

  /// Creates a copy with overridden fields.
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    DateTime? createdAt,
    List<String>? attachmentUrls,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Prompt Suggestion ─────────────────────────────────────────────────────────

/// A contextual prompt suggestion shown in the New Chat screen.
@immutable
class PromptSuggestion {
  /// Creates a [PromptSuggestion].
  const PromptSuggestion({
    required this.id,
    required this.text,
    this.category,
  });

  /// Unique suggestion identifier.
  final String id;

  /// The prompt text shown in the chip and pre-filled in the input.
  final String text;

  /// Optional category for grouping (e.g., 'sleep', 'activity').
  final String? category;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptSuggestion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ── Quick Action ──────────────────────────────────────────────────────────────

/// A contextual quick action surfaced in the Quick Actions sheet.
@immutable
class QuickAction {
  /// Creates a [QuickAction].
  const QuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.prompt,
  });

  /// Unique action identifier.
  final String id;

  /// Short action title (e.g., "Log Sleep").
  final String title;

  /// Descriptive subtitle (e.g., "Tell me how you slept last night").
  final String subtitle;

  /// Material icon code point for the action icon.
  final int icon;

  /// The pre-filled chat prompt that is auto-sent when the action is tapped.
  final String prompt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
