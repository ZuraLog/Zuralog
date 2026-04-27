class TimingSuggestion {
  const TimingSuggestion({this.tip});

  final String? tip;

  bool get hasTip => tip != null && tip!.isNotEmpty;

  factory TimingSuggestion.fromJson(Map<String, dynamic> json) =>
      TimingSuggestion(tip: json['tip'] as String?);
}
