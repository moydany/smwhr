import { BadgeMock } from "@/components/shared/badge-mock";
import { IPhoneFrame } from "@/components/shared/iphone-frame";
import { COPY } from "@/lib/copy";
import { cn } from "@/lib/utils";

function QuestActiveScreen() {
  return (
    <div className="flex h-full flex-col bg-bg p-6">
      <div className="flex items-center justify-between">
        <span className="font-mono text-[10px] uppercase tracking-wider text-text-tertiary">
          Quest activa
        </span>
        <span className="flex items-center gap-1.5 font-mono text-[10px] text-accent">
          <span className="h-1.5 w-1.5 animate-pulse-soft rounded-full bg-accent" />
          LIVE
        </span>
      </div>

      <div className="mt-12 flex flex-1 flex-col items-center justify-center text-center">
        <span className="font-mono text-[10px] uppercase tracking-wider text-text-tertiary">
          Tiempo en venue
        </span>
        <p className="mt-2 font-display text-4xl font-bold tabular-nums text-text-primary">
          00:42:18
        </p>
        <p className="mt-6 max-w-[14rem] font-body text-xs text-text-secondary">
          Te faltan 17 minutos para asegurar la insignia.
        </p>
      </div>

      <div className="space-y-2">
        <div className="rounded-lg border border-border bg-surface px-3 py-2">
          <span className="font-mono text-[10px] uppercase text-text-tertiary">
            Ubicación
          </span>
          <p className="mt-0.5 font-body text-xs text-text-primary">
            Dentro del perímetro
          </p>
        </div>
        <div className="rounded-lg border border-border bg-surface px-3 py-2">
          <span className="font-mono text-[10px] uppercase text-text-tertiary">
            Integridad
          </span>
          <p className="mt-0.5 font-body text-xs text-text-primary">
            Verificada
          </p>
        </div>
      </div>
    </div>
  );
}

function CameraScreen() {
  return (
    <div className="relative flex h-full flex-col bg-black">
      <div className="absolute inset-x-0 top-0 z-10 flex items-center justify-between p-4">
        <span className="font-mono text-[10px] uppercase tracking-wider text-white/60">
          Cámara smwhr
        </span>
        <span className="font-mono text-[10px] uppercase tracking-wider text-white/60">
          EXIF ON
        </span>
      </div>

      <div className="flex-1 bg-gradient-to-b from-surface-elevated via-surface to-bg">
        <div className="flex h-full items-center justify-center">
          <div className="h-32 w-32 rounded-2xl border-2 border-dashed border-white/20" />
        </div>
      </div>

      <div className="absolute inset-x-0 bottom-0 z-10 flex items-center justify-center pb-10">
        <div className="flex h-16 w-16 items-center justify-center rounded-full border-2 border-white/40">
          <div className="h-12 w-12 rounded-full bg-white" />
        </div>
      </div>
    </div>
  );
}

const SCREENS = [QuestActiveScreen, CameraScreen, null] as const;

export function HowSection() {
  return (
    <section className="snap-section relative px-6 py-24 sm:px-12">
      <div className="mx-auto max-w-6xl">
        <h2 className="text-center font-display font-medium leading-[1.05] text-text-primary text-4xl sm:text-5xl lg:text-[56px]">
          {COPY.how.headline}
        </h2>

        <div className="relative mt-20 space-y-24">
          <div
            aria-hidden="true"
            className="pointer-events-none absolute left-1/2 top-12 hidden h-[calc(100%-6rem)] w-px -translate-x-1/2 bg-border lg:block"
          />

          {COPY.how.steps.map((step, index) => {
            const Screen = SCREENS[index];
            const isAlternate = index % 2 === 1;

            return (
              <div
                key={step.number}
                className={cn(
                  "relative flex flex-col items-center gap-12 lg:flex-row lg:items-center lg:gap-20",
                  isAlternate && "lg:flex-row-reverse",
                )}
              >
                <div className="flex w-full max-w-[260px] justify-center lg:w-[40%]">
                  <IPhoneFrame>
                    {Screen ? (
                      <Screen />
                    ) : (
                      <div className="flex h-full items-center justify-center bg-bg p-4">
                        <BadgeMock />
                      </div>
                    )}
                  </IPhoneFrame>
                </div>

                <div
                  className={cn(
                    "max-w-md space-y-3 text-center lg:flex-1 lg:text-left",
                    isAlternate && "lg:text-right",
                  )}
                >
                  <p className="font-mono text-5xl font-bold text-accent-muted">
                    {step.number}
                  </p>
                  <h3 className="font-display text-3xl font-medium text-text-primary sm:text-[32px]">
                    {step.title}
                  </h3>
                  <p className="font-body text-base leading-relaxed text-text-secondary sm:text-[17px]">
                    {step.description}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
