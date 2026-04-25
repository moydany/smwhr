# R0.1 — Manual QA checklist

> Run before flipping `useMocks=false` and again before soft launch.
> Target devices: iPhone 14 (or 15) + a mid-tier Android (Galaxy A series).
> Build in **profile mode** so the optimizer reflects the real perf
> (`flutter run --profile` or `flutter build ios --profile --simulator`).

## Cold-start
- [ ] App icon present on home screen (Phase 2: real icon assets land)
- [ ] Cold start to splash render < 2.0 s on iPhone 14
- [ ] Splash wordmark glow holds 60 fps in profile mode
- [ ] `SmwhrAmbientBackground` (grid + drift + sweep + stars + ping rings)
      holds 60 fps with the wordmark also animating
- [ ] No iOS default white flash before splash
- [ ] Status bar text is white (dark-mode lock)

## Auth
- [ ] Apple/Google buttons fire haptic on tap
- [ ] 800–1200 ms loading state with disabled buttons during simulated auth
- [ ] AuthResult.ready → routes to /home
- [ ] AuthResult.needsOnboarding → routes to /onboarding/identity
- [ ] Email magic-link surfaces a snack (stub OK in R0.1)

## Onboarding
- [ ] Step indicator advances 01/03 → 02/03 → 03/03
- [ ] Identity: handle live-validates with debounce, taken handles show error
- [ ] Identity: Continue is disabled until handle, displayName ≥2 chars,
      city are all set
- [ ] Interests: tap categories, "Everything" toggles all 5
- [ ] Interests: Continue blocked until ≥1 selected
- [ ] Permissions: Enable notifications fires heavy haptic + completes
      onboarding + routes to /home
- [ ] "Maybe later" also completes onboarding (no notif perm)
- [ ] Back chevron pops correctly between steps

## Home feed
- [ ] Wordmark + avatar visible in top bar; tapping avatar pushes /profile
- [ ] Pull-to-refresh works; spinner stops; loading skeleton flashes during
      first load
- [ ] Featured card hero visible; intent CTA toggles between
      "I'll be there" magenta and "You're in" dark
- [ ] List rows tappable; navigate to /events/<slug>
- [ ] No frame drops while scrolling

## Event detail
- [ ] Hero artwork renders with bottom fade gradient
- [ ] Back chevron pops back to home
- [ ] Intent toggle works; stats row updates "going" count live
- [ ] THE QUEST body interpolates `dwellMinimumMin`
- [ ] WHAT YOU'LL EARN locked badge preview shows category + serial line
- [ ] Tickets link visible when `ticketmasterUrl` present

## Active quest
- [ ] "● QUEST ACTIVE" pill pulses
- [ ] Timer shows `00 : MM : SS`, SS ticks every 1 s, MM ticks once per
      mock-minute (1 s wall = 1 mock min in mock mode)
- [ ] Three checks light up by ~1.6 s after mount
- [ ] Capture CTA stays disabled until dwell ≥ event.dwellMinimumMin AND
      first three checks pass
- [ ] Capture tap routes to /camera/<eventId>

## Camera
- [ ] Camera screen slides up from the bottom (modal feel)
- [ ] Badge frame preview shows correct event metadata (venue, city, date,
      artist · title)
- [ ] Shutter button glows magenta with white centre
- [ ] Tap shutter → 220 ms white flash + heavy haptic + 1.5 s loading +
      route to /reveal/<badgeId>
- [ ] X button pops back to active quest

## Reveal
- [ ] "QUEST COMPLETE" label fades in
- [ ] Frame drops in from above on `easeOutBack`
- [ ] Photo composite scales 0.85→1 with opacity ramp
- [ ] Heavy haptic at the composite moment
- [ ] Serial label types in last
- [ ] CTAs (Share / Save to collection) fade in after 1.6 s
- [ ] Animation hits 60 fps in profile mode

## Badge detail
- [ ] BadgeCard hero renders with category-tinted glow
- [ ] Stats card: ISSUED / VERIFICATION (magenta) / VENUE / SERIAL (mono)
- [ ] Share CTA pushes /share/<badgeId>

## Profile + Collection
- [ ] Avatar gradient circle + handle + bio
- [ ] Stats card 3-col: QUESTS / VENUES / ARTISTS
- [ ] Tabs: Collection (active magenta underline) · Wanted · Friends
- [ ] Grid renders 7 seeded badges across 5 categories
- [ ] Tapping a tile pushes /badge/<id>
- [ ] No "BOTTOM OVERFLOWED BY N PIXELS" warnings

## Share
- [ ] Preview card matches the Reveal layout (badge + "I was somewhere." +
      @SMWHR + smwhr.quest)
- [ ] Tapping Share captures the RepaintBoundary, writes a temp PNG,
      and surfaces the iOS / Android share sheet via share_plus
- [ ] "Save to camera roll" snack stub (Phase 2)
- [ ] Close (X) pops back

## Cross-cutting
- [ ] Every primary action has a haptic (light/medium/heavy as appropriate)
- [ ] No light-mode bleed-through anywhere; text reads on bg always
- [ ] Portrait-only orientation holds (rotate device — should not flip)
- [ ] No console errors in `flutter run --profile`
- [ ] Memory: heap stays under ~150 MB at idle on iPhone 14
- [ ] Cold restart re-hydrates the signed-in user (Hive auth box)
- [ ] Sign-out from /_debug returns to splash (in mock mode)

## Known stubs (Phase 2)
- Real Apple/Google OAuth (currently mock)
- Email magic-link verify (currently snack)
- Real CameraController + photo capture (currently procedural preview)
- Real EXIF metadata (currently no-op)
- Push notifications via firebase_messaging
- Locus + Geolocator dual-track tracking
- Save to camera roll (gallery saver)
- Real promoter posters (currently procedural EventArtwork)
- Custom TTF fonts (currently google_fonts at runtime)
- Lottie reveal animation (currently procedural Flutter animation)
