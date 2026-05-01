import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface Props {
  children: ReactNode;
  glowColor?: string;
  className?: string;
  float?: boolean;
}

export function IPhoneFrame({
  children,
  glowColor = "#FF2D95",
  className,
  float = true,
}: Props) {
  return (
    <div className={cn("relative", className)}>
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -inset-12 -z-10 opacity-40 blur-3xl"
        style={{
          background: `radial-gradient(ellipse, ${glowColor} 0%, transparent 70%)`,
        }}
      />

      <div
        className={cn(
          "relative rounded-[3.5rem] bg-surface-elevated p-2 shadow-2xl",
          float && "animate-float",
        )}
      >
        <div className="overflow-hidden rounded-[3rem] border border-border bg-bg">
          <div className="relative flex h-8 items-center justify-center">
            <div className="absolute top-2 h-6 w-24 rounded-full bg-black" />
          </div>

          <div className="relative aspect-[9/19.5]">{children}</div>
        </div>
      </div>
    </div>
  );
}
