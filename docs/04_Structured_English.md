EchoVoice — Design Documentation

# EchoVoice — Structured English


# Level 1 Processes

## Process 1.0 — Manage Exercise

BEGIN

  READ Active Goals FROM D2 Goal Config Store

  GET Exercise Selection FROM Caregiver

  IF Exercise Selection IS VALID AND CONSISTENT WITH Active Goals THEN

    DETERMINE Target Word FOR the selected exercise

    SEND Target Word TO Process 2.0 (Capture Speech)

  ELSE

    REJECT selection

    PROMPT Caregiver TO choose a valid exercise

  ENDIF

END

## Process 2.0 — Capture Speech

*The Start-Recording Flag and Recording-Complete Flag are shown explicitly as control flow, matching the Structure Chart.*

BEGIN

  RECEIVE Target Word/Prompts FROM Process 1.0

  DISPLAY/PLAY Target Word TO Learner (prompt)

  RECEIVE Start-Recording Flag (control) FROM Process 1.0 / Main Control

  IF Start-Recording Flag = TRUE THEN

    WAIT FOR Speech Input FROM Learner

    IF Speech Input IS RECEIVED WITHIN timeout THEN

      RECORD Speech Input AS Raw Audio File (.wav)

      SET Recording-Complete Flag (control) = TRUE

      SEND Raw Audio File (.wav) TO Process 3.0 (Speech Recognition & Assessment)

      SEND Recording-Complete Flag TO Process 3.0 / Main Control

    ELSE

      FLAG no-response event

      SET Recording-Complete Flag (control) = FALSE

      RETURN control TO Process 1.0

    ENDIF

  ENDIF

END

## Process 3.0 — Speech Recognition & Assessment

BEGIN

  RECEIVE Recorded Speech (raw audio) FROM Process 2.0

  PROCESS Recorded Speech (see Level 2 decomposition: 3.1-3.4)

  PRODUCE Assessment Result

  WRITE Assessment Record TO D1 Progress Database

  SEND Assessment Result TO Process 4.0 (Generate Feedback)

END

## Process 4.0 — Generate Feedback

BEGIN

  RECEIVE Assessment Result FROM Process 3.0

  IF Assessment Result INDICATES correct/acceptable pronunciation THEN

    GENERATE positive Visual & Auditory Prompts

  ELSE IF Assessment Result INDICATES minor errors THEN

    GENERATE corrective Visual & Auditory Prompts highlighting the error

  ELSE

    GENERATE encouraging retry Visual & Auditory Prompts

  ENDIF

  SEND Visual & Auditory Prompts TO Learner

END

## Process 5.0 — Monitor Progress

*Report generation is gated by an explicit Report-Request Flag (control) from the Caregiver, matching the "IF report requested" condition on the Structure Chart.*

BEGIN

  READ Stored Progress FROM D1 Progress Database

  COMPUTE Session Progress Summary FOR current session

  SEND Session Progress Summary TO Caregiver

  RECEIVE Report-Request Flag (control) FROM Caregiver

  IF Report-Request Flag = TRUE THEN

    COMPUTE Longitudinal Progress Report (Exportable) (trends across sessions)

    SEND Longitudinal Progress Report TO Caregiver (for sharing with an external clinician)

  ENDIF

END

## Process 6.0 — Configure Goals & Review Assessment

*Goal updates return an explicit Update-Status Flag (control) confirming whether the write to D2 succeeded, matching the "IF goal update submitted" condition on the Structure Chart. Goal configuration and progress review are Caregiver inputs.*

BEGIN

  RECEIVE Goal Configuration AND Progress Review request FROM Caregiver

  IF input TYPE = Goal Configuration THEN

    VALIDATE goal parameters

    IF VALID THEN

      WRITE Goal Configuration TO D2 Goal Config Store

      SET Update-Status Flag (control) = SUCCESS

    ELSE

      SET Update-Status Flag (control) = FAILURE

    ENDIF

    SEND Update-Status Flag TO Caregiver / Main Control

  ELSE IF input TYPE = Progress Review THEN

    READ Stored Progress FROM D1 Progress Database

    PRESENT assessment records and summaries TO Caregiver

    (no store update; review only)

  ENDIF

END

# Level 2 — Decomposition of Process 3.0

## Process 3.1 — Extract Acoustic Features

BEGIN

  RECEIVE Raw Audio File (.wav) FROM Process 2.0 (Capture Speech)

  APPLY signal processing (e.g., framing, windowing, transformation)

  PRODUCE Spectrogram Tensors

  SEND Spectrogram Tensors TO Process 3.2

END

## Process 3.2 — Run Model Inference

*The Inference Status Flag is shown explicitly as a control-flow output, matching the Structure Chart.*

BEGIN

  RECEIVE Spectrogram Tensors FROM Process 3.1

  RUN on-device speech recognition model ON Spectrogram Tensors

  IF model inference SUCCEEDS THEN

    PRODUCE Predicted Phoneme Sequence

    SET Inference Status Flag (control) = SUCCESS

    SEND Predicted Phoneme Sequence TO Process 3.3

  ELSE

    SET Inference Status Flag (control) = FAILURE

  ENDIF

  SEND Inference Status Flag TO Process 3.3 / Main Control

END

## Process 3.3 — Align Phonemes

BEGIN

  RECEIVE Predicted Phoneme Sequence FROM Process 3.2

  READ Target Phoneme Template FROM D3 Phoneme Target Dictionary

  ALIGN Predicted Phoneme Sequence WITH Target Phoneme Template

  FOR EACH phoneme position DO

    IF predicted phoneme ≠ target phoneme THEN

      RECORD mismatch

    ENDIF

  ENDFOR

  PRODUCE Phoneme Error Matrix

  SEND Phoneme Error Matrix TO Process 3.4

END

## Process 3.4 — Compute Pronunciation Score

BEGIN

  RECEIVE Phoneme Error Matrix FROM Process 3.3

  CALCULATE pronunciation score FROM error matrix (e.g., weighted accuracy per phoneme)

  PRODUCE Assessment Result

  SEND Assessment Result TO Process 4.0 (Generate Feedback, Level 1)

  WRITE Assessment Record TO D1 Progress Database

END

# Data Stores Referenced

D1 — Progress Database: stores Assessment Records; source of Stored Progress for monitoring.

D2 — Goal Config Store: stores Goal Configuration; source of Active Goals for exercise selection.

D3 — Phoneme Target Dictionary: source of Target Phoneme Templates for alignment.

# External Entities

Learner: provides Speech Input; receives Visual & Auditory Prompts.

Caregiver: provides Exercise Selection, Goal Configuration, and the Report-Request Flag; receives Session Progress Summary, the Exportable Longitudinal Progress Report, and the Update-Status Flag.

SLP (external — research/clinical validation only): not a user of the app; the Caregiver shares exported reports with an external clinician through their own preferred channels.
