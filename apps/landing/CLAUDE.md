# Landing Agent — apps/landing

Scope: Landing page pública de smwhr.

Lee primero el `CLAUDE.md` raíz. Este documento complementa, no reemplaza.

---

## Stack

- **Framework:** Next.js 15+ con App Router
- **Styling:** Tailwind CSS 4+
- **Typography:** next/font para Space Grotesk, Inter, JetBrains Mono
- **Forms:** server actions para waitlist signup
- **Database:** Supabase (comparte backend con la app)
- **Deploy:** Vercel
- **Analytics:** PostHog (mismo proyecto que mobile)

---

## Objetivo de la landing

Una sola página con un solo objetivo: **capturar emails de usuarios interesados antes del lanzamiento**.

NO es un sitio de documentación, NO tiene múltiples páginas, NO tiene blog, NO tiene FAQ largo.

**La pregunta que debe responder un visitante en 5 segundos:**
*"What is this and should I sign up?"*

---

## Estructura de folders

```
apps/landing/
├── app/
│   ├── layout.tsx
│   ├── page.tsx              # única página
│   ├── globals.css
│   ├── actions/
│   │   └── waitlist.ts       # server action
│   └── api/
│       └── health/
│           └── route.ts
├── components/
│   ├── hero.tsx
│   ├── features-grid.tsx
│   ├── waitlist-form.tsx
│   ├── footer.tsx
│   └── ui/
│       └── button.tsx
├── lib/
│   ├── supabase.ts
│   └── posthog.ts
├── public/
│   ├── og-image.png          # share card
│   └── favicon.svg
├── .env.example
├── tailwind.config.ts
├── next.config.mjs
└── package.json
```

---

## Secciones de la landing (una sola página)

### Hero (above the fold)

- Wordmark `smwhr` grande centrado, magenta neón (#FF2D95)
- Tagline: *"You were somewhere."*
- Subtítulo: *"The verified record of your real life. Concerts, matches, festivals, peaks. Collect proof of what you actually lived."*
- CTA: input email + botón magenta "Join the waitlist"
- Coordenada sutil inferior: `20.0850° N · -98.3630° W` (guiño a Tulancingo) en JetBrains Mono gris tenue

### Features grid (3 columnas)

Tres cards simples con iconografía minimal:

1. **Verified presence**
   *"GPS, device trust, and dwell time. Only real attendance counts."*

2. **Collectible proof**
   *"Each event becomes a badge. Framed, numbered, yours."*

3. **Made for sharing**
   *"One tap to Instagram Stories. Your somewhere, your story."*

### Coming soon preview

Mockup estático de la pantalla de reveal (pantalla 09 de los mocks) en un iPhone frame centrado.

Texto debajo: *"First drop: May 2026."*

### Footer minimalista

- Copyright "© 2026 smwhr · Orbit M"
- Links: Terms · Privacy · Contact
- Social: @smwhr (X, Instagram)

---

## Design tokens (match con mobile)

```css
/* globals.css */
:root {
  --bg: #050505;
  --surface: #111111;
  --surface-elevated: #1A1A1A;
  --border: #2A2A2A;

  --text-primary: #FFFFFF;
  --text-secondary: #888888;
  --text-tertiary: #555555;

  --accent: #FF2D95;
  --accent-muted: #8B1A51;
  --accent-glow: rgba(255, 45, 149, 0.15);

  --font-display: 'Space Grotesk', sans-serif;
  --font-body: 'Inter', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}

body {
  background: var(--bg);
  color: var(--text-primary);
  font-family: var(--font-body);
}
```

---

## Tailwind config

```typescript
// tailwind.config.ts
import type { Config } from 'tailwindcss';

export default {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#050505',
        surface: '#111111',
        'surface-elevated': '#1A1A1A',
        border: '#2A2A2A',
        'text-primary': '#FFFFFF',
        'text-secondary': '#888888',
        'text-tertiary': '#555555',
        accent: '#FF2D95',
        'accent-muted': '#8B1A51',
      },
      fontFamily: {
        display: ['var(--font-space-grotesk)'],
        body: ['var(--font-inter)'],
        mono: ['var(--font-jetbrains-mono)'],
      },
      spacing: {
        xxs: '4px',
        xs: '8px',
        sm: '12px',
        md: '16px',
        lg: '24px',
        xl: '32px',
        xxl: '48px',
        xxxl: '64px',
      },
    },
  },
} satisfies Config;
```

---

## Waitlist form (server action)

```typescript
// app/actions/waitlist.ts
'use server';

import { createClient } from '@/lib/supabase';
import { z } from 'zod';

const emailSchema = z.object({
  email: z.string().email(),
  interests: z.array(z.string()).optional(),
  referrer: z.string().optional(),
});

export async function joinWaitlist(formData: FormData) {
  const parsed = emailSchema.safeParse({
    email: formData.get('email'),
    referrer: formData.get('referrer'),
  });

  if (!parsed.success) {
    return { success: false, error: 'Invalid email' };
  }

  const supabase = createClient();
  const { error } = await supabase
    .from('waitlist_signups')
    .insert({
      email: parsed.data.email,
      referrer: parsed.data.referrer,
      source: 'landing',
      created_at: new Date().toISOString(),
    });

  if (error) {
    // Check if duplicate
    if (error.code === '23505') {
      return { success: true, message: "You're already on the list." };
    }
    return { success: false, error: 'Something went wrong. Try again.' };
  }

  return { success: true, message: "You're on the list. See you somewhere." };
}
```

---

## SEO y metadata

```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: 'smwhr — You were somewhere.',
  description: 'The verified record of your real life. Concerts, matches, festivals, peaks. Collect proof of what you actually lived.',
  keywords: ['concerts', 'events', 'verification', 'badges', 'collectibles', 'Mexico', 'festivals'],
  openGraph: {
    title: 'smwhr',
    description: 'You were somewhere.',
    url: 'https://smwhr.quest',
    siteName: 'smwhr',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'smwhr',
    description: 'You were somewhere.',
    images: ['/og-image.png'],
  },
};
```

---

## Analytics

- PostHog page_view automático
- Eventos custom:
  - `waitlist_signup` con email hash
  - `cta_click` con variant
  - `scroll_to_features`
  - `scroll_to_preview`

---

## First tasks

1. `npx create-next-app@latest landing --typescript --tailwind --app --src-dir=false`
2. Configurar Tailwind con design tokens
3. Configurar next/font para las 3 tipografías
4. Implementar Hero
5. Implementar Features Grid
6. Implementar mockup preview con image estática
7. Implementar footer
8. Crear tabla `waitlist_signups` en Supabase
9. Implementar server action `joinWaitlist`
10. Deploy a Vercel con dominio `smwhr.quest`

---

## Anti-patterns landing

- ❌ Multi-page con routing complejo
- ❌ Animaciones excesivas que distraen
- ❌ Formularios con múltiples campos (solo email)
- ❌ Blog, docs, FAQ inline (esos son para R1.0+)
- ❌ Modales de cookies intrusivos (usa banner simple)
- ❌ Newsletter además de waitlist (uno solo)
- ❌ Imágenes pesadas sin next/image
