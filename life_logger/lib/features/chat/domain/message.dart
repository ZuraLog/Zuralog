/// Life Logger Edge Agent — Chat Message Domain Model.
///
/// Represents a single chat message exchanged between the user
/// and the AI assistant. Used by the ChatRepository and UI layers.
library;

/// A single chat message in a conversation.
///
/// Messages have a [role] indicating the author ('user' or 'assistant')
/// and [content] containing the message text.
class ChatMessage {
  /// Unique identifier for this message.
  final String? id;

  /// The message author role: 'user', 'assistant', 'system', or 'tool'.
  final String role;

  /// The text content of the message.
  final String content;

  /// When this message was created.
  final DateTime createdAt;

  /// Creates a new [ChatMessage].
  ///
  /// [role] indicates the message author.
  /// [content] is the message text.
  /// [id] is optional and typically set by the server.
  /// [createdAt] defaults to the current time.
  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Creates a [ChatMessage] from a JSON map.
  ///
  /// Expected keys: 'id' (optional), 'role', 'content', 'created_at' (optional).
  ///
  /// [json] is the decoded JSON map from the server or WebSocket.
  ///
  /// Returns a new [ChatMessage] instance.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this message to a JSON-serializable map.
  ///
  /// Returns a map with keys: 'id', 'role', 'content', 'created_at'.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
