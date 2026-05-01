import { ChevronDown } from "lucide-react";
import { CoordinateBadge } from "@/components/shared/coordinate-badge";
import { WaitlistButton } from "@/components/shared/waitlist-button";
import { Wordmark } from "@/components/shared/wordmark";
import { COPY } from "@/lib/copy";

interface Props {
  count: number;
}

export function HeroSection({ count }: Props) {
  return (
    <section className="snap-section relative flex min-h-screen flex-col items-center justify-center overflow-hidden px-6 py-12 text-center sm:px-12">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(ellipse 60% 40% at 50% 35%, rgba(255, 45, 149, 0.15), transparent 70%)",
        }}
      />

      <div className="relative flex flex-col items-center">
        <CoordinateBadge />

        <div className="mt-12 mb-8">
          <Wordmark />
        </div>

        <h1 className="max-w-2xl font-display font-medium leading-[1.1] text-text-primary text-3xl sm:text-4xl md:text-5xl">
          {COPY.hero.headline1}
          <br />
          {COPY.hero.headline2}
        </h1>

        <p className="mt-8 max-w-md font-body leading-relaxed text-text-secondary text-base sm:text-lg">
          {COPY.hero.subtitle}
        </p>

        <div className="mt-10">
          <WaitlistButton label={COPY.hero.cta} />
        </div>

        {count > 0 && (
          <p className="mt-4 font-mono text-xs text-text-tertiary">
            {COPY.hero.counter(count)}
          </p>
        )}
      </div>

      <a
        href="#proof"
        className="absolute bottom-10 left-1/2 flex -translate-x-1/2 flex-col items-center gap-2 text-text-tertiary transition hover:text-text-secondary"
        aria-label={COPY.hero.scrollHint}
      >
        <ChevronDown
          className="h-4 w-4 animate-bounce-soft"
          strokeWidth={1.5}
        />
        <span className="font-mono text-[11px] tracking-wider">
          {COPY.hero.scrollHint}
        </span>
      </a>
    </section>
  );
}
