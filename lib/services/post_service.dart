import 'package:firebase_database/firebase_database.dart';

class PostService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('posts');

  Query getPosts() {
    return _ref.orderByChild('timestamp');
  }

  Future<void> addPost({
    required String userName,
    required String type,
    required String title,
    required String description,
  }) async {
    final id = _ref.push().key!;
    await _ref.child(id).set({
      'userName': userName,
      'type': type,
      'title': title,
      'description': description,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
