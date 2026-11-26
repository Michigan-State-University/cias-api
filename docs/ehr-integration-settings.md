# EHR integration settings

Environment variables for a site with an EHR integration: patient verification over Epic on FHIR,
results sent as HL7 to the site's receiving system, and code scanning. The settings below are read when
used, never at boot, so a site without an EHR integration boots with them blank. Several other
`EPIC_ON_FHIR_*` names in `.env.template` are read at boot, so every site must define those, even blank.
The code is in `app/services/ehr/settings.rb` and `app/services/api/hl7_receiver/`.

The web build has its own copies of `EHR_SITE_NAME` and `EHR_BARCODE_SCAN_FEATURE_ENABLED`, plus
`EHR_INTEGRATION_FEATURE_ENABLED` (see cias-web's `.env.example`). Set both sides to match.

## HL7 receiver

The site's interface engine that takes the results (Cloverleaf for Henry Ford).

| Setting | Value |
|---|---|
| `HL7_RECEIVER_TOKEN_URL` | Token endpoint. Required to send. |
| `HL7_RECEIVER_URL` | Endpoint that takes the HL7 messages. Required to send. |
| `HL7_RECEIVER_USERNAME`, `HL7_RECEIVER_PASSWORD` | Token request credentials. Required to send. |
| `HL7_RECEIVER_CLIENT_ID`, `HL7_RECEIVER_CLIENT_SECRET` | Token request client. Required to send. |
| `HL7_RECEIVER_SSL_VERIFY` | `false`, `0` or `off` turns certificate verification off. Anything else, blank included, verifies. |
| `HL7_RECEIVER_CA_CERT` | PEM added to the system trust store. See below. |

A blank token or receiver URL stops the send with an error naming the setting, reported to Sentry.
If the token request is refused (a wrong or blank credential), that session's results are skipped, not
retried; Sentry gets "no token issued", which names no setting.

To roll back certificate verification, set `HL7_RECEIVER_SSL_VERIFY=false` (`False` or `no` still
verify). On ECS that takes the SSM change plus a new deployment of the API and worker services.

Henry Ford's HL7 listener (`:7443`) serves its certificate without the Entrust OV intermediate, so
`HL7_RECEIVER_CA_CERT` must hold that intermediate. The Sectigo R46 root comes from the system trust
store once `ca-certificates` is current; add the root here as well only on a host that predates R46.

## HL7 message values

The site's receiving system assigns these. They have no defaults.

| Setting | HL7 field |
|---|---|
| `HL7_SENDING_FACILITY` | MSH-4 |
| `HL7_RECEIVING_FACILITY` | MSH-6 |
| `HL7_PROCESSING_ID` | MSH-11: `P` in production, `T` elsewhere |
| `HL7_DOCUMENT_TYPE` | TXA-2 |
| `HL7_OBSERVATION_VALUE_PREFIX` | OBX-5 prefix of the PDF report |

All are checked before anything is sent. The send stops, and Sentry gets the setting names (never the
values), when a value:

- is blank;
- contains `|`, `~`, a line break or a double quote;
- starts or ends with whitespace.

`^`, `&` and `\` are allowed, since composite values use them.

`HL7_REPORT_TIMEZONE` is optional: the time zone of the HL7 timestamps.
Blank: the participant's time zone.

## Site identity

| Setting | Value |
|---|---|
| `EHR_SITE_NAME` | The site's name in API messages. Blank: `EHR`. |
| `EHR_CSV_PREFIX` | Prefix of the patient-detail columns in CSV exports. Blank: `ehr_patient`. |
| `EHR_APPOINTMENTS_FROM_PAST` | `1` lets patient verification match past appointments. |

## Code scanning

Participants can scan the code printed on the site's patient labels instead of typing their details
(`verify_by_code`).

| Setting | Value |
|---|---|
| `EHR_BARCODE_SCAN_FEATURE_ENABLED` | `1` (surrounding spaces ignored) turns scanning on. Anything else, blank included, leaves it off. |
| `EHR_BARCODE_PATIENT_ID_PATTERN` | Where the patient ID sits in the scanned text and what it may contain: a regular expression with a named group `patient_id`. Required when scanning is on. |
| `EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM` | FHIR identifier system (OID) of that patient ID. Required when scanning is on. |

With scanning on, a blank required setting refuses every scan and is reported to Sentry.

Put the ID's rules in the group itself. Henry Ford's labels carry `<PtID>Z394</PtID>`, with an ID of up to
10 letters or digits: `<PtID> *(?<patient_id>[A-Za-z0-9]{1,10}) *</PtID>`. A code the pattern doesn't match is
refused as unreadable. Close the group on both sides (a tag, a separator, `\A` or `\z`): an ID that runs
into more letters, digits, `.` or `-` is refused, so the pattern can't cut a longer ID down to another one. Every ID must also be 1 to 64 letters, digits, `.` or `-`, whatever the pattern allows.

Every scan fails, with an error naming the setting (reported to Sentry), when the pattern:

- isn't a valid regular expression;
- starts or ends with whitespace;
- has no `patient_id` group.

In a local `.env`, single-quote a pattern with backslashes (`EHR_BARCODE_PATIENT_ID_PATTERN='\A(?<patient_id>\d+)\z'`).
dotenv drops backslashes from unquoted and double-quoted values.
