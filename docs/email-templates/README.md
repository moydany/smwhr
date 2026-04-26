# Email templates

Custom Supabase Auth email templates that match the smwhr design
system — deep black background, magenta neon accent, Space Grotesk +
Inter + JetBrains Mono.

## How to apply

Supabase dashboard → **Authentication → Email Templates → Magic Link**.

| Field | Paste from |
|---|---|
| **Subject heading** | `{{ .Token }} — tu código smwhr` |
| **Message body (HTML)** | [magic-link.html](magic-link.html) |
| **Message body (plain text)** | [magic-link.txt](magic-link.txt) — only if Supabase exposes the field; otherwise the HTML's text fallback is enough |

Hit **Save**. Next OTP request renders the new template.

## Why subject = `{{ .Token }} — tu código smwhr`

Putting the 6-digit code first in the subject line lets iOS surface it
in the lock-screen / banner notification with the keyboard-suggestion
chip ("From Messages: 123456 → tap to autofill"). The user can fill the
OTP without ever opening the email — fastest possible auth UX on iOS.

If we ever localise to English (R0.5+), keep the same pattern:
`{{ .Token }} — your smwhr code`.

## Template variables Supabase substitutes

- `{{ .Token }}` — the 6-digit OTP. Required for the in-app code field.
- `{{ .ConfirmationURL }}` — magic link that auto-verifies on click
  (works only on the same device the request came from).
- `{{ .Email }}` — the recipient's email; we don't currently render
  it but it's available.

The default Supabase template ships only `{{ .ConfirmationURL }}`. The
in-app input expects a numeric code, so the default template silently
breaks the flow — that's why we override.

## Other templates (not customised yet)

Supabase ships several other templates we'll customise close to release:

- **Confirm signup** — used if we ever switch to confirm-on-signup
  (currently we don't; signInWithOtp creates + verifies in one pass).
- **Change Email Address** — when users update their email post-launch.
- **Reset Password** — never used; smwhr is OTP-only by design.

For R0.1 only the Magic Link template needs customising.
