/// Life Logger Edge Agent — Chat Message Domain Model.
///
/// Represents a single chat message exchanged between the user
/// and the AI assistant. Used by the ChatRepository and UI layers.
library;

/// A single chat message in a conversation.
///
/// Messages have a [role] indicating the author ('user' or 'assistant')
/// and [content] containing the message text. Assistant messages may
/// include a [clientAction] map when the AI requests the client to
/// perform a side-effect (e.g. opening a deep link).
class ChatMessage {
  /// Unique identifier for this message.
  final String? id;

  /// The message author role: 'user', 'assistant', 'system', or 'tool'.
  final String role;

  /// The text content of the message.
  final String content;

  /// When this message was created.
  final DateTime createdAt;

  /// Optional client-side action payload returned by the AI.
  ///
  /// When present, the chat UI should execute the action described
  /// in this map. The `client_action` key indicates the action type
  /// (e.g. `open_url`), with additional keys providing parameters
  /// such as `url` and `fallback_url`.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "client_action": "open_url",
  ///   "url": "strava://record",
  ///   "fallback_url": "https://www.strava.com"
  /// }
  /// ```
  final Map<String, dynamic>? clientAction;

  /// Creates a new [ChatMessage].
  ///
  /// [role] indicates the message author.
  /// [content] is the message text.
  /// [id] is optional and typically set by the server.
  /// [createdAt] defaults to the current time.
  /// [clientAction] is an optional AI-driven action payload.
  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.clientAction,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Creates a [ChatMessage] from a JSON map.
  ///
  /// Expected keys: 'id' (optional), 'role', 'content',
  /// 'created_at' (optional), 'client_action' (optional).
  ///
  /// [json] is the decoded JSON map from the server or WebSocket.
  ///
  /// Returns a new [ChatMessage] instance.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      clientAction: json['client_action'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this message to a JSON-serializable map.
  ///
  /// Returns a map with keys: 'id', 'role', 'content', 'created_at',
  /// and optionally 'client_action' when present.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (clientAction != null) 'client_action': clientAction,
    };
  }
}
