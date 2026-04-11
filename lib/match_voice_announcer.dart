import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'models/player.dart';

class MatchVoiceAnnouncer {
  MatchVoiceAnnouncer() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _isConfigured = false;

  Future<void> _configure() async {
    if (_isConfigured) {
      return;
    }

    try {
      await _tts.setLanguage('en-US');
    } catch (error) {
      debugPrint('MatchVoiceAnnouncer: setLanguage failed: $error');
    }

    try {
      await _tts.setSpeechRate(kIsWeb ? 0.42 : 0.46);
    } catch (error) {
      debugPrint('MatchVoiceAnnouncer: setSpeechRate failed: $error');
    }

    try {
      await _tts.setPitch(1.0);
    } catch (error) {
      debugPrint('MatchVoiceAnnouncer: setPitch failed: $error');
    }

    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (error) {
      debugPrint('MatchVoiceAnnouncer: awaitSpeakCompletion failed: $error');
    }

    _isConfigured = true;
  }

  String buildAnnouncement({
    required List<Player> teamA,
    required List<Player> teamB,
  }) {
    final buffer = StringBuffer('Generated match. ');

    buffer.write('Team A. ');
    for (final player in teamA) {
      buffer.write('${player.name}. ');
    }

    buffer.write('Team B. ');
    for (final player in teamB) {
      buffer.write('${player.name}. ');
    }

    return buffer.toString().trim();
  }

  Future<bool> speakLineup({
    required List<Player> teamA,
    required List<Player> teamB,
  }) async {
    try {
      await _configure();
      await _tts.stop();
      await _tts.speak(buildAnnouncement(teamA: teamA, teamB: teamB));
      return true;
    } catch (error) {
      debugPrint('MatchVoiceAnnouncer: speak failed: $error');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('MatchVoiceAnnouncer: stop failed: $error');
    }
  }
}