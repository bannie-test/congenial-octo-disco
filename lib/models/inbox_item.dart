/// Loại thông báo trong app, quyết định màu và biểu tượng.
enum InboxKind { welcome, level, streak, clean, daily, relapse, missed }

/// Một thông báo trong "Hộp thông báo" của app.
class InboxItem {
  InboxItem({
    required this.id,
    required this.kind,
    required this.emoji,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
  });

  final String id;
  final InboxKind kind;
  final String emoji;
  final String title;
  final String body;
  final DateTime at;
  bool read;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'emoji': emoji,
    'title': title,
    'body': body,
    'at': at.toIso8601String(),
    'read': read,
  };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
    id: json['id'] as String,
    kind: InboxKind.values.asNameMap()[json['kind']] ?? InboxKind.welcome,
    emoji: json['emoji'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    at: DateTime.parse(json['at'] as String),
    read: json['read'] as bool? ?? false,
  );
}
