// lib/services/voice_structuring_service.dart
//
// STT (speech_to_text) wrapper + AI structuring orchestration για το
// "Smart Voice" flow (Pro v1.1 Wave 2).
//
// Παρέχει live transcription και delegates στο AiAssistantService για
// structuring (transcript → VoiceStructureResult με τύπο checklist/text/
// reminder). Default locale: el_GR. Override για άλλη γλώσσα στο widget.

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'ai_assistant_service.dart';

class VoiceStructuringService {
  VoiceStructuringService._();
  static final instance = VoiceStructuringService._();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  String? _lastError;

  String? get lastError => _lastError;
  bool get isListening => _stt.isListening;
  bool get isAvailable => _stt.isAvailable;

  /// Initialize STT engine. Returns true αν είναι διαθέσιμο + permission OK.
  /// Optional callbacks για status/error events.
  Future<bool> initialize({
    void Function(String status)? onStatusChange,
    void Function(String error)? onError,
  }) async {
    if (_initialized && _stt.isAvailable) return true;
    _lastError = null;
    try {
      _initialized = await _stt.initialize(
        onStatus: (s) => onStatusChange?.call(s),
        onError: (SpeechRecognitionError e) {
          _lastError = e.errorMsg;
          onError?.call(e.errorMsg);
        },
      );
    } catch (e) {
      _lastError = e.toString();
      _initialized = false;
    }
    return _initialized;
  }

  /// Start listening. Στέλνει partial + final transcripts στο [onResult].
  /// [isFinal] είναι true στο τελικό αποτέλεσμα μετά από pause/stop.
  /// Επιστρέφει false αν αποτύχει η εκκίνηση.
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevel,
    String localeId = 'el_GR',
    Duration listenFor = const Duration(seconds: 90),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    try {
      await _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        onSoundLevelChange:
            onSoundLevel == null ? null : (level) => onSoundLevel(level),
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Σταματάει αμέσως, διατηρεί το τελευταίο transcript.
  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
  }

  /// Ακυρώνει χωρίς να επιστρέψει transcript.
  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
  }

  /// Στέλνει το transcript στο AI για structuring.
  /// Επιστρέφει null σε αποτυχία AI ή κενό transcript.
  Future<VoiceStructureResult?> structure(String transcript) {
    return AiAssistantService.instance.structureVoiceInput(transcript);
  }
}