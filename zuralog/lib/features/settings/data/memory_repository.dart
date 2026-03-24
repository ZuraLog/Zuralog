import '../../../core/network/api_client.dart';

class MemoryItem {
  final String id;
  final String text;
  const MemoryItem({required this.id, required this.text});

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
    id: json['id']?.toString() ?? '',
    text: json['text']?.toString() ?? json['memory']?.toString() ?? '',
  );
}

class MemoryRepository {
  MemoryRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<MemoryItem>> listMemories() async {
    final response = await _apiClient.get('/api/v1/memories');
    final data = response.data;
    final List<dynamic> items = data is Map ? (data['memories'] ?? data['items'] ?? []) : (data is List ? data : []);
    return items.map((e) => MemoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteMemory(String memoryId) async {
    await _apiClient.delete('/api/v1/memories/$memoryId');
  }

  Future<void> clearAllMemories() async {
    await _apiClient.delete('/api/v1/memories', queryParameters: {'confirm': 'true'});
  }
}
