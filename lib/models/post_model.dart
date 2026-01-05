class PostModel {
  final String id;
  final String ownerId;
  final String userName;
  final String type;
  final String title;
  final String description;
  final String? imageUrl;
  final int timestamp;

  PostModel({
    required this.id,
    required this.ownerId,
    required this.userName,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
  });

  factory PostModel.fromMap(String id, Map<String, dynamic> data) {
    return PostModel(
      id: id,
      ownerId: data['ownerId'] ?? '',
      userName: data['userName'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] ?? 0,
    );
  }
}
