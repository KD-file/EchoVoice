EchoVoice — Design Documentation

# EchoVoice — Pseudocode

*Aligned with Chapter 1 & 2, the Structure Chart, and the DFD control flags. Goal configuration and progress review are Caregiver inputs; the Speech-Language Pathologist is an **external** clinical validator only.*

## 0.0 EchoVoice Main Control Module

BEGIN MainControl

  INITIALIZE session

  WHILE session is active DO

    exerciseSelection ← GET caregiver's exercise selection

    targetWord, selectionAccepted ← CALL ManageExercise(exerciseSelection)

    IF selectionAccepted = TRUE THEN

      startRecordingFlag ← TRUE

      recordedSpeech, recordingCompleteFlag ← CALL CaptureSpeech(targetWord, startRecordingFlag)

      IF recordingCompleteFlag = TRUE THEN

        assessmentResult ← CALL SpeechRecognitionAndAssessment(recordedSpeech, targetWord)

        // 3.4 writes the Assessment Record to D1 internally

        CALL GenerateFeedback(assessmentResult)

      ELSE

        DISPLAY "No response detected"

        CONTINUE WHILE

      END IF

    ELSE

      DISPLAY "Selection rejected — please choose a valid exercise"

      CONTINUE WHILE

    END IF

    IF caregiver sends Goal Configuration / Progress Review input THEN

      caregiverInput ← GET input FROM Caregiver

      updateStatusFlag ← CALL ConfigureGoalsAndReview(caregiverInput)

      DISPLAY updateStatusFlag TO Caregiver

    END IF

    IF learner OR caregiver ENDS session THEN

      EXIT WHILE

    END IF

  END WHILE

  reportRequestFlag ← GET caregiver's export request (if any)

  sessionProgressSummary, longitudinalProgressReport ← CALL MonitorProgress(reportRequestFlag)

  DISPLAY sessionProgressSummary TO Caregiver

  IF reportRequestFlag = TRUE THEN

    MAKE longitudinalProgressReport AVAILABLE TO Caregiver (to share with an external clinician)

  END IF

END MainControl

## 1.0 Manage Exercise

BEGIN ManageExercise(exerciseSelection)

  activeGoals ← READ D2 (Goal Config Store)

  IF exerciseSelection IS VALID AND CONSISTENT WITH activeGoals THEN

    targetWord, targetPhonemeSequence ← DETERMINE target word FOR exerciseSelection

    RETURN targetWord, selectionAccepted = TRUE

  ELSE

    REJECT exerciseSelection

    PROMPT Caregiver TO choose a valid exercise

    RETURN targetWord = NULL, selectionAccepted = FALSE

  END IF

END ManageExercise

## 2.0 Capture Speech

BEGIN CaptureSpeech(targetWord, startRecordingFlag)

  DISPLAY visualPrompt(targetWord)

  PLAY auditoryPrompt(targetWord)

  IF startRecordingFlag = TRUE THEN

    OPEN microphone stream

    WAIT FOR speech input FROM learner UNTIL timeout

    IF speech input IS RECEIVED WITHIN timeout THEN

      recordedSpeech ← RECORD speech input AS rawAudioFile (.wav)

      recordingCompleteFlag ← TRUE

    ELSE

      FLAG no-response event

      recordedSpeech ← NULL

      recordingCompleteFlag ← FALSE

      // control returns to 1.0 Manage Exercise, per Structured English

    END IF

    CLOSE microphone stream

  ELSE

    recordingCompleteFlag ← FALSE

  END IF

  RETURN recordedSpeech, recordingCompleteFlag

END CaptureSpeech

## 3.0 Speech Recognition & Assessment (Orchestrator)

BEGIN SpeechRecognitionAndAssessment(recordedSpeech, targetWord)

  rawAudioFile ← recordedSpeech

  spectrogramTensors ← CALL ExtractAcousticFeatures(rawAudioFile)

  predictedPhonemeSequence, inferenceStatusFlag ← CALL RunModelInference(spectrogramTensors)

  IF inferenceStatusFlag ≠ SUCCESS THEN

    RETURN assessmentResult = ERROR("Recognition failed — please retry")

  END IF

  phonemeErrorMatrix ← CALL AlignPhonemes(predictedPhonemeSequence, targetWord)

  // 3.3 reads D3 (Phoneme Target Dictionary) internally

  assessmentResult ← CALL ComputePronunciationScore(phonemeErrorMatrix)

  // 3.4 writes the Assessment Record to D1 internally

  RETURN assessmentResult

END SpeechRecognitionAndAssessment

## 3.1 Extract Acoustic Features

BEGIN ExtractAcousticFeatures(rawAudioFile)

  audioSignal ← LOAD rawAudioFile

  audioSignal ← NORMALIZE(audioSignal)

  audioSignal ← REMOVE silence/noise (pre-emphasis, trimming)

  spectrogram ← COMPUTE mel-spectrogram(audioSignal, frameSize, hopLength)

  spectrogramTensors ← CONVERT spectrogram TO tensor format expected by ASR model

  RETURN spectrogramTensors

END ExtractAcousticFeatures

## 3.2 Run Model Inference

BEGIN RunModelInference(spectrogramTensors)

  TRY

    LOAD compressed on-device ASR model (if not already resident in memory)

    modelOutput ← model.PREDICT(spectrogramTensors)

    predictedPhonemeSequence ← DECODE(modelOutput) INTO phoneme sequence

    inferenceStatusFlag ← SUCCESS

  CATCH inferenceError

    predictedPhonemeSequence ← NULL

    inferenceStatusFlag ← FAILURE

  END TRY

  RETURN predictedPhonemeSequence, inferenceStatusFlag

