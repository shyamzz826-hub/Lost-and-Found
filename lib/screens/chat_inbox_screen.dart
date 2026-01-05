import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatelessWidget {
  const ChatInboxScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, String chatId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete chat'),
        content: const Text('Are you sure you want to delete this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseDatabase.instance.ref('chats/$chatId').remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final chatRef = FirebaseDatabase.instance.ref('chats');

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<DatabaseEvent>(
        stream: chatRef.onValue,
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: Text('No chats yet'));
          }

          final Map chatsMap = snap.data!.snapshot.value as Map;

          final chats =
              chatsMap.entries
                  .where(
                    (e) =>
                        e.value['users'] is Map &&
                        e.value['users'][myUid] == true,
                  )
                  .toList()
                ..sort((a, b) {
                  final bt = b.value['lastTimestamp'] ?? 0;
                  final at = a.value['lastTimestamp'] ?? 0;
                  return bt.compareTo(at);
                });

          if (chats.isEmpty) {
            return const Center(child: Text('No chats yet'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final chatId = chats[i].key;
              final chat = chats[i].value as Map;

              String otherUid = '';
              final users = chat['users'] as Map;
              for (final uid in users.keys) {
                if (uid != myUid) {
                  otherUid = uid;
                  break;
                }
              }

              int unread = 0;
              final unreadMap = chat['unread'];
              if (unreadMap is Map && unreadMap[myUid] is int) {
                unread = unreadMap[myUid];
              }

              final lastMessage = chat['lastMessage'] is String
                  ? chat['lastMessage']
                  : '';

              String name = 'User';

              if (chat['userInfo'] is Map &&
                  chat['userInfo'][otherUid] is Map &&
                  chat['userInfo'][otherUid]['name'] is String &&
                  chat['userInfo'][otherUid]['name'].toString().isNotEmpty) {
                name = chat['userInfo'][otherUid]['name'];
              }

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,

                onTap: () async {
                  await FirebaseDatabase.instance
                      .ref('chats/$chatId/unread/$myUid')
                      .set(0);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(chatId: chatId, otherUserName: name),
                    ),
                  );
                },

                onLongPress: () => _confirmDelete(context, chatId),
              );
            },
          );
        },
      ),
    );
  }
}
