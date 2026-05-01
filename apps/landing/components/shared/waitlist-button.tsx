"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { COPY } from "@/lib/copy";
import { WaitlistModal } from "./waitlist-modal";

interface Props {
  label?: string;
}

export function WaitlistButton({ label = COPY.hero.cta }: Props) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <Button
        type="button"
        onClick={() => setOpen(true)}
        className="rounded-xl bg-accent px-8 py-6 text-base font-medium text-bg shadow-[0_0_40px_rgba(255,45,149,0.25)] transition-all hover:scale-[1.02] hover:bg-accent hover:shadow-[0_0_60px_rgba(255,45,149,0.4)] focus-visible:ring-accent"
      >
        {label}
      </Button>

      <WaitlistModal open={open} onOpenChange={setOpen} />
    </>
  );
}
