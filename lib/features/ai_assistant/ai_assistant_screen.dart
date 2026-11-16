import 'package:flutter/material.dart';
import '../../services/ai_assistant_service.dart';

/// Confidential AI Health and Hygiene Assistant Screen
class AiAssistantScreen extends StatefulWidget {
  final VoidCallback? onFindPadsRequested;
  final VoidCallback? onCycleTrackerRequested;

  const AiAssistantScreen({
    super.key,
    this.onFindPadsRequested,
    this.onCycleTrackerRequested,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasApiKey = false;

  static const Color _deepTeal = Color(0xFF116B78);
  static const Color _mint = Color(0xFF35B9B4);
  static const Color _softTeal = Color(0xFFE4F8F2);
  static const Color _ink = Color(0xFF172B36);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final history = await AiAssistantService.loadChatHistory();
    final key = await AiAssistantService.getApiKey();
    if (mounted) {
      setState(() {
        _messages = history;
        _hasApiKey = key != null && key.isNotEmpty;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _isLoading) return;

    _inputController.clear();

    final userMessage = AiChatMessage(
      id: UniqueKey().toString(),
      text: clean,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await AiAssistantService.askCompanion(
        clean,
        previousMessages: _messages,
      );

      if (mounted) {
        setState(() {
          _messages.add(response);
          _isLoading = false;
        });
        await AiAssistantService.saveChatHistory(_messages);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'For your privacy, this will permanently remove all messages from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Privately'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AiAssistantService.clearChatHistory();
      if (mounted) {
        setState(() {
          _messages = [AiAssistantService.getWelcomeMessage()];
        });
      }
    }
  }

  Future<void> _showApiKeyDialog() async {
    final currentKey = await AiAssistantService.getApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: _deepTeal, size: 20),
            SizedBox(width: 8),
            Text('Gemini AI API Key', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PadCare Companion works 100% offline with its built-in expert knowledge base. '
              'Optionally, you can enter a Google Gemini API Key for dynamic live answers.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF556E74)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _deepTeal),
            onPressed: () async {
              await AiAssistantService.setApiKey(controller.text.trim());
              final key = await AiAssistantService.getApiKey();
              if (mounted) {
                setState(() => _hasApiKey = key != null && key.isNotEmpty);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _softTeal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5EAC5)),
              ),
              child: const Icon(Icons.favorite_rounded, color: _deepTeal, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PadCare Companion',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _hasApiKey ? const Color(0xFF10B981) : _mint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _hasApiKey ? 'Gemini 1.5 Flash Connected' : 'Confidential Health Guide (Offline)',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF556E74),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gemini Key Settings',
            icon: const Icon(Icons.vpn_key_outlined, color: _deepTeal, size: 20),
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            tooltip: 'Clear chat privately',
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF7A8B90), size: 22),
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Confidentiality and Safety Alert Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE4F8F2),
                border: Border(bottom: BorderSide(color: Color(0xFFA5EAC5), width: 0.8)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: _deepTeal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% Confidential. Educational guide only—visit a clinic for medical emergencies.',
                      style: TextStyle(fontSize: 11, color: _deepTeal, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Messages Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            if (_isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCECEB)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _deepTeal),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'PadCare Companion is typing...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B8487), fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Bottom Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _deepTeal,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: _deepTeal.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: _softTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.favorite_rounded, size: 14, color: _deepTeal),
                  ),
                ),
                const Text(
                  'PadCare Companion',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _deepTeal),
                ),
                if (message.isOfflineFallback)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Offline Guide',
                      style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: const Color(0xFFDCECEB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (message.relatedAction != null) ...[
                    const SizedBox(height: 10),
                    _buildRelatedActionButton(message.relatedAction!),
                  ],
                ],
              ),
            ),
            if (message.actionSuggestions != null && message.actionSuggestions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.actionSuggestions!.map((suggestion) {
                  return ActionChip(
                    label: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 11, color: _deepTeal, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFA5EAC5)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _sendMessage(suggestion),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedActionButton(String action) {
    if (action == 'find_pads') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _deepTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            if (widget.onFindPadsRequested != null) {
              widget.onFindPadsRequested!();
            }
          },
          icon: const Icon(Icons.location_on_rounded, size: 16),
          label: const Text('Find Pads Near Me', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      );
    }
    if (action == 'cycle_tracker') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _deepTeal,
            side: const BorderSide(color: _deepTeal),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            if (widget.onCycleTrackerRequested != null) {
              widget.onCycleTrackerRequested!();
            }
          },
          icon: const Icon(Icons.calendar_month_rounded, size: 16),
          label: const Text('Open Cycle Tracker', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDCECEB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: 'Ask a private health or hygiene question...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFDCECEB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _deepTeal, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: _deepTeal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(_inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}
