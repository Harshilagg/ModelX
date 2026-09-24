import 'package:flutter/foundation.dart';

import '../agency/scouting/ai_scout_service.dart';
import 'ai_copilot_service.dart';

/// One turn of the conversation.
class CopilotMessage {
  final bool fromUser;
  final String text;

  /// Set when the reply is a list of scouted models rather than prose.
  final List<AiScoutResult>? results;

  const CopilotMessage.user(this.text) : fromUser = true, results = null;

  const CopilotMessage.assistant(this.text, {this.results}) : fromUser = false;
}

/// The assistant's conversation, kept alive across the app.
///
/// It used to live on the panel widget, so closing the panel destroyed
/// it: every reopen started from nothing, and stepping away to look at
/// the thing you were asking about lost the thread. That is also what
/// made the panel have to be modal -- there was nothing to come back
/// to. Holding it here is what lets the assistant be dismissed and
/// resumed.
///
/// Deliberately not persisted to disk. A conversation about what is on
/// screen goes stale the moment the app is relaunched, and keeping it
/// would mean storing what a user asked about their own profile.
class CopilotConversation extends ChangeNotifier {
  CopilotConversation({AiCopilotService? service}) : _injected = service;

  /// The app has no dependency injection, so one instance is shared.
  /// Tests build their own with a stub service.
  static final CopilotConversation instance = CopilotConversation();

  final AiCopilotService? _injected;
  AiCopilotService? _resolved;

  /// Built on the first question rather than with the conversation.
  ///
  /// The service reaches Firestore as it is constructed, so building it
  /// eagerly meant the assistant did that work at app start whether or
  /// not anyone opened it -- and made the conversation impossible to
  /// construct at all without a Firebase app.
  AiCopilotService get _service =>
      _injected ?? (_resolved ??= AiCopilotService());

  final List<CopilotMessage> _messages = [];

  bool _sending = false;

  List<CopilotMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get isEmpty => _messages.isEmpty;

  /// True once there is something worth coming back to, which is what
  /// decides whether opening the assistant shows the prompt or the
  /// conversation.
  bool get hasHistory => _messages.isNotEmpty;

  Future<void> send(String query, Map<String, dynamic> pageContext) async {
    final text = query.trim();
    if (text.isEmpty || _sending) return;

    _messages.add(CopilotMessage.user(text));
    _sending = true;
    notifyListeners();

    try {
      final response = await _service.handleRequest(text, pageContext);
      _messages.add(_interpret(response));
    } catch (e) {
      _messages.add(
        CopilotMessage.assistant(
          'Something went wrong reaching the assistant. Please try again.',
        ),
      );
      debugPrint('CopilotConversation: $e');
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// The service returns prose, a list of scouted models, or something
  /// close enough to one to be worth trying.
  CopilotMessage _interpret(dynamic response) {
    if (response is List<AiScoutResult>) {
      return CopilotMessage.assistant(
        '${response.length} ${response.length == 1 ? 'model' : 'models'} found.',
        results: response,
      );
    }
    if (response is List) {
      try {
        final results = response.cast<AiScoutResult>().toList();
        return CopilotMessage.assistant(
          '${results.length} found.',
          results: results,
        );
      } catch (_) {
        // Not a result list after all; fall through to prose.
      }
    }
    return CopilotMessage.assistant(response.toString());
  }

  void clear() {
    _messages.clear();
    _sending = false;
    notifyListeners();
  }
}
