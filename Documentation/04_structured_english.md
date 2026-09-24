# Structured English — EchoVoice

Structured English versions of the DFD's primitive processes, using only
SEQUENCE, IF‑THEN‑ELSE, and DO WHILE/DO UNTIL constructs (no free-form prose),
per Gane–Sarson process-specification conventions.

---

## Process 2.0 — CAPTURE AND TRANSCRIBE SPEECH ATTEMPT

```
PROCESS CaptureAndTranscribe
  IF browser does not support MediaRecorder AND getUserMedia THEN
      DISPLAY "unsupported browser" banner
      DISABLE microphone button
      EXIT process
  ENDIF

  ON microphone button clicked:
      IF no word is selected OR a transcription is already in progress THEN
          EXIT process
      ENDIF

      IF not currently recording THEN
          REQUEST microphone permission
          IF permission denied THEN
              DISPLAY toast "please allow microphone access"
              EXIT process
          ENDIF
          START MediaRecorder
          SET recording status to "listening"
      ELSE
          STOP MediaRecorder
      ENDIF

  ON recording stopped:
      ASSEMBLE recorded chunks INTO audio blob
      IF audio blob size < 500 bytes THEN
          DISPLAY toast "didn't hear anything, try again"
          EXIT process
      ENDIF

      SET status to "analyzing"
      SEND audio blob TO backend endpoint /api/transcribe

      IF backend responds successfully THEN
          RECEIVE spokenText
          IF spokenText is empty THEN
              DISPLAY toast "didn't catch that, try again"
          ELSE
              CALL AnalyzeAttempt(spokenText)
          ENDIF
      ELSE
          DISPLAY "backend offline" banner
          DISPLAY toast with error detail
      ENDIF

      RESET status to "ready"
END PROCESS
```

---

## Process 3.0 — COMPUTE ASSESSMENT METRICS (`AnalyzeAttempt`)

```
PROCESS AnalyzeAttempt (spokenText)
  IF no word is selected THEN
      EXIT process
  ENDIF

  SET targetWord      = selected word's text
  SET targetPhonemes  = selected word's phoneme list
  SET spokenPhonemes  = ConvertToPhonemes(spokenText)

  COMPUTE werResult = AlignAndScore(targetWord AS words, spokenText AS words)
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

  DISPLAY target word, spoken text, and the six metric cards
          (Sacc, WER, PER, substitutions, deletions, insertions)
  RENDER phoneme alignment chips from perResult.alignment

  BUILD attempt record WITH
          timestamp, child name, child age, target word/IPA,
          spoken text, target/spoken phonemes, WER, PER, Sacc,
          Sp, Dp, Ip, alignment
  APPEND attempt record TO session history
  SAVE session history TO local storage

  IF Sacc >= 90 THEN
      DISPLAY toast "perfect pronunciation"
  ELSE IF Sacc >= 70 THEN
      DISPLAY toast "great job"
  ELSE IF Sacc >= 50 THEN
      DISPLAY toast "good try"
  ELSE
      DISPLAY toast "listen carefully and try again"
  ENDIF

  REFRESH word grid to mark this word as tested
END PROCESS
```

---

## Process — ALIGN AND SCORE (shared by WER and PER)

```
PROCESS AlignAndScore (reference[], hypothesis[])
  SET refLen = COUNT(reference)
  SET hypLen = COUNT(hypothesis)

  INITIALIZE dp TABLE of size (refLen+1) BY (hypLen+1)
  FOR i = 0 TO refLen: SET dp[i][0] = i
  FOR j = 0 TO hypLen: SET dp[0][j] = j

  FOR i = 1 TO refLen
      FOR j = 1 TO hypLen
          IF reference[i] EQUALS hypothesis[j] THEN
              SET cost = 0
          ELSE
              SET cost = 1
          ENDIF
          SET dp[i][j] = MIN(
              dp[i-1][j]   + 1,     -- deletion
              dp[i][j-1]   + 1,     -- insertion
              dp[i-1][j-1] + cost   -- match or substitution
          )
      ENDFOR
  ENDFOR

  TRACE BACK through dp FROM (refLen, hypLen) TO (0,0)
      CLASSIFYING each step AS correct, substitution, deletion, or insertion
      BUILDING an ordered alignment list

  SET errorRate = IF refLen > 0
                      THEN (substitutions+deletions+insertions) / refLen × 100
                      ELSE 0

  RETURN errorRate, substitutions, deletions, insertions, alignment
END PROCESS
```

---

## Process 5.0 — GENERATE ASSESSMENT REPORT

```
PROCESS GenerateReport
  IF session history is empty THEN
      DISPLAY toast "No data to generate report!"
      EXIT process
  ENDIF

  GROUP session history entries BY target word
  FOR EACH word group
      COMPUTE average accuracy, average WER, average PER,
              and total substitutions/deletions/insertions
  ENDFOR

  COMPUTE avgPER  = MEAN of all attempts' PER
  COMPUTE avgWER  = MEAN of all attempts' WER
  COMPUTE totalSubs, totalDels, totalIns ACROSS all attempts

  BUILD clinical interpretation notes:
      IF avgPER <= 15  THEN note "within target threshold"
      ELSE IF avgPER <= 30 THEN note "moderate, practice recommended"
      ELSE note "exceeds 30%, clinical consultation advised"

      IF avgWER <= 20 THEN note "acceptable word-level recognition"
      ELSE note "further evaluation recommended"

      IF totalSubs > (totalDels + totalIns) THEN
          note "substitutions predominant — articulatory placement difficulty"
      ENDIF
      IF totalDels > totalSubs THEN
          note "deletions elevated — possible omission pattern"
      ENDIF

  RENDER PDF WITH header, summary table, detailed attempt log,
             interpretation notes, ICC reference scale, footer
  SAVE PDF AS "EchoVoice_Report_<childName>_<sessionDate>.pdf"
  DISPLAY toast "PDF report downloaded"
END PROCESS
```
