# Pseudocode — EchoVoice

Language-neutral pseudocode for the algorithmically interesting modules.
Frontend items correspond to functions in `index.html`; backend items
correspond to `Source_Code/app.py`.

---

## 1. Frontend: `startRecording` / `stopRecording` / `handleRecordedAudio`

```
FUNCTION startRecording()
    stream ← AWAIT getUserMedia({ audio: true })
    chunks ← empty list
    mimeType ← first of ["audio/webm","audio/ogg","audio/mp4"] supported by MediaRecorder
    recorder ← NEW MediaRecorder(stream, mimeType)

    recorder.onDataAvailable ← (data) => IF data.size > 0 THEN chunks.append(data)
    recorder.onStop ← () =>
        stop all tracks in stream
        blob ← Blob(chunks, type = mimeType)
        CALL handleRecordedAudio(blob)

    recorder.start()
    isRecording ← TRUE
    UPDATE UI to "listening" state
END FUNCTION

FUNCTION stopRecording()
    isRecording ← FALSE
    IF recorder.state ≠ "inactive" THEN recorder.stop()   -- fires onStop above
END FUNCTION

FUNCTION handleRecordedAudio(blob)
    IF blob.size < 500 THEN
        UPDATE UI to "ready" state
        SHOW toast("didn't hear anything")
        RETURN
    ENDIF

    isProcessing ← TRUE
    UPDATE UI to "analyzing" state
    TRY
        transcript ← AWAIT TranscribeWithBackend(blob)
        IF transcript = "" THEN
            SHOW toast("didn't catch that")
        ELSE
            CALL AnalyzeAttempt(transcript)
        ENDIF
    CATCH networkError
        SHOW backendOfflineBanner
        SHOW toast("could not reach ASR backend: " + networkError.message)
    FINALLY
        isProcessing ← FALSE
        UPDATE UI to "ready" state
    END TRY
END FUNCTION

FUNCTION TranscribeWithBackend(blob) RETURNS string
    form ← multipart form with field "audio" = blob
    response ← AWAIT HTTP POST (BACKEND_URL + "/api/transcribe", form)
    IF response.status ≠ 200 THEN
        THROW Error(response.body.detail OR response.statusText)
    ENDIF
    RETURN response.body.transcript
END FUNCTION
```

---

## 2. Backend: `/api/transcribe` request handler

```
ENDPOINT POST /api/transcribe (file: audio)
    rawBytes ← READ(audio)
    IF rawBytes is empty THEN RETURN 400 "empty audio upload"

    TRY
        waveform ← DecodeAudio(rawBytes)     -- see below
    CATCH decodeError
        RETURN 400 "could not decode audio: " + decodeError
    END TRY

    IF waveform.length = 0 THEN RETURN 400 "decoded audio was empty"

    inputs      ← processor(waveform, samplingRate = 16000)
    logits      ← model.forward(inputs.input_values)        -- no gradient
    predictedIds ← ARGMAX(logits, axis = vocabulary)
    transcript  ← processor.batch_decode(predictedIds)[0].strip().lower()

    RETURN 200 { transcript, model_source, fine_tuned }
END ENDPOINT

FUNCTION DecodeAudio(rawBytes) RETURNS float32[] waveform @16kHz mono
    TRY
        (waveform, sampleRate) ← soundfile.read(rawBytes)     -- wav/flac
    CATCH
        write rawBytes to temp file (.webm)
        (waveform, sampleRate) ← librosa.load(tempFile, mono = TRUE)  -- webm/opus etc.
    END TRY

    IF waveform has more than one channel THEN
        waveform ← MEAN(waveform, across channels)
    ENDIF

    IF sampleRate ≠ 16000 THEN
        waveform ← librosa.resample(waveform, sampleRate → 16000)
    ENDIF

    RETURN waveform AS float32
END FUNCTION
```

---

## 3. Backend: model load at startup

```
FUNCTION LoadModel()
    IF directory ECHOVOICE_MODEL_DIR exists AND is non-empty THEN
        modelSource ← ECHOVOICE_MODEL_DIR       -- fine-tuned checkpoint
        fineTuned   ← TRUE
    ELSE
        modelSource ← "facebook/hubert-large-ls960-ft"   -- fallback
        fineTuned   ← FALSE
        LOG WARNING "no fine-tuned checkpoint found, using base model"
    ENDIF

    processor ← AutoProcessor.fromPretrained(modelSource)
    model     ← AutoModelForCTC.fromPretrained(modelSource)
    model.to(device)                -- GPU if available, else CPU
    model.eval()

    RETURN processor, model, modelSource, fineTuned
END FUNCTION
```

