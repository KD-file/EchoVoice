/// Custom exception hierarchy for EchoVoice.
///
/// Using a dedicated hierarchy (rather than throwing raw `Exception` or
/// `String` values) lets callers catch specific failure modes and decide
/// how to recover, which is central to defensive programming: failures
/// are anticipated, typed, and handled deliberately rather than allowed
/// to propagate as generic, unactionable errors.
library echovoice.exceptions;

/// Base type for all EchoVoice-specific exceptions.
///
/// Callers can catch this type to handle any EchoVoice failure generically,
/// or catch a specific subtype below to handle a particular failure mode.
abstract class EchoVoiceException implements Exception {
  final String message;
  final Object? cause;

  const EchoVoiceException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message'
      '${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Thrown when audio capture fails (e.g., microphone permission denied,
/// device has no working microphone, or recording was interrupted).
class AudioCaptureException extends EchoVoiceException {
  const AudioCaptureException(super.message, {super.cause});
}

/// Thrown when the on-device ASR model cannot be loaded or fails during
/// inference (e.g., corrupted model file, unsupported device architecture,
/// out-of-memory during inference).
class ModelInferenceException extends EchoVoiceException {
  const ModelInferenceException(super.message, {super.cause});
}

/// Thrown when phoneme alignment cannot be completed, for example because
/// the predicted phoneme sequence or the reference target sequence is
/// empty or malformed.
class PhonemeAlignmentException extends EchoVoiceException {
  const PhonemeAlignmentException(super.message, {super.cause});
}

/// Thrown when a local database read/write fails.
class LocalStorageException extends EchoVoiceException {
  const LocalStorageException(super.message, {super.cause});
}

/// Thrown when input validation fails (e.g., a caller passes an
/// out-of-range value, a null where one is not permitted, or a
/// malformed configuration object).
class ValidationException extends EchoVoiceException {
  const ValidationException(super.message, {super.cause});
}
