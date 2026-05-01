import { MapPin, ShieldCheck, Timer } from "lucide-react";
import { BadgeMock } from "@/components/shared/badge-mock";
import { IPhoneFrame } from "@/components/shared/iphone-frame";
import { COPY } from "@/lib/copy";

const ICONS = {
  "map-pin": MapPin,
  timer: Timer,
  "shield-check": ShieldCheck,
} as const;

export function ProofSection() {
  return (
    <section
      id="proof"
      className="snap-section relative flex min-h-screen items-center px-6 py-24 sm:px-12"
    >
      <div className="mx-auto flex w-full max-w-6xl flex-col items-center gap-16 lg:flex-row lg:items-center lg:justify-between lg:gap-20">
        <div className="order-2 flex w-full justify-center lg:order-1 lg:w-[42%]">
          <div className="w-full max-w-[280px]">
            <IPhoneFrame>
              <div className="flex h-full items-center justify-center bg-bg p-4">
                <BadgeMock />
              </div>
            </IPhoneFrame>
          </div>
        </div>

        <div className="order-1 max-w-xl space-y-8 text-center lg:order-2 lg:flex-1 lg:text-left">
          <h2 className="font-display font-medium leading-[1.05] text-text-primary text-4xl sm:text-5xl lg:text-[56px]">
            {COPY.proof.headline}
          </h2>

          <div className="flex flex-wrap justify-center gap-2 lg:justify-start">
            {COPY.proof.chips.map((chip) => {
              const Icon = ICONS[chip.icon];
              return (
                <div
                  key={chip.label}
                  className="inline-flex items-center gap-2 rounded-full border border-border bg-surface px-3.5 py-2"
                >
                  <Icon
                    className="h-3.5 w-3.5 text-text-secondary"
                    strokeWidth={1.5}
                  />
                  <span className="font-body text-xs text-text-secondary">
                    {chip.label}
                  </span>
                </div>
              );
            })}
          </div>

          <p className="font-body text-base leading-relaxed text-text-secondary sm:text-lg">
            {COPY.proof.description}
          </p>
        </div>
      </div>
    </section>
  );
}
