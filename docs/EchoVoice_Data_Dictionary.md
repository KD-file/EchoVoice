**EchoVoice — Data Dictionary**

**1. Legend**

| **Symbol / Term** | **Meaning** |
| --- | --- |
| PK | Primary Key |
| FK | Foreign Key |
| int | Stored as SQLite INTEGER |
| string | Stored as SQLite TEXT |
| date | Stored as SQLite TEXT (ISO-8601, YYYY-MM-DD) |
| datetime | Stored as SQLite TEXT (ISO-8601, YYYY-MM-DDTHH:MM:SS) |
| float | Stored as SQLite REAL |
| 1 : 0..M | One mandatory parent to zero-or-many children (optional crow's foot) |
| 1 : 1 | Strict one-to-one, mandatory on both sides |

**2. Entity Overview**

| **#** | **Entity** | **PK** | **FK(s)** | **Purpose** |
| --- | --- | --- | --- | --- |
| **1** | Caregiver | caregiver_id | — | Parent/guardian who runs practice sessions at home and configures goals |
| **2** | Learner | learner_id | caregiver_id | The child receiving therapy; central subject of the system |
| **3** | Goal_Configuration | goal_id | learner_id, caregiver_id | Therapy targets (phonemes) the caregiver sets for a learner |
| **4** | Exercise | exercise_id | — | A practice item (target word) in the content library |
| **5** | Phoneme_Target | phoneme_id | exercise_id | Individual phonemes making up an exercise word, in order |
| **6** | Practice_Session | session_id | learner_id, caregiver_id | One sitting of practice by a learner, guided by a caregiver |
| **7** | Attempt | attempt_id | session_id, exercise_id | One recorded spoken attempt at an exercise within a session |
| **8** | Assessment_Record | assessment_id | attempt_id | Automated scoring output for one attempt |
| **9** | Progress_Report | report_id | learner_id | Aggregated summary of a learner's assessment history over time |

*Note: The Speech-Language Pathologist is an external clinical validator, not an entity in the app's data model. Progress reports are exported on-device by the Caregiver and shared with an external clinician through the Caregiver's own preferred channels.*

**3. Entity Detail**

**3.1 Caregiver**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **caregiver_id** | int | PK | Unique identifier for the caregiver |
| **full_name** | string | NOT NULL | Caregiver's full name |
| **contact_number** | string | NOT NULL | Caregiver's phone/contact number |
| **relationship_to_learner** | string | NOT NULL | e.g., "Mother", "Father", "Guardian" |

**3.2 Learner**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **learner_id** | int | PK | Unique identifier for the learner (child) |
| **caregiver_id** | int | FK → Caregiver.caregiver_id | The caregiver responsible for this learner |
| **full_name** | string | NOT NULL | Learner's full name |
| **date_of_birth** | date | NOT NULL | Used for age-appropriate exercise selection |
| **diagnosis_notes** | string | nullable | Free-text clinical/diagnostic notes |
| **enrollment_date** | date | NOT NULL | Date the learner was enrolled in the program |

**3.3 Goal_Configuration**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **goal_id** | int | PK | Unique identifier for the goal configuration |
| **learner_id** | int | FK → Learner.learner_id | Learner this goal applies to |
| **caregiver_id** | int | FK → Caregiver.caregiver_id | Caregiver who configured the goal |
| **target_phonemes** | string | NOT NULL | Phoneme(s) targeted (e.g., comma-separated list or JSON array) |
| **date_set** | date | NOT NULL | Date the goal was configured |
| **status** | string | NOT NULL | e.g., "Active", "Completed", "On Hold" |

**3.4 Exercise**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **exercise_id** | int | PK | Unique identifier for the exercise |
| **target_word** | string | NOT NULL | The word the learner is asked to repeat |
| **difficulty_level** | string | NOT NULL | e.g., "Beginner", "Intermediate", "Advanced" |
| **category** | string | NOT NULL | Thematic grouping (e.g., "Animals", "Food") |

**3.5 Phoneme_Target**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **phoneme_id** | int | PK | Unique identifier for the phoneme target |
| **exercise_id** | int | FK → Exercise.exercise_id | Exercise this phoneme belongs to |
| **phoneme_symbol** | string | NOT NULL | IPA or internal phoneme notation |
| **position_index** | int | NOT NULL | Order of this phoneme within the target word |

**3.6 Practice_Session**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **session_id** | int | PK | Unique identifier for the session |
| **learner_id** | int | FK → Learner.learner_id | Learner who participated |
| **caregiver_id** | int | FK → Caregiver.caregiver_id | Caregiver who initiated/guided the session |
| **session_date** | datetime | NOT NULL | Date and time the session took place |

**3.7 Attempt**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **attempt_id** | int | PK | Unique identifier for the attempt |
| **session_id** | int | FK → Practice_Session.session_id | Session this attempt belongs to |
| **exercise_id** | int | FK → Exercise.exercise_id | Exercise being attempted |
| **audio_file_path** | string | NOT NULL | Local on-device path to the recorded audio file |
| **timestamp** | datetime | NOT NULL | When the attempt was recorded |

**3.8 Assessment_Record**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **assessment_id** | int | PK | Unique identifier for the assessment record |
| **attempt_id** | int | FK → Attempt.attempt_id, UNIQUE | The attempt this record scores (1:1) |
| **phoneme_error_matrix** | string | NOT NULL | Serialized (e.g., JSON) phoneme-level error breakdown |
| **pronunciation_score** | float | NOT NULL | Overall computed pronunciation score |
| **wer** | float | NOT NULL | Word Error Rate |
| **per** | float | NOT NULL | Phoneme Error Rate |
| **date_created** | datetime | NOT NULL | When the assessment was generated |

**3.9 Progress_Report**

| **Field** | **Type** | **Constraint** | **Description** |
| --- | --- | --- | --- |
| **report_id** | int | PK | Unique identifier for the report |
| **learner_id** | int | FK → Learner.learner_id | Learner this report summarizes |
| **recipient_type** | string | NOT NULL | "Caregiver" — the report is exported for the caregiver, who may share it with an external clinician |
| **range_start** | date | NOT NULL | Start of the summarized date range |
| **range_end** | date | NOT NULL | End of the summarized date range |
| **summary_text** | string | NOT NULL | Generated narrative summary of progress over the range |

**4. Relationships (Business Rules)**

| **Relationship** | **Cardinality** | **Enforced by** |
| --- | --- | --- |
| Caregiver sets Goal_Configuration | 1 Caregiver : 0..M Goal_Configuration | Goal_Configuration.caregiver_id |
| Caregiver has Learner | 1 Caregiver : 0..M Learner | Learner.caregiver_id |
| Learner has Goal_Configuration | 1 Learner : 0..M Goal_Configuration | Goal_Configuration.learner_id |
| Learner participates in Practice_Session | 1 Learner : 0..M Practice_Session | Practice_Session.learner_id |
| Caregiver initiates Practice_Session | 1 Caregiver : 0..M Practice_Session | Practice_Session.caregiver_id |
| Learner compiled_for Progress_Report | 1 Learner : 0..M Progress_Report | Progress_Report.learner_id |
| Exercise contains Phoneme_Target | 1 Exercise : 0..M Phoneme_Target | Phoneme_Target.exercise_id |
| Exercise assigned_to Attempt | 1 Exercise : 0..M Attempt | Attempt.exercise_id |
| Practice_Session contains Attempt | 1 Practice_Session : 0..M Attempt | Attempt.session_id |
| Attempt generates Assessment_Record | 1 Attempt : 1 Assessment_Record | Assessment_Record.attempt_id (should be UNIQUE) |
