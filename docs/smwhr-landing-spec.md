# smwhr — Landing Page Spec v2

**Versión:** v2.0
**Fecha:** 24 abril 2026
**Stack:** Next.js 15 + Tailwind 4 + shadcn/ui + Supabase
**Deploy:** Vercel
**Domain:** smwhr.quest

---

## Cambios de v1 a v2

- v1 era demasiado austera, parecía "coming soon" sin sustancia
- v2 muestra el producto sin comprometerse legalmente
- v2 tiene secciones tipo "How it works" pero diseñadas distintas a templates
- v2 incluye mockups visuales de la app
- v2 mantiene single page pero con scroll deliberado, no infinito

---

## Reglas legales NO NEGOCIABLES

### Cero menciones reales

**NO usar bajo ninguna circunstancia:**

- Nombres de artistas reales (BTS, Bad Bunny, Caifanes, Olivia Dean, etc.)
- Nombres de festivales reales (Corona Capital, Bahidorá, Vive Latino, Pa'l Norte, Hipnosis)
- Nombres de ligas (Liga MX, NFL, NBA, Premier League)
- Nombres de equipos deportivos
- Nombres de venues específicos (Estadio Azteca, Foro Sol, Auditorio Nacional, Estadio GNP Seguros)
- Logos o marcas comerciales de terceros
- Fotos de personas reales o famosas

### Lo que SÍ usamos

**Placeholders genéricos creíbles en español:**

- "Concierto · Jueves 7 mayo"
- "Festival · Fin de semana"
- "Partido · Estadio principal"
- "Show acústico · Foro íntimo"
- "Carrera · Trail mountain"

**Imágenes:**

- Solo mockups generados con Nano Banana o ilustraciones propias
- Foto de "audiencia" o "concierto" puede ser stock de Unsplash con licencia clara
- Background patterns abstractos
- Cero fotos de gente identificable

**Branding:**

- Solo el wordmark "smwhr" y elementos visuales propios
- Logo de "Orbit M" como studio en footer (eso es tuyo)

---

## Estructura nueva: 5 secciones, scroll deliberado

A diferencia de v1 que era 1 vista, v2 tiene 5 secciones que el usuario scrollea. Pero cada sección está diseñada de manera distinta para que NO se sienta template.

```
[1] HERO — wordmark + headline + CTA + counter + coordinate badge
[2] PROOF — mockup de app + frase corta sobre verificación
[3] HOW — 3 pasos del flow del usuario en formato no genérico
[4] CATALOG — preview de tipos de eventos sin mencionar marcas
[5] FOOTER — minimalista en una línea
```

**El truco visual:** cada sección tiene scroll-snap que la hace caber exacto en viewport en desktop. En mobile fluye naturalmente.

---

## SECCIÓN 1 — Hero

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              ● 20.0850° N · -98.3630° W                 │
│                                                         │
│                                                         │
│                                                         │
│                    smwhr                                │
│                                                         │
│              Estuviste ahí.                             │
│              Tenemos la prueba.                         │
│                                                         │
│        Una app que verifica tu asistencia               │
│        a eventos en vivo y la convierte                 │
│        en una colección que es tuya.                    │
│                                                         │
│              ┌──────────────────────┐                   │
│              │  Apúntate a la lista │                   │
│              └──────────────────────┘                   │
│                                                         │
│              247 personas ya están dentro               │
│                                                         │
│                                                         │
│              ↓  Mira cómo funciona                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Cambios vs v1:**

- "247 apuntados" → "247 personas ya están dentro" (más cálido)
- Agregada flecha sutil al final que invita a scroll: "↓ Mira cómo funciona"
- Esa flecha tiene animación bounce muy sutil (1s ease-in-out)

---

## SECCIÓN 2 — Proof (Mostrar el producto)

Esta es la sección que faltaba en v1. Mostramos un mockup de la app con efectos visuales.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│      No es un check-in. Es prueba.                      │
│                                                         │
│      [────────────────────────────────────]             │
│      │                                    │             │
│      │   [Mockup de iPhone con la         │             │
│      │    pantalla de Reveal de la app]   │             │
│      │                                    │             │
│      │   La app muestra una insignia      │             │
│      │   coleccionable con número serial  │             │
│      │   y "VERIFIED ✓"                   │             │
│      │                                    │             │
│      [────────────────────────────────────]             │
│                                                         │
│      GPS · Tiempo de permanencia · Integridad           │
│      del dispositivo. Tres capas que aseguran           │
│      que sí estuviste ahí.                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Specs de la sección Proof

**Layout:**

- Desktop: split en dos columnas. Mockup izquierda, texto derecha.
- Mobile: stack vertical, mockup arriba

**Headline:**

- Font: Space Grotesk Medium 36px (mobile) / 56px (desktop)
- Color: white
- "No es un check-in. Es prueba."

**Mockup del iPhone:**

- Frame de iPhone moderno (sin notch real, mockup limpio tipo iPhone 15)
- Dentro: screenshot de la pantalla de Reveal de la app con datos genéricos:
  - Texto "ESTADIO PRINCIPAL"
  - "CIUDAD DE MÉXICO · 07 MAY 2026"
  - "CONCIERTO · TOUR NOCTURNO"
  - "SMWHR #01247 OF 47,832 VERIFIED ✓"
- Glow magenta radial detrás del frame
- Animación: float muy sutil (3s loop, translate Y ±4px)

**Texto descriptivo derecha:**

- Font: Inter Regular 18px
- Color: text-secondary
- "GPS · Tiempo de permanencia · Integridad del dispositivo. Tres capas que aseguran que sí estuviste ahí."

**Detalle visual:**

- 3 chips alineados arriba del párrafo, con iconos abstractos:
  - 📍 → reemplazar con icono Phosphor de map-pin (1.5px stroke)
  - ⏱ → reemplazar con icono Phosphor de timer
  - 🛡 → reemplazar con icono Phosphor de shield-check
- Chips con border #2A2A2A, background #111111, padding 8px 14px

---

## SECCIÓN 3 — How it works (3 pasos)

La sección típica "How it works" pero diseñada distinto. En vez de 3 cards horizontales en grid, son 3 momentos en timeline vertical con el mockup del iPhone progresando.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│      Tres pasos. Una historia.                          │
│                                                         │
│      ┌─────────────┐   01  Llegas                       │
│      │             │       Marcas el evento. Llegamos   │
│      │  [Mock      │       cuando tú llegas. La app     │
│      │   pantalla  │       detecta el venue por GPS y   │
│      │   Quest     │       activa la quest sola.        │
│      │   Active]   │                                    │
│      │             │                                    │
│      └─────────────┘                                    │
│                                                         │
│      ┌─────────────┐   02  Te quedas                    │
│      │             │       60 minutos mínimo. Si te     │
│      │  [Mock      │       vas antes, no cuenta. Si te  │
│      │   pantalla  │       quedas, capturas un momento  │
│      │   Camera]   │       con la cámara que la app     │
│      │             │       provee, no la galería.       │
│      └─────────────┘                                    │
│                                                         │
│      ┌─────────────┐   03  Recibes                      │
│      │             │       Al terminar, tu insignia se  │
│      │  [Mock      │       genera con número de serie   │
│      │   pantalla  │       único. Se guarda en tu       │
│      │   Reveal]   │       colección. Es tuya.          │
│      │             │                                    │
│      └─────────────┘                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Specs de la sección How

**Headline:**

- "Tres pasos. Una historia."
- Mismo size que Proof headline

**Cada paso:**

- Layout: split vertical
- Izquierda (40%): mockup del iPhone con la pantalla correspondiente
- Derecha (60%): número grande + título + descripción

**Número:**

- "01", "02", "03"
- Font: JetBrains Mono Bold
- Tamaño: 48px
- Color: accent-muted (#8B1A51)

**Título del paso:**

- "Llegas", "Te quedas", "Recibes"
- Font: Space Grotesk Medium 32px
- Color: white

**Descripción:**

- Font: Inter Regular 17px
- Color: text-secondary
- Line-height: 1.6
- Max-width: 420px

**Mockups:**

- Mismo iPhone frame que en Proof
- Cada uno con la pantalla correspondiente de la app
- Glow magenta sutil
- En desktop: alternan lado (paso 1 izquierda, paso 2 derecha, paso 3 izquierda) para crear ritmo visual

**Mobile:**

- Stack vertical, número y título arriba, mockup debajo, descripción al final
- Cada paso ocupa scroll completo

**Detalle clave:**

- Una línea vertical sutil (1px, color border) conecta los 3 mockups en desktop, sugiriendo continuidad de la historia
- En mobile la línea se omite

---

## SECCIÓN 4 — Catalog Preview

Esta sección muestra el tipo de eventos sin mencionar nombres reales. Es donde puedes generar curiosidad sin riesgo legal.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│      Toda la noche.                                     │
│      Todos los partidos.                                │
│      Todas las cumbres.                                 │
│                                                         │
│      [Grid 2x3 de cards genéricas con tipos de eventos] │
│                                                         │
│      ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│      │ Conciertos│ Partidos │ Festivales│             │
│      │  ●       │  ●        │  ●        │             │
│      │ [glow    │ [glow     │ [glow     │             │
│      │  rosa]   │  verde]   │  naranja] │             │
│      └──────────┘ └──────────┘ └──────────┘             │
│      ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│      │ Outdoor  │ Cultura  │ Lo que     │             │
│      │  ●       │  ●        │ venga.    │             │
│      │ [glow    │ [glow     │  ●        │             │
│      │  azul]   │  morado]  │ [glow     │             │
│      │          │           │  multi]   │             │
│      └──────────┘ └──────────┘ └──────────┘             │
│                                                         │
│      Cada categoría tiene su marco, su color,           │
│      su lenguaje visual. Las insignias se sienten       │
│      distintas porque la experiencia lo es.             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Specs de la sección Catalog

**Headline (multi-línea poética):**

- "Toda la noche.\nTodos los partidos.\nTodas las cumbres."
- Font: Space Grotesk Medium 40px (mobile) / 64px (desktop)
- Color: white
- Line-height: 1.05
- Las 3 líneas separadas con `<br/>`

**Grid de 6 cards (2x3 desktop, 1 col mobile):**

Cada card representa una categoría con su ambient color del design system:

```
Card 1: Conciertos    — magenta #FF2D95
Card 2: Partidos      — verde #2DFF95
Card 3: Festivales    — naranja #FF9D2D
Card 4: Outdoor       — azul #2DC8FF
Card 5: Cultura       — morado #9D2DFF
Card 6: Lo que venga  — gradient multi sutil
```

**Diseño de cada card:**

```css
.category-card {
  background: #111111;
  border: 1px solid #2a2a2a;
  border-radius: 16px;
  padding: 32px 24px;
  height: 220px;
  position: relative;
  overflow: hidden;
}

.category-card::before {
  /* Glow ambient color en esquina superior derecha */
  content: "";
  position: absolute;
  top: -50px;
  right: -50px;
  width: 200px;
  height: 200px;
  background: radial-gradient(circle, var(--ambient-color) 0%, transparent 70%);
  opacity: 0.4;
  filter: blur(40px);
}

.category-card:hover::before {
  opacity: 0.7;
  transform: scale(1.2);
  transition: all 0.4s ease;
}
```

**Contenido de cada card:**

- Dot de 8px con el ambient color, top-left
- Título de la categoría (Inter Medium 22px, white)
- Una palabra/frase descriptiva en mono (12px, text-tertiary)
  - "Conciertos · Estadios y foros"
  - "Partidos · Liga, copa, mundial"
  - "Festivales · Multi-día"
  - "Outdoor · Cumbres y trails"
  - "Cultura · Teatro y arte"
  - "Lo que venga · Tu evento"

**Texto debajo del grid:**

- Font: Inter Regular 17px
- Color: text-secondary
- Max-width: 600px
- Centrado
- "Cada categoría tiene su marco, su color, su lenguaje visual. Las insignias se sienten distintas porque la experiencia lo es."

---

## SECCIÓN 5 — Final CTA + Footer

Cierre de la página que invita al action una vez más.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│            Vamos a empezar.                             │
│                                                         │
│            ┌────────────────────────┐                   │
│            │  Apúntate a la lista   │                   │
│            └────────────────────────┘                   │
│                                                         │
│            247 personas ya están dentro                 │
│                                                         │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  smwhr                              Hecho en MX · 2026  │
│                                                         │
│  Una venture de Orbit M             [twitter] [insta]   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Specs

**Headline final CTA:**

- "Vamos a empezar."
- Font: Space Grotesk Medium 48px
- Color: white

**Botón:**

- Mismo botón magenta del hero
- Mismo modal al click

**Counter:**

- Mismo texto que en hero, asegura consistencia

**Footer:**

Layout de 2 columnas (desktop) / stack vertical (mobile):

**Izquierda:**

- Wordmark "smwhr" pequeño en magenta (Space Grotesk 18px)
- Línea debajo: "Una venture de Orbit M" (Inter 13px, text-tertiary)

**Derecha:**

- Texto "Hecho en MX · 2026" (Inter 13px, text-tertiary)
- Iconos sociales debajo (mejor alineados verticalmente)

**Iconos sociales:**

- Twitter/X: `@smwhr`
- Instagram: `@smwhr.quest` o el que tengas

Tamaño: 18px stroke 1.5px, color text-tertiary, hover color text-secondary

---

## Implementación técnica

### Estructura de archivos actualizada

```
apps/landing/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── globals.css
│   ├── actions/
│   │   └── waitlist.ts
│   └── api/
│       └── stats/
│           └── route.ts
├── components/
│   ├── ui/                          # shadcn
│   │   ├── button.tsx
│   │   ├── dialog.tsx
│   │   ├── input.tsx
│   │   └── toggle-group.tsx
│   ├── sections/
│   │   ├── hero-section.tsx
│   │   ├── proof-section.tsx
│   │   ├── how-section.tsx
│   │   ├── catalog-section.tsx
│   │   └── final-cta-section.tsx
│   ├── shared/
│   │   ├── wordmark.tsx
│   │   ├── coordinate-badge.tsx
│   │   ├── waitlist-button.tsx
│   │   ├── waitlist-modal.tsx
│   │   ├── footer.tsx
│   │   ├── iphone-frame.tsx        # Reusable iPhone mockup
│   │   ├── badge-mock.tsx          # Mock de la insignia
│   │   └── category-card.tsx
│   └── icons/
│       ├── map-pin-icon.tsx
│       ├── timer-icon.tsx
│       └── shield-check-icon.tsx
├── lib/
│   ├── supabase.ts
│   ├── utils.ts
│   └── constants.ts
├── public/
│   ├── og-image.png
│   ├── favicon.svg
│   └── mockups/
│       ├── reveal-screen.png       # Pre-rendered screen mock
│       ├── quest-active-screen.png
│       └── camera-screen.png
└── package.json
```

### iPhone frame component reutilizable

`components/shared/iphone-frame.tsx`:

```typescript
import Image from 'next/image';

interface Props {
  screenSrc: string;
  alt: string;
  glowColor?: string;
  className?: string;
}

export function IPhoneFrame({
  screenSrc,
  alt,
  glowColor = '#FF2D95',
  className = '',
}: Props) {
  return (
    <div className={`relative ${className}`}>
      {/* Glow halo */}
      <div
        className="absolute inset-0 -inset-x-12 -inset-y-12 blur-3xl opacity-40 pointer-events-none"
        style={{
          background: `radial-gradient(ellipse, ${glowColor} 0%, transparent 70%)`,
        }}
        aria-hidden="true"
      />

      {/* iPhone body */}
      <div className="relative bg-[#1a1a1a] rounded-[3.5rem] p-2 shadow-2xl">
        <div className="bg-bg rounded-[3rem] overflow-hidden border border-[#2A2A2A]">
          {/* Notch / Dynamic Island */}
          <div className="relative h-8 flex items-center justify-center">
            <div className="absolute top-2 w-24 h-6 bg-black rounded-full" />
          </div>

          {/* Screen content */}
          <div className="relative aspect-[9/19.5]">
            <Image
              src={screenSrc}
              alt={alt}
              fill
              className="object-cover"
              priority
            />
          </div>
        </div>
      </div>
    </div>
  );
}
```

### Badge mock component

`components/shared/badge-mock.tsx`:

```typescript
interface Props {
  category?: string;
  serial?: string;
  total?: string;
  date?: string;
  venue?: string;
  glowColor?: string;
}

export function BadgeMock({
  category = 'CONCIERTO',
  serial = '01247',
  total = '47,832',
  date = '07 MAY 2026',
  venue = 'ESTADIO PRINCIPAL',
  glowColor = '#FF2D95',
}: Props) {
  return (
    <div className="relative max-w-sm">
      <div
        className="absolute inset-0 blur-3xl opacity-50"
        style={{
          background: `radial-gradient(ellipse, ${glowColor} 0%, transparent 70%)`,
        }}
      />

      <div className="relative bg-bg border border-border rounded-2xl p-6">
        {/* Top label */}
        <div className="flex justify-between items-center mb-4">
          <span className="font-mono text-[11px] text-text-tertiary tracking-wider">
            SMWHR
          </span>
          <span className="font-mono text-[11px] text-text-tertiary tracking-wider">
            {category}
          </span>
        </div>

        {/* Visual area with glow */}
        <div
          className="aspect-square rounded-xl mb-4 flex items-center justify-center"
          style={{
            background: `radial-gradient(ellipse 50% 60% at 50% 60%, ${glowColor}40 0%, transparent 70%)`,
          }}
        >
          {/* Silhouette */}
          <svg viewBox="0 0 200 100" className="w-3/4 h-auto">
            <path
              d="M 0 100 L 50 30 L 100 50 L 150 25 L 200 100 Z"
              fill="white"
              opacity="0.95"
            />
          </svg>
        </div>

        {/* Info */}
        <div className="space-y-1">
          <h3 className="font-display font-bold text-white text-lg">
            {venue}
          </h3>
          <p className="font-body text-text-secondary text-sm">
            CIUDAD DE MÉXICO · {date}
          </p>
        </div>

        {/* Serial */}
        <div className="mt-4 pt-4 border-t border-border flex justify-between items-center">
          <span className="font-mono text-[11px] text-text-tertiary">
            #{serial} OF {total}
          </span>
          <span className="font-mono text-[11px] text-accent">
            VERIFIED ✓
          </span>
        </div>
      </div>
    </div>
  );
}
```

### Mockups de pantallas

**Estrategia recomendada:** generar 3 screenshots PNG de las pantallas de la app usando Nano Banana o exportando los mocks de Figma una vez los tengas. Mientras tanto, puedes usar el componente `BadgeMock` directamente en el HTML como placeholder vivo.

**Imágenes finales:**

- `public/mockups/reveal-screen.png` (1170x2532 idealmente, 9:19.5 ratio)
- `public/mockups/quest-active-screen.png`
- `public/mockups/camera-screen.png`

Si todavía no tienes las pantallas listas en alta resolución, usa `BadgeMock` y composiciones HTML/Tailwind para simularlas. Eso de hecho es mejor que screenshots porque:

1. Pesa menos (HTML vs PNG)
2. Es responsive nativo
3. Se puede modificar sin re-exportar
4. Los textos quedan crisp en cualquier resolución

### Page principal con secciones

`app/page.tsx`:

```typescript
import { HeroSection } from '@/components/sections/hero-section';
import { ProofSection } from '@/components/sections/proof-section';
import { HowSection } from '@/components/sections/how-section';
import { CatalogSection } from '@/components/sections/catalog-section';
import { FinalCtaSection } from '@/components/sections/final-cta-section';
import { Footer } from '@/components/shared/footer';

export default function HomePage() {
  return (
    <main className="bg-bg text-text-primary">
      <HeroSection />
      <ProofSection />
      <HowSection />
      <CatalogSection />
      <FinalCtaSection />
      <Footer />
    </main>
  );
}
```

### Scroll snap (opcional pero recomendado)

`globals.css`:

```css
@layer base {
  html {
    scroll-behavior: smooth;
  }

  /* En desktop, scroll-snap por sección */
  @media (min-width: 1024px) {
    main {
      scroll-snap-type: y proximity;
    }

    section {
      scroll-snap-align: start;
      min-height: 100vh;
    }
  }
}
```

---

## Animaciones específicas

### Hero — flecha de scroll

```css
@keyframes bounce-soft {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(8px);
  }
}

.scroll-indicator {
  animation: bounce-soft 1.5s ease-in-out infinite;
}
```

### iPhone frames — float sutil

```css
@keyframes float {
  0%,
  100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-6px);
  }
}

.iphone-float {
  animation: float 4s ease-in-out infinite;
}
```

### Category cards — hover

```css
.category-card {
  transition: all 0.3s ease;
}

.category-card:hover {
  border-color: rgba(255, 45, 149, 0.3);
  transform: translateY(-2px);
}
```

### Sections — fade in on scroll

Usar `framer-motion` o `react-intersection-observer` para fade-in cuando entran en viewport:

```typescript
import { motion } from 'framer-motion';

<motion.div
  initial={{ opacity: 0, y: 20 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, margin: '-100px' }}
  transition={{ duration: 0.6, ease: 'easeOut' }}
>
  {content}
</motion.div>
```

---

## Performance

Con todas las secciones agregadas, mantener performance crítica:

- **Imágenes:** todas con `next/image`, lazy loading default, formato WebP/AVIF
- **Mockups:** si son PNG, optimizar bajo 200KB cada uno
- **Fuentes:** `font-display: swap` ya configurado
- **Bundle JS:** mantener bajo 100KB inicial. Server components donde posible.
- **Animaciones:** usar `transform` y `opacity` (GPU accelerated), evitar `width`, `height`, `top`, `left`

**Lighthouse targets actualizados:**

- Performance: ≥ 95 (era 95 en v1, mantener)
- LCP: < 1.5s (con mockups, era 1.0s en v1)
- CLS: < 0.05
- TBT: < 200ms

---

## Microcopy completo en español

Todos los strings de la landing en un solo lugar para revisión:

```typescript
// lib/copy.ts
export const COPY = {
  hero: {
    coordinates: "20.0850° N · -98.3630° W",
    headline1: "Estuviste ahí.",
    headline2: "Tenemos la prueba.",
    subtitle:
      "Una app que verifica tu asistencia a eventos en vivo y la convierte en una colección que es tuya.",
    cta: "Apúntate a la lista",
    counter: (n: number) => `${n} personas ya están dentro`,
    scrollHint: "Mira cómo funciona",
  },
  proof: {
    headline: "No es un check-in. Es prueba.",
    description:
      "GPS · Tiempo de permanencia · Integridad del dispositivo. Tres capas que aseguran que sí estuviste ahí.",
    chips: ["Ubicación", "Tiempo", "Integridad"],
  },
  how: {
    headline: "Tres pasos. Una historia.",
    steps: [
      {
        number: "01",
        title: "Llegas",
        description:
          "Marcas el evento. Llegamos cuando tú llegas. La app detecta el venue por GPS y activa la quest sola.",
      },
      {
        number: "02",
        title: "Te quedas",
        description:
          "60 minutos mínimo. Si te vas antes, no cuenta. Si te quedas, capturas un momento con la cámara que la app provee, no la galería.",
      },
      {
        number: "03",
        title: "Recibes",
        description:
          "Al terminar, tu insignia se genera con número de serie único. Se guarda en tu colección. Es tuya.",
      },
    ],
  },
  catalog: {
    headline1: "Toda la noche.",
    headline2: "Todos los partidos.",
    headline3: "Todas las cumbres.",
    categories: [
      { title: "Conciertos", subtitle: "Estadios y foros", color: "#FF2D95" },
      { title: "Partidos", subtitle: "Liga, copa, mundial", color: "#2DFF95" },
      { title: "Festivales", subtitle: "Multi-día", color: "#FF9D2D" },
      { title: "Outdoor", subtitle: "Cumbres y trails", color: "#2DC8FF" },
      { title: "Cultura", subtitle: "Teatro y arte", color: "#9D2DFF" },
      { title: "Lo que venga", subtitle: "Tu evento", color: "gradient" },
    ],
    description:
      "Cada categoría tiene su marco, su color, su lenguaje visual. Las insignias se sienten distintas porque la experiencia lo es.",
  },
  finalCta: {
    headline: "Vamos a empezar.",
    cta: "Apúntate a la lista",
  },
  footer: {
    location: "Hecho en MX · 2026",
    studio: "Una venture de Orbit M",
  },
  modal: {
    title: "Bienvenido a smwhr.",
    subtitle: "Te avisamos cuando estemos listos. Sin spam.",
    emailPlaceholder: "tu@correo.com",
    interestsLabel: "¿Qué eventos te mueven?",
    interests: ["Música", "Deportes", "Festivales", "Outdoor", "Todo"],
    submit: "Apúntame",
    submitting: "Apuntándote...",
    success: "Listo. Te vemos ahí.",
    successPosition: (n: number) => `Eres el #${n} en la lista.`,
    alreadyRegistered: "Ya estás en la lista. Te avisamos pronto.",
    error: "Algo falló. Inténtalo de nuevo.",
    legal1: "Al continuar aceptas los",
    legalTerms: "términos",
    legal2: "y la",
    legalPrivacy: "política de privacidad",
    legal3: ".",
  },
};
```

---

## Lo que hace que esta landing NO parezca template

**v1 problems → v2 solutions:**

| Problema v1            | Solución v2                      |
| ---------------------- | -------------------------------- |
| Demasiado vacía        | 5 secciones con sustancia        |
| No mostraba producto   | Sección Proof con mockup grande  |
| Faltaba "how it works" | Sección How con timeline visual  |
| No daba idea de scope  | Sección Catalog con 6 categorías |
| Footer pobre           | Footer con studio + social       |

**Cómo evitar template look:**

1. **Mockups con glow custom**, no genéricos
2. **Headlines poéticas multi-línea** ("Toda la noche. Todos los partidos.")
3. **Timeline vertical** en How en vez de grid horizontal
4. **Cards con ambient color hue propio** según categoría
5. **Animaciones sutiles**, nunca invasivas
6. **Cero stock photography** de gente
7. **Iconos custom** o de Phosphor con stroke 1.5px (no Heroicons default)
8. **Microcopy distintivo** ("Apúntate a la lista" vs "Join waitlist")
9. **Componentes hechos** desde scratch para identidad smwhr (BadgeMock, IPhoneFrame)
10. **Wordmark grande con glow magenta** que la mayoría de templates no se atreve

---

_Esta landing v2 es ventana viva del producto. Cada sección debe sentirse como statement editorial, no como vendor pitch._
