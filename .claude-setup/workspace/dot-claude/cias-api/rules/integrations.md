# Third-Party Integrations

Most external API services live under `app/services/api/` with a facade class delegating to sub-services. Exception: Twilio SMS is under `app/services/communication/`.

## Twilio (SMS/Voice)
- **Service:** `Communication::Sms` (`app/services/communication/sms.rb`)
- **Inbound handler:** `V1::Sms::Replay` (`app/services/v1/sms/replay.rb`)
- **Client:** `Twilio::REST::Client` with `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
- **Sending from:** `TWILIO_FROM` env var
- **Phone parsing:** `Phonelib.parse()` for country code extraction
- **Phone model:** encrypted `number` field, `full_number()` = prefix + number
- **Message model:** encrypted `phone` field, tracks `status` (success/error)
- Supports SMS and MMS (with `media_url`)
- Inbound SMS handles: codes, answers to questions, STOP opt-out

## Google Cloud TTS & Translation
- **TTS:** `Audio::TextToSpeech::Google` (`app/models/audio/text_to_speech/google.rb`)
- **Translation:** `V1::Google::TranslationService` (`app/services/v1/google/translation_service.rb`)
- **Credentials:** `GOOGLE_APPLICATION_CREDENTIALS` (JSON file path or raw JSON string)
- **TTS env vars:** `TEXT_TO_SPEECH_PROVIDER`, `TEXT_TO_SPEECH_LANGUAGE`, `TEXT_TO_SPEECH_VOICE`
- **Caching:** Audio files cached by SHA256 digest of `text_language_voice`
- **Voice models:** `GoogleTtsVoice`, `GoogleTtsLanguage`
- Translation strips image tags before translating, preserves data: URLs

## Henry Ford Health System (HFHS) — HL7 Integration
- **Facade:** `Api::Hfhs` → `Api::Hfhs::UserSession`, `Api::Hfhs::Reports`
- **Auth:** OAuth2 password grant → Bearer token
- **HL7 mappers** (`app/services/hl7/`):
  - `PatientDataMapper` — MSH + PID segments
  - `UserSessionMapper` — PV1 + OBR + OBX (answers)
  - `AnswersMapper` — OBX segments from `Answer::HenryFord`
  - `GeneratedReportMapper` — TXA + OBX with Base64-encoded PDF
- **Constants:** Sending app = `HTD`, facility = `HFHS`, HL7 version = `2.3`
- **Patient data:** `HfhsPatientDetail` model (all fields Lockbox-encrypted)
- **Env vars:** `HFHS_URL`, `HFHS_TOKEN_URL`, `HFHS_USERNAME`, `HFHS_CLIENT_ID`, `HFHS_CLIENT_SECRET`, `HFHS_PASSWORD`

## Epic on FHIR — Patient Verification & Appointments
- **Base:** `Api::EpicOnFhir::BaseService` (abstract, validates responses, Sentry on errors)
- **Auth:** JWT Bearer token with RSA private key (`Api::EpicOnFhir::Authentication`)
- **Patient lookup:** `Api::EpicOnFhir::PatientVerification` — FHIR `$match` operation
- **Appointments:** `Api::EpicOnFhir::Appointments` — retrieves by patient ID
- **Orchestrator:** `V1::HenryFord::VerifyService` — verifies patient, fetches appointments, creates `HfhsPatientDetail`
- **Location matching:** `ClinicLocation` with `epic_identifier` / `auxiliary_epic_identifier`
- **Env vars:** `EPIC_ON_FHIR_AUTHENTICATION_ENDPOINT`, `EPIC_ON_FHIR_PATIENT_ENDPOINT`, `EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT`, `EPIC_ON_FHIR_CLIENT_ID`, `EPIC_ON_FHIR_PRIVATE_KEY`, `EPIC_ON_FHIR_PUBLIC_KEY`, `EPIC_ON_FHIR_KID`, `EPIC_ON_FHIR_AUTHENTICATION_ALGORITHM`, `EPIC_ON_FHIR_SYSTEM`

## CAT-MH — Computerized Adaptive Testing
- **Facade:** `Api::CatMh` with full interview lifecycle methods
- **Base:** `Api::CatMh::Base` — HTTP via Faraday with cookie management (JSESSIONID, AWSELB)
- **Auth:** Form-based login (`j_username`/`j_password`), expects 302 redirect with Set-Cookie
- **Flow:** create_interview → authenticate → initialize → get_question → answer → ... → get_result → terminate
- **Session state:** `jsession_id` and `awselb` stored on `UserSession::CatMh`
- **Recovery:** Auto-retry on session timeout, `BreakLock` for cookie reset
- **Models:** `CatMhLanguage`, `CatMhTestType`, `CatMhTestAttribute`, `CatMhVariable`, `CatMhPopulation`, `CatMhTimeFrame`
- **Env var:** `BASE_CAT_URL`

## Documo — Fax Service
- **Service:** `Api::Documo::SendMultipleFaxes`
- **Auth:** Basic auth with `DOCUMO_API_KEY`
- **Endpoint:** `BASE_DOCUMO_URL/v1/faxes/multiple`
- **Format:** Multipart form-data with PDF attachments and cover page
- **Used by:** `V1::GeneratedReports::ShareToThirdParty`

## AWS S3 — File Storage
- **Config:** `config/storage.yml` — production uses `:amazon` service
- **Env vars:** `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, `STORAGE_BUCKET`
- **Used for:** Audio MP3 files, generated PDF reports, logos, exported data, conversation transcripts
