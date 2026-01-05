import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'full_screen_image.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final String myUid = FirebaseAuth.instance.currentUser!.uid;
  final String myName = FirebaseAuth.instance.currentUser!.displayName ?? 'You';

  late final DatabaseReference _chatRef;
  late final DatabaseReference _msgRef;

  static const double _inputBarHeight = 64;

  bool _showScrollDown = false;
  Map<String, dynamic>? _replyTo;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _chatRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}');
    _msgRef = _chatRef.child('messages');

    _chatRef.child('unread/$myUid').set(0);
    _scrollCtrl.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.offset <= 40;
    if (_showScrollDown != !atBottom) {
      setState(() => _showScrollDown = !atBottom);
    }
  }

  String _dateLabel(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final m = DateTime(d.year, d.month, d.day);

    if (m == today) return 'Today';
    if (m == yesterday) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _timeLabel(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  void _scrollBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _increaseUnreadForOthers() async {
    final snap = await _chatRef.child('users').get();
    if (!snap.exists) return;

    final users = Map<String, dynamic>.from(snap.value as Map);
    for (final uid in users.keys) {
      if (uid != myUid) {
        _chatRef
            .child('unread/$uid')
            .runTransaction((v) => Transaction.success((v as int? ?? 0) + 1));
      }
    }
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final ts = DateTime.now().millisecondsSinceEpoch;

    await _msgRef.push().set({
      'senderId': myUid,
      'senderName': myName,
      'type': 'text',
      'text': text,
      'timestamp': ts,
      if (_replyTo != null) 'replyTo': _replyTo,
    });

    setState(() => _replyTo = null);

    await _chatRef.update({
      'lastMessage': text,
      'lastTimestamp': ts,
      'lastSenderId': myUid,
      'lastSenderName': myName,
    });

    await _increaseUnreadForOthers();
    _scrollBottom();
  }

  Future<void> _sendImage(ImageSource src) async {
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 75);
    if (picked == null) return;

    final file = File(picked.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _msgRef.push();

    await msgRef.set({
      'senderId': myUid,
      'senderName': myName,
      'type': 'image',
      'uploading': true,
      'localPath': file.path,
      'timestamp': ts,
      if (_replyTo != null) 'replyTo': _replyTo,
    });

    setState(() => _replyTo = null);
    _scrollBottom();

    final ref = FirebaseStorage.instance.ref(
      'chat_images/${widget.chatId}/${msgRef.key}.jpg',
    );

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await msgRef.update({
      'imageUrl': url,
      'uploading': false,
      'localPath': null,
    });

    await _chatRef.update({'lastMessage': '📷 Photo', 'lastTimestamp': ts});
    await _increaseUnreadForOthers();
    _scrollBottom();
  }

  Widget _imageBubble(Map msg) {
    final url = msg['imageUrl'];
    final local = msg['localPath'];

    return GestureDetector(
      onTap: url != null
          ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: url)),
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: url != null
            ? Image.network(url, width: 220, height: 220, fit: BoxFit.cover)
            : Image.file(
                File(local),
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete messages'),
        content: Text('Delete ${_selected.length} messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await Future.wait(_selected.map((id) => _msgRef.child(id).remove()));
      setState(() => _selected.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selected.isEmpty
            ? Text(widget.otherUserName)
            : Text('${_selected.length} selected'),
        actions: _selected.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelected,
                ),
              ]
            : [],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _msgRef.onValue,
              builder: (_, s) {
                if (!s.hasData || s.data!.snapshot.value == null) {
                  return const Center(child: Text('Start chatting 👋'));
                }

                final data = Map<String, dynamic>.from(
                  s.data!.snapshot.value as Map,
                );

                final msgs = data.entries.toList()
                  ..sort(
                    (a, b) =>
                        b.value['timestamp'].compareTo(a.value['timestamp']),
                  );

                return ListView.builder(
                  reverse: true,
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    _inputBarHeight,
                  ),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final id = msgs[i].key;
                    final msg = msgs[i].value;
                    final isMe = msg['senderId'] == myUid;
                    final selected = _selected.contains(id);

                    final curDate = _dateLabel(msg['timestamp']);
                    final nextDate = i + 1 < msgs.length
                        ? _dateLabel(msgs[i + 1].value['timestamp'])
                        : null;

                    return Column(
                      children: [
                        if (curDate != nextDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              curDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onLongPress: () => setState(() => _selected.add(id)),
                          onTap: () {
                            if (_selected.isNotEmpty) {
                              setState(() {
                                selected
                                    ? _selected.remove(id)
                                    : _selected.add(id);
                              });
                            }
                          },
                          child: Dismissible(
                            key: ValueKey(id),
                            direction: _selected.isEmpty
                                ? DismissDirection.startToEnd
                                : DismissDirection.none,
                            movementDuration: const Duration(milliseconds: 120),
                            confirmDismiss: (_) async {
                              setState(() {
                                _replyTo = {
                                  'text': msg['type'] == 'image'
                                      ? '📷 Photo'
                                      : msg['text'],
                                };
                              });
                              return false;
                            },
                            background: const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Icon(Icons.reply),
                              ),
                            ),
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.blue.shade100
                                      : isMe
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (msg['replyTo'] != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: const Border(
                                            left: BorderSide(
                                              color: Colors.blue,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          msg['replyTo']['text'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    msg['type'] == 'image'
                                        ? _imageBubble(msg)
                                        : Text(
                                            msg['text'],
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeLabel(msg['timestamp']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          if (_replyTo != null)
            Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _replyTo!['text'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),

          SafeArea(
            child: SizedBox(
              height: _inputBarHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Camera'),
                              onTap: () {
                                Navigator.pop(context);
                                _sendImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.image),
                              title: const Text('Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _sendImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _showScrollDown
          ? Padding(
              padding: const EdgeInsets.only(bottom: _inputBarHeight + 8),
              child: FloatingActionButton(
                mini: true,
                onPressed: _scrollBottom,
                child: const Icon(Icons.arrow_downward),
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }
}
