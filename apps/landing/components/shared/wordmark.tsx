interface Props {
  size?: "default" | "sm";
}

export function Wordmark({ size = "default" }: Props) {
  if (size === "sm") {
    return (
      <span className="font-display text-lg font-bold tracking-tight text-accent">
        smwhr
      </span>
    );
  }

  return (
    <div className="relative inline-block">
      <div
        aria-hidden="true"
        className="absolute inset-0 -z-10 blur-3xl opacity-50"
        style={{
          background:
            "radial-gradient(ellipse, #FF2D95 0%, transparent 70%)",
          transform: "scale(1.5)",
        }}
      />

      <span
        className="relative block font-display font-bold leading-none text-accent"
        style={{
          fontSize: "clamp(80px, 14vw, 160px)",
          letterSpacing: "-0.04em",
        }}
      >
        smwhr
      </span>
    </div>
  );
}
