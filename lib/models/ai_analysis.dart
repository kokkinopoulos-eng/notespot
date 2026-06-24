const List<String> kCategories = [
  'receipts', 'work', 'personal', 'shopping', 'ideas', 'food', 'travel', 'other'
];
class AiAnalysis {
  const AiAnalysis({
    required this.title,
    required this.category,
    required this.tags,
    required this.extractedText,
    this.description = '',
  });
  final String title;
  final String category;
  final List<String> tags;
  final String extractedText;
  final String description;
  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    final rawCat = (json['category'] as String? ?? '').toLowerCase().trim();
    final category = kCategories.contains(rawCat) ? rawCat : 'other';
    final rawTags = json['tags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.whereType<String>().toList();
    }
    return AiAnalysis(
      title: (json['title'] as String? ?? '').trim(),
      category: category,
      tags: tags,
      extractedText: (json['extracted_text'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
    );
  }
}