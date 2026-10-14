# Encryption & Security

## PII Encryption (Lockbox)
All personally identifiable information is encrypted at rest using Lockbox gem.

### Encrypted Models
| Model | Encrypted Fields | Blind Indexes |
|-------|-----------------|---------------|
| User | email, first_name, last_name, uid | email_bidx, uid_bidx |
| Answer | body (JSON) | — |
| HfhsPatientDetail | patient_id, first_name, last_name, dob, sex, zip_code, phone_number, visit_id | patient_id_bidx |
| Phone | number | — |
| Message | phone | — |

### Querying Encrypted Data
- Never query `*_ciphertext` columns directly
- Use blind index columns for lookups: `User.find_by(email: 'test@example.com')` automatically uses `email_bidx`
- Use `decrypted_body` to access Answer content

### Adding New Encrypted Fields
```ruby
# In model
has_encrypted :field_name
blind_index :field_name  # if searchable

# In migration
add_column :table, :field_name_ciphertext, :text
add_column :table, :field_name_bidx, :string
add_index :table, :field_name_bidx
```

## Password Security
- Argon2 hashing via `devise-argon2`
- Cost factor: 4 (test), 10 (production)
- Token-based auth rotates on each request

## Rate Limiting (Rack::Attack)
- Global request throttle is defined but **currently commented out** (100 req/min)
- Active throttles are login-specific only:
  - 5 attempts per 20 seconds per IP
  - 10 attempts per 20 seconds per email
- Configured in `config/initializers/rack_attack.rb`

## HTTP Security Headers
- `secure_headers` gem for CSP, X-Frame-Options, etc.
- Configured in `config/initializers/secure_headers.rb`

## Sensitive Data Logging
- `logstop` gem prevents logging of sensitive data patterns
- Audited gem excludes all encrypted fields from audit records
- Paper Trail tracks changes but encrypted fields are stored as ciphertext

## Audit Exclusions
Always exclude encrypted fields from audit:
```ruby
audited except: %i[email_ciphertext first_name_ciphertext ...]
```

## What to Watch For
- Never log decrypted PII (email, phone, name, patient data)
- Never expose `*_ciphertext` columns in serializers — use the decrypted accessor
- Never commit encryption keys or `LOCKBOX_MASTER_KEY` to source control
- Always add blind indexes when encrypted fields need to be searchable
- Answer `body` is in migration mode (`migrating: true`) — both encrypted and unencrypted reads supported
