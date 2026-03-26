import 'dart:convert';

class JournalSummary {
  const JournalSummary({required this.content, required this.tags});
  final String content;
  final List<String> tags;
}

/// Scans [message] for a JSON object with type "journal_summary".
/// Returns null if not found or malformed.
JournalSummary? detectJournalSummary(String message) {
  final regex = RegExp(r'\{[^{}]*"type"\s*:\s*"journal_summary"[^{}]*\}');
  final match = regex.firstMatch(message);
  if (match == null) return null;

  try {
    final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    if (json['type'] != 'journal_summary') return null;
    final content = json['content'] as String?;
    if (content == null || content.isEmpty) return null;
    final tags = (json['tags'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    return JournalSummary(content: content, tags: tags);
  } catch (_) {
    return null;
  }
}
