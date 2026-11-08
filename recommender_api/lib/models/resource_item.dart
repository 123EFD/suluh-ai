class ResourceItem {
  final String resourceId;
  final String topic;
  final int durationMin;
  final String type;
  final String content;
  final String? title;

  ResourceItem({
    required this.resourceId,
    required this.topic,
    required this.durationMin,
    required this.type,
    required this.content,
    this.title,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      resourceId: json['resource_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      durationMin: json['duration_min'] as int? ?? json['duration'] as int? ?? 10,
      type: json['type'] as String? ?? 'reading',
      content: json['content'] as String? ?? '',
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resource_id': resourceId,
      'topic': topic,
      'duration': durationMin,
      'duration_min': durationMin,
      'type': type,
      'content': content,
      if (title != null) 'title': title,
    };
  }
}
