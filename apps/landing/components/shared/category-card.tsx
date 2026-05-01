import { cn } from "@/lib/utils";

interface Props {
  title: string;
  subtitle: string;
  color: string;
}

export function CategoryCard({ title, subtitle, color }: Props) {
  const isGradient = color === "gradient";

  const ambient = isGradient
    ? "conic-gradient(from 180deg at 50% 50%, #FF2D95, #2DC8FF, #9D2DFF, #FF9D2D, #FF2D95)"
    : `radial-gradient(circle, ${color} 0%, transparent 70%)`;

  return (
    <div
      className={cn(
        "group relative h-[220px] overflow-hidden rounded-2xl border border-border bg-surface p-8 transition-all duration-300",
        "hover:-translate-y-0.5 hover:border-accent/30",
      )}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -right-12 -top-12 h-48 w-48 opacity-40 blur-2xl transition-all duration-500 group-hover:scale-125 group-hover:opacity-70"
        style={{ background: ambient }}
      />

      <div className="relative flex h-full flex-col">
        <span
          aria-hidden="true"
          className="block h-2 w-2 rounded-full"
          style={{
            background: isGradient ? "#FF2D95" : color,
            boxShadow: `0 0 12px ${isGradient ? "#FF2D95" : color}`,
          }}
        />

        <div className="mt-auto">
          <h3 className="font-body text-[22px] font-medium text-text-primary">
            {title}
          </h3>
          <p className="mt-1 font-mono text-xs text-text-tertiary">
            {subtitle}
          </p>
        </div>
      </div>
    </div>
  );
}
