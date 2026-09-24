import 'package:flutter/material.dart';

import '../../services/copilot_conversation.dart';
import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';
import 'app_field.dart';
import 'app_metrics.dart';

/// How much of the assistant is showing.
enum CopilotStage {
  /// Nothing. The aperture is just a button.
  closed,

  /// A prompt docked above the bar, with the screen still visible
  /// behind it.
  docked,

  /// The conversation, given the room it needs.
  open,
}

/// The docked prompt: an input and a few openers, above the nav bar.
///
/// Small questions about what is on screen never leave the screen. The
/// aperture stays visible beside it, which is the point of giving it
/// states at all -- a button that shows it is thinking has to be
/// somewhere you can see it.
class CopilotDock extends StatefulWidget {
  final CopilotConversation conversation;
  final Map<String, dynamic> pageContext;

  /// Openers for the screen underneath.
  final List<String> suggestions;

  /// Called when a question is asked, so the shell can grow the surface.
  final VoidCallback onExpand;
  final VoidCallback onDismiss;

  const CopilotDock({
    super.key,
    required this.conversation,
    required this.pageContext,
    required this.suggestions,
    required this.onExpand,
    required this.onDismiss,
  });

  @override
  State<CopilotDock> createState() => _CopilotDockState();
}

class _CopilotDockState extends State<CopilotDock> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Opens with the caret already in the field: the whole point of the
    // docked stage is that a question costs one tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ask(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    // Grow first, so the answer arrives somewhere it can be read.
    widget.onExpand();
    widget.conversation.send(text, widget.pageContext);
  }

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: p.line),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.conversation.hasHistory
                      ? 'Carry on where you left off'
                      : 'Ask about this screen',
                  style: AppType.label(color: p.onSurfaceSoft),
                ),
              ),
              GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  button: true,
                  label: 'Close assistant',
                  child: Icon(Icons.close, size: 18, color: p.onSurfaceFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _controller,
            focusNode: _focus,
            hintText: 'Ask anything',
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: _ask,
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            // One row, scrolled rather than wrapped: the dock has to
            // stay a fixed, small height or it stops being a dock.
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _Opener(
                  label: widget.suggestions[i],
                  onTap: () => _ask(widget.suggestions[i]),
                ),
              ),
            ),
          ],
          if (widget.conversation.hasHistory) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.onExpand,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Open the conversation',
                style: AppType.label(
                  color: p.onSurface,
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Opener extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Opener({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: AppRadii.pill,
          border: Border.all(color: p.lineStrong),
        ),
        child: Text(label, style: AppType.label(color: p.onSurface)),
      ),
    );
  }
}

/// The conversation, once there is one.
class CopilotPanel extends StatefulWidget {
  final CopilotConversation conversation;
  final Map<String, dynamic> pageContext;
  final List<String> suggestions;
  final VoidCallback onCollapse;

  /// Rendered in place of a scouted result list, so the shell decides
  /// what a result looks like.
  final Widget Function(CopilotMessage message)? resultBuilder;

  const CopilotPanel({
    super.key,
    required this.conversation,
    required this.pageContext,
    required this.onCollapse,
    this.suggestions = const [],
    this.resultBuilder,
  });

  @override
  State<CopilotPanel> createState() => _CopilotPanelState();
}

class _CopilotPanelState extends State<CopilotPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.conversation.addListener(_toBottom);
  }

  @override
  void dispose() {
    widget.conversation.removeListener(_toBottom);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Follows the newest turn. Jumps rather than animates when the list
  /// is already long: an animated scroll through a hundred messages
  /// takes longer than reading the answer.
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _ask(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    widget.conversation.send(text, widget.pageContext);
  }

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Column(
        children: [
          _Header(
            conversation: widget.conversation,
            onClose: widget.onCollapse,
          ),
          Divider(color: p.line, height: 1),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.conversation,
              builder: (context, _) {
                final messages = widget.conversation.messages;
                final sending = widget.conversation.sending;

                if (messages.isEmpty && !sending) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppMetrics.gutter),
                      child: Text(
                        'Ask about your profile, a casting, or how something works.',
                        textAlign: TextAlign.center,
                        style: AppType.body(color: p.onSurfaceSoft),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppMetrics.gutter),
                  itemCount: messages.length + (sending ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == messages.length) return const _Thinking();
                    final message = messages[i];
                    if (message.results != null &&
                        widget.resultBuilder != null) {
                      return widget.resultBuilder!(message);
                    }
                    return _Bubble(message: message);
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            conversation: widget.conversation,
            suggestions: widget.suggestions,
            onAsk: _ask,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CopilotConversation conversation;
  final VoidCallback onClose;

  const _Header({required this.conversation, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Assistant',
              style: AppType.heading(color: p.onSurface),
            ),
          ),
          AnimatedBuilder(
            animation: conversation,
            builder: (context, _) => conversation.hasHistory
                ? GestureDetector(
                    onTap: conversation.clear,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Clear',
                        style: AppType.label(color: p.onSurfaceSoft),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              button: true,
              label: 'Close assistant',
              child: SizedBox(
                width: AppMetrics.tapTarget,
                height: AppMetrics.tapTarget,
                child: Icon(Icons.close, size: 20, color: p.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final CopilotMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final mine = message.fromUser;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? p.onSurface : p.surfaceField,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: SelectableText(
            message.text,
            style: AppType.body(color: mine ? p.surface : p.onSurface),
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.surfaceField,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Text('Thinking...', style: AppType.body(color: p.onSurfaceSoft)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final CopilotConversation conversation;
  final List<String> suggestions;
  final ValueChanged<String> onAsk;

  const _Composer({
    required this.controller,
    required this.conversation,
    required this.suggestions,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);

    return AnimatedBuilder(
      animation: conversation,
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppMetrics.gutter,
          8,
          AppMetrics.gutter,
          MediaQuery.viewInsetsOf(context).bottom +
              AppMetrics.bottomInset(context, minimum: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Openers only while the conversation is empty; once it has
            // started they are noise between the answer and the reply.
            if (suggestions.isNotEmpty && !conversation.hasHistory) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _Opener(
                    label: suggestions[i],
                    onTap: () => onAsk(suggestions[i]),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: controller,
                    hintText: 'Ask anything',
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: onAsk,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: conversation.sending
                      ? null
                      : () => onAsk(controller.text),
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    label: 'Send',
                    child: Container(
                      width: AppMetrics.field,
                      height: AppMetrics.field,
                      decoration: BoxDecoration(
                        color: conversation.sending
                            ? p.onSurfaceFaint
                            : p.onSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: p.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
