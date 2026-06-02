import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:opa_app/services/chat_websocket_service.dart';
import 'package:opa_app/services/image_upload_service.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatWebSocketService _wsService = ChatWebSocketService();
  final ImageUploadService _imageService = ImageUploadService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  Timer? _typingTimer;
  Map<String, dynamic>? _replyTo;
  String? _imageUploading;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    await _wsService.connect();
    
    _wsService.onMessage((data) {
      if (mounted) {
        setState(() {
          _messages.insert(0, data);
        });
        _scrollToBottom();
      }
    });
    
    _wsService.onTypingStart((data) {
      if (data['chatId'] == widget.chatId && data['userId'] != _wsService.userId) {
        setState(() => _isTyping = true);
      }
    });
    
    _wsService.onTypingStop((data) {
      if (data['chatId'] == widget.chatId) {
        setState(() => _isTyping = false);
      }
    });
    
    _wsService.onMessageRead((data) {
      if (data['chatId'] == widget.chatId) {
        setState(() {});
      }
    });
    
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await ref.read(chatProvider.notifier).getMessages(widget.chatId);
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTyping() {
    if (_typingTimer != null) {
      _typingTimer!.cancel();
    } else {
      _wsService.sendTypingStart(widget.chatId);
    }
    
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _wsService.sendTypingStop(widget.chatId);
      _typingTimer = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final message = _messageController.text.trim();
    _messageController.clear();
    
    await _wsService.sendMessage(
      widget.chatId,
      message,
      replyToId: _replyTo?['id'],
    );
    
    setState(() => _replyTo = null);
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    setState(() => _imageUploading = 'Uploading...');
    
    try {
      final imageUrl = await _imageService.uploadImage(File(image.path));
      await _wsService.sendImage(widget.chatId, imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload gambar: $e')),
      );
    } finally {
      setState(() => _imageUploading = null);
    }
  }

  Future<void> _sendLocation() async {
    final location = Location();
    final permission = await location.requestPermission();
    
    if (permission != PermissionStatus.granted) return;
    
    final currentLocation = await location.getLocation();
    
    await _wsService.sendLocation(
      widget.chatId,
      currentLocation.latitude!,
      currentLocation.longitude!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Tim'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChatInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Typing indicator
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Seseorang sedang mengetik...'),
                ],
              ),
            ),
          
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['senderId'] == _wsService.userId;
                      
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          
          // Reply indicator
          if (_replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membalas: ${_replyTo!['sender']['name']}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _replyTo!['content'],
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),
          
          // Image uploading indicator
          if (_imageUploading != null)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 8),
                  Text(_imageUploading!),
                ],
              ),
            ),
          
          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () => _showAttachmentMenu(),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) => _handleTyping(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final isRead = message['readBy']?.any((r) => r['userId'] != message['senderId']) ?? false;
    
    return GestureDetector(
      onLongPress: () {
        setState(() => _replyTo = message);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  message['sender']['name'][0].toUpperCase(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message['sender']['name'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    if (message['replyTo'] != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Membalas: ${message['replyTo']['sender']['name']}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              message['replyTo']['content'],
                              style: const TextStyle(fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    if (message['type'] == 'text')
                      Text(message['content']),
                    if (message['type'] == 'image')
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Image.network(message['mediaUrl']),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message['mediaUrl'],
                            height: 150,
                            width: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (message['type'] == 'location')
                      GestureDetector(
                        onTap: () {
                          final location = message['location'];
                          // Open map with location
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  message['location']?['address'] ?? 'Lihat lokasi',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(DateTime.parse(message['createdAt'])),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        if (isMe && isRead)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.done_all, size: 12, color: Colors.blue),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Kirim Gambar'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Bagikan Lokasi'),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Info Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // Add participant list, etc.
          ],
        ),
      ),
    );
  }
}