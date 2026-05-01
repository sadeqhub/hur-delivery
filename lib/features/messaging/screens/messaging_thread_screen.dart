import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/messaging_service.dart';
import '../../../core/localization/app_localizations.dart';

class MessagingThreadScreen extends StatefulWidget {
  final String conversationId;
  final bool isSupport;
  const MessagingThreadScreen({super.key, required this.conversationId, this.isSupport = false});

  @override
  State<MessagingThreadScreen> createState() => _MessagingThreadScreenState();
}

class _MessagingThreadScreenState extends State<MessagingThreadScreen> {
  late final Stream<List<Message>> _stream;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Message? _replyingTo;
  final List<Message> _pending = [];
  final Set<String> _knownIds = {};
  final ImagePicker _picker = ImagePicker();
  File? _pendingImage;
  bool _isSending = false;

  // Typing-indicator state. Admin messages arriving via realtime are held back
  // behind a short Timer to give the illusion that the agent is typing. Existing
  // history (loaded on first stream emission) is marked revealed immediately.
  final Set<String> _revealedIds = {};
  final Map<String, Timer> _revealTimers = {};
  bool _seededReveals = false;

  // Recognizers for tappable email/phone spans. Recreated on each build and
  // disposed in dispose() to avoid leaking gesture detectors.
  final List<TapGestureRecognizer> _linkRecognizers = [];

  // Matches Iraqi-format phones (+9647XXXXXXXXX or 07XXXXXXXX) and emails.
  // Lookarounds prevent partial matches inside longer digit runs (e.g. dates).
  static final RegExp _linkRegex = RegExp(
    r'(?<!\d)(\+\d{9,15}|0\d{9,10})(?!\d)'
    r'|([\w.+\-]+@[\w\-]+\.[\w.\-]+)',
  );

  @override
  void initState() {
    super.initState();
    _stream = MessagingService.instance.watchMessages(
      widget.conversationId,
      lookback: const Duration(days: 1),
    );
    if (widget.isSupport) {
      MessagingService.instance.setViewingSupport(true);
    }
  }

  @override
  void dispose() {
    for (final t in _revealTimers.values) {
      t.cancel();
    }
    _revealTimers.clear();
    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();
    if (widget.isSupport) {
      MessagingService.instance.setViewingSupport(false);
    }
    super.dispose();
  }

