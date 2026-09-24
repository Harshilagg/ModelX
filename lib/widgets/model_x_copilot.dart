import 'dart:ui';
import 'package:flutter/material.dart';
import '../agency/scouting/ai_scout_service.dart';
import '../services/copilot_conversation.dart';
import '../ui/board_theme.dart';
import 'kit/kit.dart';

class ModelXCopilot extends StatefulWidget {
  final Map<String, dynamic> pageContext;
  final Function(List<AiScoutResult>)? onResults;

  /// When set, the launcher is drawn in the board language — an ink
  /// rounded square with the mark in this screen's accent — instead of
  /// the default circular FAB. The brand and agency dashboards still run
  /// on the older theme, so they keep the FAB and are left alone.
  final Color? accent;

  const ModelXCopilot({
    super.key,
    required this.pageContext,
    this.onResults,
    this.accent,
  });

  @override
  State<ModelXCopilot> createState() => _ModelXCopilotState();

  /// Opens the assistant without going through this widget.
  ///
  /// The launcher and the panel were one thing, so the only way to
  /// reach the panel was to mount the launcher. The model side now
  /// draws its own launcher in the nav bar, and the brand and agency
  /// dashboards still use the widget, so the panel has to be reachable
  /// both ways.
  static Future<void> open(
    BuildContext context, {
    required Map<String, dynamic> pageContext,
    Function(List<AiScoutResult>)? onResults,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: 0.82,
        // The same conversation the model side's docked assistant uses.
        // Two panels meant two threads: asking something here and then
        // opening it from the bar started over.
        child: CopilotPanel(
          conversation: CopilotConversation.instance,
          pageContext: pageContext,
          onCollapse: () => Navigator.of(sheet).pop(),
          resultBuilder: onResults == null
              ? null
              : (message) => _ScoutResultsPreview(
                  results: message.results!,
                  onResults: onResults,
                ),
        ),
      ),
    );
  }
}

class _ModelXCopilotState extends State<ModelXCopilot>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _showCopilotSheet() => ModelXCopilot.open(
    context,
    pageContext: widget.pageContext,
    onResults: widget.onResults,
  );

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        if (accent != null) {
          return Semantics(
            button: true,
            label: 'ModelX copilot',
            child: GestureDetector(
              onTap: _showCopilotSheet,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BoardColors.ink,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: BoardColors.ink.withValues(alpha: 0.4),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: _glowAnimation.value / 4,
                    ),
                  ],
                ),
                child: Icon(Icons.auto_awesome, color: accent, size: 20),
              ),
            ),
          );
        }

        // A floating button over a raised keyboard covers the field
        // being typed into, and there is nothing it can usefully do
        // mid-sentence anyway.
        if (MediaQuery.viewInsetsOf(context).bottom > 0) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.4),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value / 4,
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _showCopilotSheet,
            elevation: 4,
            backgroundColor: const Color(0xFF0F172A),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _ScoutResultsPreview extends StatelessWidget {
  final List<AiScoutResult> results;
  final Function(List<AiScoutResult>)? onResults;
  const _ScoutResultsPreview({required this.results, this.onResults});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '✨ Recommended Talent:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: results.length,
            itemBuilder: (context, i) {
              final res = results[i];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: res.profile['profileImage'] != null
                            ? Image.network(
                                res.profile['profileImage'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.person),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        res.profile['fullName'] ?? 'Model',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: () {
            if (onResults != null) onResults!(results);
            // If we are already on scout page, just close the sheet
            Navigator.pop(context);
          },
          child: const Text('Back to results on Scout Page →'),
        ),
      ],
    );
  }
}
