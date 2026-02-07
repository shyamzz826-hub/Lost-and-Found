import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/post_model.dart';
import 'add_post_screen.dart';
import 'chat_screen.dart';
import 'chat_inbox_screen.dart';
import 'my_posts_screen.dart';
import 'full_screen_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _search = '';
  String _filterType = 'All';

  final List<String> _types = const [
    'All',
    'Lost',
    'Found',
    'Available',
    'Request',
  ];

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _types.map((t) {
              return ListTile(
                title: Text(t),
                trailing: _filterType == t ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() => _filterType = t);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _dateLabel(DateTime d) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final p = DateTime(d.year, d.month, d.day);

    if (p == today) return 'Today';
    if (p == yesterday) return 'Yesterday';

    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  String _timeLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final postRef = FirebaseDatabase.instance.ref('posts');
    final chatRef = FirebaseDatabase.instance.ref('chats');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Connect'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null ? const Icon(Icons.person) : null,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final q = await showSearch(
                context: context,
                delegate: _PostSearchDelegate(),
              );
              if (q != null) setState(() => _search = q.toLowerCase());
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      body: StreamBuilder<DatabaseEvent>(
        stream: postRef.onValue,
        builder: (_, snap) {
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: Text('No posts yet'));
          }

          final raw = snap.data!.snapshot.value as Map;
          List<PostModel> posts = raw.entries.map((e) {
            return PostModel.fromMap(e.key, Map<String, dynamic>.from(e.value));
          }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (_filterType != 'All') {
            posts = posts.where((p) => p.type == _filterType).toList();
          }

          if (_search.isNotEmpty) {
            posts = posts
                .where(
                  (p) =>
                      p.title.toLowerCase().contains(_search) ||
                      p.description.toLowerCase().contains(_search),
                )
                .toList();
          }

          final Map<String, List<PostModel>> grouped = {};
          for (final p in posts) {
            grouped
                .putIfAbsent(
                  _dateLabel(DateTime.fromMillisecondsSinceEpoch(p.timestamp)),
                  () => [],
                )
                .add(p);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 140),
            children: grouped.entries.map((g) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      g.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...g.value.map((post) {
                    final isOwner = post.ownerId == user.uid;
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      post.timestamp,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      elevation: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.imageUrl?.isNotEmpty == true)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FullScreenImage(imageUrl: post.imageUrl!),
                                ),
                              ),
                              child: Image.network(
                                post.imageUrl!,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${post.type}: ${post.title}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(post.description),
                                const SizedBox(height: 6),
                                Text(
                                  _timeLabel(dt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      post.userName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (!isOwner)
                                      TextButton(
                                        child: const Text('Chat'),
                                        onPressed: () async {
                                          final myUid = user.uid;
                                          final otherUid = post.ownerId;
                                          final ids = [myUid, otherUid]..sort();
                                          final chatId =
                                              'chat_${post.id}_${ids[0]}_${ids[1]}';

                                          await FirebaseDatabase.instance
                                              .ref('chats/$chatId')
                                              .update({
                                                'users/$myUid': true,
                                                'users/$otherUid': true,
                                                'unread/$myUid': 0,
                                                'unread/$otherUid': 0,
                                                'userInfo/$myUid/name':
                                                    user.displayName ?? 'User',
                                                'userInfo/$otherUid/name':
                                                    post.userName,
                                              });

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                chatId: chatId,
                                                otherUserName: post.userName,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: StreamBuilder<DatabaseEvent>(
        stream: chatRef.onValue,
        builder: (_, snap) {
          int unread = 0;
          if (snap.hasData && snap.data!.snapshot.value is Map) {
            final data = snap.data!.snapshot.value as Map;
            for (final c in data.values) {
              final map = c['unread'];
              if (map is Map && map[user.uid] is int) {
                unread += map[user.uid] as int;
              }
            }
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(blurRadius: 12, color: Colors.black26),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.article),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyPostsScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  elevation: 0,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPostScreen()),
                  ),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 12),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatInboxScreen(),
                        ),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.red,
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox();
  }

  @override
  Widget buildSuggestions(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Search posts by title or description'),
  );
}
