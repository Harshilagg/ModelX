import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/ai_copilot_service.dart';
import '../agency/scouting/ai_scout_service.dart';
import '../agency/scouting/scout_page.dart';

class ModelXCopilot extends StatefulWidget {
  final Map<String, dynamic> pageContext;
  final Function(List<AiScoutResult>)? onResults;

  const ModelXCopilot({
    super.key,
    required this.pageContext,
    this.onResults,
  });

  @override
  State<ModelXCopilot> createState() => _ModelXCopilotState();
}

class _ModelXCopilotState extends State<ModelXCopilot> with TickerProviderStateMixin {
  final AiCopilotService _copilotService = AiCopilotService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showCopilotSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CopilotPanel(
        pageContext: widget.pageContext,
        copilotService: _copilotService,
        onResults: widget.onResults,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.4),
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

class _CopilotPanel extends StatefulWidget {
  final Map<String, dynamic> pageContext;
  final AiCopilotService copilotService;
  final Function(List<AiScoutResult>)? onResults;

  const _CopilotPanel({
    required this.pageContext,
    required this.copilotService,
    this.onResults,
  });

  @override
  State<_CopilotPanel> createState() => _CopilotPanelState();
}

class _CopilotPanelState extends State<_CopilotPanel> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _chat = [];
  bool _isLoading = false;

  void _handleSend([String? forcedQuery]) async {
    final query = forcedQuery ?? _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _chat.add({'role': 'user', 'content': query});
      _isLoading = true;
      _controller.clear();
    });

    try {
      final response = await widget.copilotService.handleRequest(query, widget.pageContext);
      
      // If results were found, trigger callback immediately
      if (response is List<AiScoutResult> && widget.onResults != null) {
        widget.onResults!(response);
      } else if (response is List && widget.onResults != null) {
        // Try to cast if it's actually compatible
        try {
           final results = response.cast<AiScoutResult>().toList();
           widget.onResults!(results);
        } catch (e) {
           // Silently ignore if cast fails (it's likely not a search result list)
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _chat.add({'role': 'assistant', 'content': response});
        });
        
        // Auto-close sheet if on scout page to show results immediately (with a tiny delay for feel)
        if (response is List<AiScoutResult> && widget.pageContext['page'] == 'scout') {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _chat.add({'role': 'assistant', 'content': 'Error: $e'});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF0F172A), size: 20),
                    const SizedBox(width: 10),
                    const Text('ModelX Copilot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(),

              // Chat Area
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _chat.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _chat.length) {
                      return const Align(alignment: Alignment.centerLeft, child: _TypingIndicator());
                    }
                    final msg = _chat[index];
                    final isUser = msg['role'] == 'user';
                    
                    if (!isUser && msg['content'] is List<AiScoutResult>) {
                       return _ScoutResultsPreview(
                         results: msg['content'] as List<AiScoutResult>,
                         onResults: widget.onResults,
                       );
                    }

                    return _ChatBubble(message: msg['content'].toString(), isUser: isUser);
                  },
                ),
              ),

              // Contextual Quick Actions (Pills)
              _QuickActions(
                page: widget.pageContext['page'] ?? 'home',
                role: widget.pageContext['role'] ?? 'Model',
                onAction: _handleSend,
              ),

              // Input Bar
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(hintText: 'Ask anything...', border: InputBorder.none),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      IconButton(
                        onPressed: _handleSend,
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  const _ChatBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF0F172A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final String page;
  final String role;
  final Function(String) onAction;
  const _QuickActions({required this.page, required this.role, required this.onAction});

  @override
  Widget build(BuildContext context) {
    List<String> actions = [];
    // Normalize role: User is a Model
    final String normalizedRole = (role == 'User') ? 'Model' : role;
    final bool isBrandOrAgency = normalizedRole == 'Brand' || normalizedRole == 'Agency';

    if (page == 'scout') {
      actions = ['Find models for luxury campaign', 'Discover top talent'];
    } else if (page == 'profile') {
      actions = normalizedRole == 'Model' 
          ? ['Analyze my bio', 'Improve my skills', 'Profile tips']
          : ['View my postings', 'Company profile tips'];
    } else if (page == 'chat') {
      actions = ['Suggest reply', 'Draft outreach message'];
    } else {
      // Home / Dashboard
      if (normalizedRole == 'Model') {
        actions = ['How to get hired?', 'Portfolio tips', 'Navigating the app'];
      } else {
        actions = ['How to scout models?', 'Posting a gig', 'Hiring tips'];
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: actions.map((a) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(a, style: const TextStyle(fontSize: 12)),
            onPressed: () => onAction(a),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey[300]!),
          ),
        )).toList(),
      ),
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
          child: Text('✨ Recommended Talent:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: res.profile['profileImage'] != null 
                          ? Image.network(res.profile['profileImage'], fit: BoxFit.cover, width: double.infinity)
                          : Container(color: Colors.grey[200], child: const Icon(Icons.person)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(res.profile['fullName'] ?? 'Model', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )
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
        )
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('Copilot is thinking...', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
    );
  }
}