  Future<void> _openLink(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uri.toString())),
        );
      }
    } catch (_) {
      // Best-effort: silently ignore launch failures.
    }
  }

  // Builds TextSpans for a message body, turning detected phone numbers and
  // emails into tappable links. Caller is responsible for disposing the
  // accumulated _linkRecognizers (handled in dispose()).
  List<TextSpan> _buildMessageSpans(
    String text, {
    required TextStyle? linkStyle,
  }) {
    final spans = <TextSpan>[];
    int cursor = 0;

    for (final match in _linkRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final raw = match.group(0)!;
      final isEmail = raw.contains('@');
      final uri = isEmail
          ? Uri(scheme: 'mailto', path: raw)
          : Uri(scheme: 'tel', path: raw.replaceAll(' ', ''));

      final recognizer = TapGestureRecognizer()..onTap = () => _openLink(uri);
      _linkRecognizers.add(recognizer);

      spans.add(TextSpan(
        text: raw,
        style: linkStyle,
        recognizer: recognizer,
      ));

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  // Reading speed ≈ characters/second translated to a typing dwell time.
  // ~25ms per character + 400ms baseline, clamped to a humane window.
  Duration _typingDurationFor(String body) {
    final ms = (400 + body.length * 25).clamp(600, 3000);
    return Duration(milliseconds: ms);
  }

  void _scheduleReveal(String id, Duration delay) {
    if (!mounted) return;
    if (_revealedIds.contains(id) || _revealTimers.containsKey(id)) return;
    _revealTimers[id] = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _revealedIds.add(id);
        _revealTimers.remove(id);
      });
    });
    // Trigger a rebuild to show the typing bubble immediately.
    setState(() {});
  }

  Future<Message?> _resolveSentMessage({
    required DateTime startedAt,
    required String conversationId,
    required String? senderId,
  }) async {
    if (senderId == null) return null;
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('sender_id', senderId)
          .gte(
            'created_at',
            startedAt.subtract(const Duration(seconds: 2)).toIso8601String(),
          )
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return Message.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('⚠️ Failed to resolve sent message: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    if (_isSending) return;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() {
        _pendingImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.failedSelectImage)),
      );
    }
  }

  void _removePendingImage() {
    setState(() {
      _pendingImage = null;
    });
  }

  Future<void> _send() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    final hasText = text.isNotEmpty;
    final hasImage = _pendingImage != null;
    if (!hasText && !hasImage) return;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final replyToId = _replyingTo?.id;
    Message? optimistic;
    String? attachmentUrl;
    String? attachmentType;
    final startedAt = DateTime.now().toUtc();

    setState(() {
      _isSending = true;
    });

    try {
      if (hasImage && _pendingImage != null) {
        final file = _pendingImage!;
        final bytes = await file.readAsBytes();
        final ext = file.path.split('.').last.toLowerCase();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final objectPath =
            'conversations/${widget.conversationId}/$timestamp.$ext';
        final mime = ext == 'png'
            ? 'image/png'
            : ext == 'gif'
                ? 'image/gif'
                : 'image/jpeg';

        await Supabase.instance.client.storage.from('files').uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mime,
              ),
            );

        attachmentUrl = Supabase.instance.client.storage
            .from('files')
            .getPublicUrl(objectPath);
        attachmentType = mime;
      }

      optimistic = Message.optimistic(
        conversationId: widget.conversationId,
        body: text,
        senderId: myId,
        replyToMessageId: replyToId,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      setState(() {
        _pending.add(optimistic!);
        _controller.clear();
        _pendingImage = null;
      });

      final sentMessage = await MessagingService.instance.sendMessage(
        conversationId: widget.conversationId,
        body: hasText ? text : null,
        replyToMessageId: replyToId,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        kind: attachmentUrl != null ? 'media' : 'text',
      );

      setState(() {
        _replyingTo = null;
        final index = _pending.indexWhere((m) => m.id == optimistic!.id);
        if (index >= 0) {
          _pending[index] = sentMessage.copyWith(isOptimistic: true);
        }
      });
    } on MessagingException catch (e) {
      final resolved = await _resolveSentMessage(
        startedAt: startedAt,
        conversationId: widget.conversationId,
        senderId: myId,
      );

      if (resolved != null && optimistic != null) {
        setState(() {
          _replyingTo = null;
          final index = _pending.indexWhere((m) => m.id == optimistic!.id);
          if (index >= 0) {
            _pending[index] = resolved.copyWith(isOptimistic: true);
          }
        });
      } else {
        setState(() {
          if (optimistic != null) {
            _pending.removeWhere((m) => m.id == optimistic!.id);
          }
        });
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message.isNotEmpty ? e.message : loc.failedSendMessage),
          ),
        );
      }
    } catch (e) {
      final resolved = await _resolveSentMessage(
        startedAt: startedAt,
        conversationId: widget.conversationId,
        senderId: myId,
      );

      if (resolved != null && optimistic != null) {
        setState(() {
          _replyingTo = null;
          final index = _pending.indexWhere((m) => m.id == optimistic!.id);
          if (index >= 0) {
            _pending[index] = resolved.copyWith(isOptimistic: true);
          }
        });
      } else {
        setState(() {
          if (optimistic != null) {
            _pending.removeWhere((m) => m.id == optimistic!.id);
          }
        });
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.failedSendMessage)),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }

    if (_scroll.hasClients) {
      await Future.delayed(const Duration(milliseconds: 50));
      // With reverse: true, position 0.0 is the bottom (newest message).
      _scroll.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final previewText = _replyingTo!.body;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.6),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: cs.onPrimaryContainer),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    final isDark = theme.brightness == Brightness.dark;

    // Bubble colors based on theme
    final myBubble = cs.primaryContainer;
    final otherBubble = cs.surfaceContainerHighest;

    final repliedBg = cs.surfaceContainerHighest;
    final repliedBorderMine = cs.primary;
    final repliedBorderOther = cs.outline;

    final pendingImageBg = cs.surfaceContainerHighest;
    final previewCloseBg = Colors.black.withOpacity(isDark ? 0.55 : 0.6);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).conversation)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snapshot) {
                final msgs = [...(snapshot.data ?? const <Message>[])];

                for (final m in msgs) {
                  if (m.id.isNotEmpty) _knownIds.add(m.id);
                }

                final combined = [
                  ...msgs,
                  ..._pending.where((m) => !_knownIds.contains(m.id)),
                ];

                // Sort newest-first so that with reverse: true, the latest
                // message lands at the bottom of the visible area on open.
                combined.sort((a, b) {
                  final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final cmp = bt.compareTo(at);
                  if (cmp != 0) return cmp;
                  return b.id.compareTo(a.id);
                });

                if (snapshot.hasError) {
                  debugPrint('❌ Messaging stream error: ${snapshot.error}');
                }

                // First non-empty emission is the loaded history — reveal everything
                // immediately so we don't show a typing bubble for old messages.
                if (!_seededReveals && msgs.isNotEmpty) {
                  for (final m in msgs) {
                    if (m.id.isNotEmpty) _revealedIds.add(m.id);
                  }
                  _seededReveals = true;
                }

                // Any incoming message from someone else that we haven't revealed
                // yet gets queued behind a typing-indicator delay.
                for (final m in msgs) {
                  if (m.id.isEmpty) continue;
                  if (m.senderId == myId) continue;
                  if (_revealedIds.contains(m.id)) continue;
                  if (_revealTimers.containsKey(m.id)) continue;
                  final id = m.id;
                  final body = m.body;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scheduleReveal(id, _typingDurationFor(body));
                  });
                }

                // Hide queued admin messages from the list until their timer fires.
                final visible = combined.where((m) {
                  if (m.senderId == myId) return true;
                  if (m.id.isEmpty) return true; // safety
                  return _revealedIds.contains(m.id);
                }).toList();

                final showTyping = _revealTimers.isNotEmpty;

                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  itemCount: visible.length + (showTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (showTyping && i == 0) {
                      return _TypingBubble(
                        bubbleColor: otherBubble,
                        dotColor: cs.onSurfaceVariant,
                        borderColor: cs.outlineVariant,
                      );
                    }
                    final m = visible[i - (showTyping ? 1 : 0)];
                    final isMe = m.senderId == myId;
                    final createdAt = _formatTime(m.createdAt);

                    final replyToId = m.replyToMessageId;
                    Message? repliedTo;
                    if (replyToId != null) {
                      for (final msg in combined) {
                        if (msg.id == replyToId) {
                          repliedTo = msg;
                          break;
                        }
                      }
                    }

                    final bubbleBg = isMe ? myBubble : otherBubble;
                    final bubbleText = isMe ? cs.onPrimaryContainer : cs.onSurface;
                    final timeText = cs.onSurfaceVariant;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant, width: 0.6),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (repliedTo != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: repliedBg,
                                  border: Border(
                                    left: BorderSide(
                                      color: isMe ? repliedBorderMine : repliedBorderOther,
                                      width: 3,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  repliedTo.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (m.body.isNotEmpty)
                              SelectableText.rich(
                                TextSpan(
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: bubbleText,
                                  ),
                                  children: _buildMessageSpans(
                                    m.body,
                                    linkStyle: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.primary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: cs.primary,
                                    ),
                                  ),
                                ),
                              ),
                            if (m.attachmentUrl != null && m.attachmentUrl!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: m.body.isNotEmpty ? 8 : 0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: m.attachmentUrl!,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 220,
                                      height: 120,
                                      color: Colors.grey[300],
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 220,
                                      height: 120,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              ),
                            if (m.orderId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Builder(
                                  builder: (context) {
                                    final loc = AppLocalizations.of(context);
                                    return Text(
                                      loc.orderLabel(m.orderId ?? ''),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 11,
                                        color: cs.primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.reply, size: 16, color: timeText),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _replyingTo = m),
                                  tooltip: AppLocalizations.of(context).reply,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  createdAt,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: timeText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined),
                  onPressed: _isSending ? null : _pickImage,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_pendingImage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: pendingImageBg,
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _pendingImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: previewCloseBg,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: cs.onPrimary,
                                      ),
                                      onPressed: _removePendingImage,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildReplyPreview(),
                        TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).typeMessage,
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ],
                    ),
                  ),
                ),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-dot animated bubble shown while a support reply is being "typed".
class _TypingBubble extends StatefulWidget {
  final Color bubbleColor;
  final Color dotColor;
  final Color borderColor;
  const _TypingBubble({
    required this.bubbleColor,
    required this.dotColor,
    required this.borderColor,
  });

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Widget _dot(double phase) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final t = (_ac.value + phase) % 1.0;
        // Triangle wave: 0 → 1 → 0
        final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
        final opacity = 0.3 + 0.7 * wave;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: widget.dotColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.borderColor, width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0.0),
            const SizedBox(width: 4),
            _dot(0.33),
            const SizedBox(width: 4),
            _dot(0.66),
          ],
        ),
      ),
    );
  }
}
