interface Props {
  category?: string;
  serial?: string;
  total?: string;
  date?: string;
  venue?: string;
  glowColor?: string;
}

export function BadgeMock({
  category = "CONCIERTO",
  serial = "01247",
  total = "47,832",
  date = "07 MAY 2026",
  venue = "ESTADIO PRINCIPAL",
  glowColor = "#FF2D95",
}: Props) {
  return (
    <div className="relative w-full max-w-sm">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 -z-10 opacity-50 blur-3xl"
        style={{
          background: `radial-gradient(ellipse, ${glowColor} 0%, transparent 70%)`,
        }}
      />

      <div className="relative rounded-2xl border border-border bg-bg p-6">
        <div className="mb-4 flex items-center justify-between">
          <span className="font-mono text-[11px] tracking-wider text-text-tertiary">
            SMWHR
          </span>
          <span className="font-mono text-[11px] tracking-wider text-text-tertiary">
            {category}
          </span>
        </div>

        <div
          className="mb-4 flex aspect-square items-center justify-center rounded-xl"
          style={{
            background: `radial-gradient(ellipse 50% 60% at 50% 60%, ${glowColor}40 0%, transparent 70%)`,
          }}
        >
          <svg
            viewBox="0 0 200 100"
            className="h-auto w-3/4"
            aria-hidden="true"
          >
            <path
              d="M 0 100 L 50 30 L 100 50 L 150 25 L 200 100 Z"
              fill="white"
              opacity="0.95"
            />
          </svg>
        </div>

        <div className="space-y-1">
          <h3 className="font-display text-lg font-bold text-text-primary">
            {venue}
          </h3>
          <p className="font-body text-sm text-text-secondary">
            CIUDAD DE MÉXICO · {date}
          </p>
        </div>

        <div className="mt-4 flex items-center justify-between border-t border-border pt-4">
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
