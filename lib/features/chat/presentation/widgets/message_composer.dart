import 'package:flutter/material.dart';

class MessageComposer extends StatefulWidget {
  final bool enabled, sending;
  final Future<void> Function(String) onSend;
  final VoidCallback onPhoto;
  final ValueChanged<String> onChanged;
  const MessageComposer({
    super.key,
    required this.enabled,
    required this.sending,
    required this.onSend,
    required this.onPhoto,
    required this.onChanged,
  });
  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty || !widget.enabled || widget.sending) return;
    final text = _text.text;
    _text.clear();
    widget.onChanged('');
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.enabled)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'You’re offline. Connect to send. Nothing is queued.',
              ),
            ),
          Wrap(
            spacing: 8,
            children: ['Papunta na', 'Nandito na.']
                .map(
                  (text) => ActionChip(
                    label: Text(text),
                    onPressed: widget.enabled && !widget.sending
                        ? () => widget.onSend(text)
                        : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Send photo',
                onPressed: widget.enabled && !widget.sending
                    ? widget.onPhoto
                    : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    hintText: 'Kumusta?',
                    counterText: '',
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: widget.enabled && !widget.sending ? _send : null,
                icon: widget.sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
