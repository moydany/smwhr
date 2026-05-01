import { COPY } from "@/lib/copy";

export function CoordinateBadge() {
  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-border bg-surface/50 px-3 py-1.5 backdrop-blur-sm">
      <span
        aria-hidden="true"
        className="h-1.5 w-1.5 rounded-full bg-accent animate-pulse-soft"
      />
      <span className="font-mono text-[11px] tracking-wider text-text-tertiary">
        {COPY.hero.coordinates}
      </span>
    </div>
  );
}
