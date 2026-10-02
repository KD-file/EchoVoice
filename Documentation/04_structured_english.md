# Structured English — EchoVoice

Structured English for the processes in `01_DFD.md`. Only SEQUENCE, IF-THEN-ELSE, and DO WHILE / FOR loops are used.

---

## Process 1.0 — MANAGE SESSION AND TARGET WORDS

```
PROCESS ManageSession
  ON session start:
      READ participant code entered by caregiver
      IF participant code is empty THEN
          DISPLAY "enter participant code"
          EXIT process
      ENDIF
      CREATE new session WITH anonymized session identifier
      LOAD target word metadata FROM D1

  ON word selected:
      SET targetWord = selected word's text
      SET targetPhonemes = selected word's phoneme list
      DISPLAY target word and IPA

  ON "listen" clicked:
      PLAY model audio of targetWord
END PROCESS
```

---

## Process 2.0 — CAPTURE AND PREPROCESS AUDIO

```
PROCESS CaptureAndPreprocess
  IF browser does not support MediaRecorder AND getUserMedia THEN
      DISPLAY "unsupported browser" message
      DISABLE microphone button
      EXIT process
  ENDIF

  ON microphone button clicked:
      IF no word is selected OR a transcription is in progress THEN
          EXIT process
      ENDIF

      IF not currently recording THEN
          REQUEST microphone permission
          IF permission denied THEN
              DISPLAY "please allow microphone access"
              EXIT process
          ENDIF
          START MediaRecorder
          SET status to "listening"
      ELSE
          STOP MediaRecorder
      ENDIF

  ON recording stopped:
      PUT recorded chunks INTO one audio file
      IF audio file is too small THEN
          DISPLAY "didn't hear anything, try again"
          EXIT process
      ENDIF

      CONVERT audio to 16 kHz, mono, 16-bit PCM
      SCALE audio so its peak is -1.0 dBFS
      TRIM silence at the start and end using VAD
      IF nothing is left after trimming THEN
          DISPLAY "didn't hear anything, try again"
          EXIT process
      ENDIF

      PASS standardized audio AND target word TO Process 3.0
END PROCESS
```

---

## Process 3.0 — RECOGNIZE SPEECH (HuBERT-Large)

```
PROCESS RecognizeSpeech
  SET status to "analyzing"
  SEND standardized audio TO backend endpoint /api/transcribe

  IF backend responds successfully THEN
      ON backend:
          RECEIVE audio at FastAPI endpoint
          EXTRACT frame representations (one per 20 ms)
          COMPUTE probability of each grapheme token for each frame
          DECODE CTC output INTO grapheme transcript
      RECEIVE transcript
      IF transcript is empty THEN
          DISPLAY "didn't catch that, try again"
      ELSE
          PASS transcript TO Process 4.0
      ENDIF
  ELSE
      DISPLAY "backend offline" message with error detail
  ENDIF

  RESET status to "ready"
END PROCESS
```

---

## Process 4.0 — SCORE PRONUNCIATION

```
PROCESS ScorePronunciation (transcript)
  IF no word is selected THEN
      EXIT process
  ENDIF

  SET spokenPhonemes = ConvertToPhonemes(transcript)

  COMPUTE werResult = AlignAndScore(targetWord AS words, transcript AS words)
  COMPUTE perResult = AlignAndScore(targetPhonemes, spokenPhonemes)

  SET Np = COUNT(targetPhonemes)
  SET Sp = perResult.substitutions
  SET Dp = perResult.deletions
  SET Ip = perResult.insertions

  IF Np > 0 THEN
      SET Sacc = MAX(0, ((Np − (Sp + Dp + Ip)) / Np) × 100)
  ELSE
      SET Sacc = 0
  ENDIF

  BUILD phoneme error matrix FROM perResult.alignment
  PASS Sacc TO Process 5.0
  PASS PER, WER, Sacc, and error matrix TO Process 6.0
END PROCESS
```

AlignAndScore is the Levenshtein alignment from `05_pseudocode.md`, used for both words and phonemes:

```
PROCESS AlignAndScore (reference[], hypothesis[])
  FILL dp TABLE using the cheapest of deletion, insertion, or match/substitution
  TRACE BACK through dp TO classify each step AS
          correct, substitution, deletion, or insertion
  SET errorRate = IF COUNT(reference) > 0
                      THEN (substitutions + deletions + insertions) / COUNT(reference) × 100
                      ELSE 0
  RETURN errorRate, substitutions, deletions, insertions, alignment
END PROCESS
```

---

## Process 5.0 — GENERATE FEEDBACK

```
PROCESS GenerateFeedback (Sacc)
  IF Sacc >= 90 THEN
      DISPLAY "Very Good!" WITH star animation
  ELSE IF Sacc >= 30 THEN
      DISPLAY encouraging message
  ELSE
      DISPLAY "Let's Practice Together!" WITH replay prompt
  ENDIF
END PROCESS
```

The manuscript gives wording only for 90 to 100 and below 30. The middle band wording (30 to 89) still has to be chosen.

---

## Process 6.0 — STORE SESSION DATA

```
PROCESS StoreSessionData (attemptResults)
  BUILD attempt record WITH
          timestamp, session identifier, target word and IPA,
          transcript, PER, WER, Sacc, Sp, Dp, Ip, alignment
  SAVE attempt record TO SQLite (D2)
  APPEND timestamped entry TO localStorage history (D3)
  IF saving to SQLite fails THEN
      DISPLAY "could not save to server"
  ENDIF
END PROCESS
```

---

## Process 7.0 — GENERATE PROGRESS REPORTS

```
PROCESS GenerateReport (requester)
  READ attempt history FROM D3
  READ session records and phoneme error matrices FROM D2
  IF no attempts exist THEN
      DISPLAY "no attempts to report"
      EXIT process
  ENDIF

  IF requester is caregiver THEN
      COMPUTE star ratings, streaks, and badges
      BUILD Child Progress Report (PDF) WITH stars, streaks, badges,
              and encouraging messages
      EXCLUDE all technical metrics and phoneme error matrices
      SAVE AS PDF
  ELSE IF requester is SLP THEN
      GROUP attempts BY target word
      COMPUTE average PER, average WER, and total Sp, Dp, Ip
      COMPUTE phoneme error matrix AND error-pattern trends

      IF average PER < 15 THEN
          NOTE "meets PER benchmark"
      ELSE
          NOTE "above PER benchmark, review with SLP"
      ENDIF
      IF average WER < 20 THEN
          NOTE "meets WER benchmark"
      ELSE
          NOTE "above WER benchmark, review with SLP"
      ENDIF

      BUILD Clinician Report (PDF) WITH session metrics, error matrix,
              trends, session history, and notes
      EXPORT same data AS CSV
  ENDIF

  SHOW only the anonymized session identifier in the report
  DISPLAY "report downloaded"
END PROCESS
```

PER below 15 and WER below 20 are engineering benchmarks from the manuscript. They are not clinical standards.