---

## 4. Frontend: Levenshtein alignment (shared by WER and PER)

```
FUNCTION LevenshteinAlign(reference[1..n], hypothesis[1..m]) RETURNS {subs, dels, ins, alignment[]}
    ALLOCATE dp[0..n][0..m]
    FOR i = 0 TO n: dp[i][0] ← i
    FOR j = 0 TO m: dp[0][j] ← j

    FOR i = 1 TO n
        FOR j = 1 TO m
            cost ← 0 IF reference[i] = hypothesis[j] ELSE 1
            dp[i][j] ← MIN(
                dp[i-1][j]   + 1,     -- deletion
                dp[i][j-1]   + 1,     -- insertion
                dp[i-1][j-1] + cost   -- match / substitution
            )
        END FOR
    END FOR

    -- backtrack from (n, m) to (0, 0)
    i ← n, j ← m
    alignment ← empty list
    subs ← dels ← ins ← 0

    WHILE i > 0 OR j > 0
        IF i > 0 AND j > 0 AND reference[i] = hypothesis[j] AND dp[i][j] = dp[i-1][j-1] THEN
            PREPEND {type: "correct", ref: reference[i], hyp: hypothesis[j]} TO alignment
            i ← i - 1; j ← j - 1
        ELSE IF i > 0 AND j > 0 AND dp[i][j] = dp[i-1][j-1] + 1 THEN
            PREPEND {type: "substitution", ref: reference[i], hyp: hypothesis[j]} TO alignment
            subs ← subs + 1; i ← i - 1; j ← j - 1
        ELSE IF i > 0 AND dp[i][j] = dp[i-1][j] + 1 THEN
            PREPEND {type: "deletion", ref: reference[i]} TO alignment
            dels ← dels + 1; i ← i - 1
        ELSE
            PREPEND {type: "insertion", hyp: hypothesis[j]} TO alignment
            ins ← ins + 1; j ← j - 1
        END IF
    END WHILE

    RETURN {subs, dels, ins, alignment}
END FUNCTION

FUNCTION ComputeWER(targetText, spokenText) RETURNS {wer, subs, dels, ins, alignment}
    result ← LevenshteinAlign(WORDS(targetText), WORDS(spokenText))
    wer ← 0 IF WORDS(targetText).length = 0
             ELSE (result.subs + result.dels + result.ins) / WORDS(targetText).length × 100
    RETURN result WITH wer ADDED
END FUNCTION

FUNCTION ComputePER(refPhonemes[], hypPhonemes[]) RETURNS {per, accuracy, subs, dels, ins, alignment}
    result ← LevenshteinAlign(refPhonemes, hypPhonemes)
    per ← 0 IF refPhonemes.length = 0
            ELSE (result.subs + result.dels + result.ins) / refPhonemes.length × 100
    accuracy ← MAX(0, 100 - per)
    RETURN result WITH per, accuracy ADDED
END FUNCTION
```

---

## 5. Report aggregation (used by `GenerateReport`)

```
FUNCTION AggregateByWord(history[]) RETURNS map<word, stats>
    wordData ← empty map
    FOR EACH entry IN history
        IF entry.targetWord NOT IN wordData THEN
            wordData[entry.targetWord] ← { ipa: entry.targetIpa, attempts: [] }
        ENDIF
        APPEND entry TO wordData[entry.targetWord].attempts
    END FOR

    FOR EACH (word, data) IN wordData
        data.avgAccuracy ← MEAN(a.accuracy FOR a IN data.attempts)
        data.avgWER      ← MEAN(a.wer      FOR a IN data.attempts)
        data.avgPER      ← MEAN(a.per      FOR a IN data.attempts)
        data.totalSubs   ← SUM(a.subs FOR a IN data.attempts)
        data.totalDels   ← SUM(a.dels FOR a IN data.attempts)
        data.totalIns    ← SUM(a.ins  FOR a IN data.attempts)
    END FOR

    RETURN wordData
END FUNCTION
```
