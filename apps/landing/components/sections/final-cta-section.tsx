import { WaitlistButton } from "@/components/shared/waitlist-button";
import { COPY } from "@/lib/copy";

interface Props {
  count: number;
}

export function FinalCtaSection({ count }: Props) {
  return (
    <section className="snap-section relative flex min-h-[60vh] flex-col items-center justify-center overflow-hidden px-6 py-24 text-center sm:px-12">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(ellipse 50% 50% at 50% 50%, rgba(255, 45, 149, 0.12), transparent 70%)",
        }}
      />

      <div className="relative flex flex-col items-center">
        <h2 className="font-display font-medium leading-[1.05] text-text-primary text-4xl sm:text-5xl lg:text-[48px]">
          {COPY.finalCta.headline}
        </h2>

        <div className="mt-10">
          <WaitlistButton label={COPY.finalCta.cta} />
        </div>

        {count > 0 && (
          <p className="mt-4 font-mono text-xs text-text-tertiary">
            {COPY.hero.counter(count)}
          </p>
        )}
      </div>
    </section>
  );
}
