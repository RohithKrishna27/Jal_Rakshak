import 'package:flutter/material.dart';
import 'package:priject_jalrakshak/services/ollama_chat_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final OllamaChatService _chatService = OllamaChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      role: _ChatRole.assistant,
      text:
          'Hi, I am Jal Rakshak Assistant. Ask me about rivers, pollution reporting, or app features.',
    ),
  ];

  final List<String> _suggestions = const [
    'How do I report river pollution?',
    'Which rivers are most polluted?',
    'Give me clean-up ideas for my area.',
    'Explain the app features briefly.',
  ];

  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, text: text));
      _isSending = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final reply = await _chatService.generateReply(
        messages: _messages
            .map((message) => {
                  'role': message.role == _ChatRole.user ? 'user' : 'assistant',
                  'content': message.text,
                })
            .toList(),
      );

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: _ChatRole.assistant, text: reply));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          role: _ChatRole.assistant,
          text:
              'I could not reach the local AI server right now. Check Wi-Fi and Ollama service.',
          isError: true,
        ));
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(const _ChatMessage(
          role: _ChatRole.assistant,
          text:
              'Chat cleared. Ask me anything about river protection or the app.',
        ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardInset > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        elevation: 0,
        title: const Text('Jal Rakshak Assistant'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clearChat,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF7FB), Color(0xFFF9FCFE)],
          ),
        ),
        child: Column(
          children: [
            if (!isKeyboardOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A3D62), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A3D62).withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jal Rakshak Assistant',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Local Ollama gpt-oss:120b-cloud chat for river help, pollution guidance, and app support.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isKeyboardOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _suggestions
                        .map(
                          (suggestion) => ActionChip(
                            label: Text(suggestion),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: const Color(0xFF0A3D62).withOpacity(0.10),
                              ),
                            ),
                            labelStyle: const TextStyle(
                              color: Color(0xFF0A3D62),
                              fontWeight: FontWeight.w600,
                            ),
                            onPressed: () {
                              _messageController.text = suggestion;
                              _messageController.selection = TextSelection.collapsed(
                                offset: suggestion.length,
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16, 18, 16, isKeyboardOpen ? 24 : 18),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message.role == _ChatRole.user;
                    final bubbleColor = isUser
                        ? const Color(0xFF0A3D62)
                        : message.isError
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFF3F8FC);
                    final textColor = isUser
                        ? Colors.white
                        : message.isError
                            ? const Color(0xFFC62828)
                            : const Color(0xFF102A43);

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                                Radius.circular(isUser ? 18 : 6),
                            bottomRight:
                                Radius.circular(isUser ? 6 : 18),
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_isSending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Ask about rivers, reports, cleanup, or app help',
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FloatingActionButton.small(
                          onPressed: _isSending ? null : _sendMessage,
                          backgroundColor: const Color(0xFF0A3D62),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
  });

  final _ChatRole role;
  final String text;
  final bool isError;
}

enum _ChatRole { user, assistant }