END RunModelInference

## 3.3 Align Phonemes

BEGIN AlignPhonemes(predictedPhonemeSequence, targetWord)

  targetPhonemeTemplate ← READ D3 (Phoneme Target Dictionary) USING targetWord

  alignmentMatrix ← INITIALIZE matrix[LENGTH(targetPhonemeTemplate)+1][LENGTH(predictedPhonemeSequence)+1]

  // Dynamic-programming alignment (edit-distance style, e.g. Needleman-Wunsch)

  FOR i FROM 0 TO LENGTH(targetPhonemeTemplate) DO

    FOR j FROM 0 TO LENGTH(predictedPhonemeSequence) DO

      IF i = 0 THEN alignmentMatrix[i][j] ← j

      ELSE IF j = 0 THEN alignmentMatrix[i][j] ← i

      ELSE IF targetPhonemeTemplate[i] = predictedPhonemeSequence[j] THEN

        alignmentMatrix[i][j] ← alignmentMatrix[i-1][j-1]

      ELSE

        RECORD mismatch

        alignmentMatrix[i][j] ← 1 + MIN(

          alignmentMatrix[i-1][j],     // deletion

          alignmentMatrix[i][j-1],     // insertion

          alignmentMatrix[i-1][j-1])   // substitution

      END IF

    END FOR

  END FOR

  phonemeErrorMatrix ← BACKTRACE alignmentMatrix

    TAGGING each phoneme as MATCH / SUBSTITUTION / INSERTION / DELETION

  RETURN phonemeErrorMatrix

END AlignPhonemes

## 3.4 Compute Pronunciation Score

BEGIN ComputePronunciationScore(phonemeErrorMatrix)

  totalPhonemes ← COUNT(phonemeErrorMatrix)

  errorCount ← COUNT(entries IN phonemeErrorMatrix WHERE tag ≠ MATCH)

  phonemeErrorRate ← errorCount / totalPhonemes

  accuracyScore ← (1 – phonemeErrorRate) × 100

  FOR EACH phoneme IN phonemeErrorMatrix DO

    SET phoneme.score BASED ON tag (MATCH = full credit, SUBSTITUTION = partial, INSERTION/DELETION = none)

  END FOR

  assessmentResult ← {

    targetWord,

    accuracyScore,

    phonemeErrorRate,

    phonemeLevelBreakdown ← phonemeErrorMatrix,

    timestamp ← CURRENT_TIME()

  }

  WRITE assessmentResult TO D1 (Progress Database) AS assessmentRecord

  RETURN assessmentResult

END ComputePronunciationScore

## 4.0 Generate Feedback

BEGIN GenerateFeedback(assessmentResult)

  IF assessmentResult INDICATES correct/acceptable pronunciation THEN

    GENERATE positive visualAuditoryPrompts

  ELSE IF assessmentResult INDICATES minor errors THEN

    GENERATE corrective visualAuditoryPrompts HIGHLIGHTING the mispronounced phoneme(s)

  ELSE

    GENERATE encouraging retry visualAuditoryPrompts

    SUGGEST simplified variant of exercise

  END IF

  SEND visualAuditoryPrompts TO Learner

  RETURN visualAuditoryPrompts

END GenerateFeedback

## 5.0 Monitor Progress

*Takes reportRequestFlag as a parameter and only compiles the exportable longitudinal report when it is TRUE, matching the "IF report requested" branch on the Structure Chart.*

BEGIN MonitorProgress(reportRequestFlag)

  storedProgress ← READ D1 (Progress Database)

  sessionProgressSummary ← COMPUTE FROM storedProgress FOR current session

    (attempts this session, average accuracy, simple takeaway)

  SEND sessionProgressSummary TO Caregiver

  longitudinalProgressReport ← NULL

  IF reportRequestFlag = TRUE THEN

    longitudinalProgressReport ← COMPUTE FROM storedProgress (trends across sessions)

      (full accuracy history, most-missed phonemes, trend lines)

    SEND longitudinalProgressReport TO Caregiver (for sharing with an external clinician)

  END IF

  RETURN sessionProgressSummary, longitudinalProgressReport

END MonitorProgress

## 6.0 Configure Goals & Review Assessment

*Returns an explicit updateStatusFlag reflecting whether the goal write to D2 succeeded, matching the "IF goal update submitted" branch on the Structure Chart. Input is from the Caregiver.*

BEGIN ConfigureGoalsAndReview(caregiverInput)

  updateStatusFlag ← NULL

  IF caregiverInput.type = "Goal Configuration" THEN

    IF VALIDATE(caregiverInput.goalParameters) = TRUE THEN

      WRITE caregiverInput.goalParameters TO D2 (Goal Config Store)

      updateStatusFlag ← SUCCESS

      RETURN updateStatusFlag, CONFIRMATION "Goals updated"

    ELSE

      updateStatusFlag ← FAILURE

      RETURN updateStatusFlag, ERROR "Invalid goal configuration — please review entries"

    END IF

  ELSE IF caregiverInput.type = "Progress Review" THEN

    READ storedProgress ← D1 (Progress Database)

    REVIEW assessment data

    // used for progress review / reporting only — no store update

    RETURN updateStatusFlag = N/A, CONFIRMATION "Review presented"

  END IF

END ConfigureGoalsAndReview
