"use client";

import { Check } from "lucide-react";
import { useState } from "react";
import { joinWaitlist } from "@/app/actions/waitlist";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { COPY } from "@/lib/copy";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

type Status = "idle" | "loading" | "success" | "error";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function WaitlistModal({ open, onOpenChange }: Props) {
  const [email, setEmail] = useState("");
  const [interests, setInterests] = useState<string[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [position, setPosition] = useState<number | null>(null);
  const [alreadyRegistered, setAlreadyRegistered] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const reset = () => {
    setEmail("");
    setInterests([]);
    setStatus("idle");
    setPosition(null);
    setAlreadyRegistered(false);
    setErrorMessage(null);
  };

  const handleOpenChange = (next: boolean) => {
    onOpenChange(next);
    if (!next) {
      setTimeout(reset, 250);
    }
  };

  const handleInterestsChange = (value: string[]) => {
    if (value.includes("all") && !interests.includes("all")) {
      setInterests(["all"]);
      return;
    }

    if (interests.includes("all") && value.length > 1) {
      setInterests(value.filter((v) => v !== "all"));
      return;
    }

    setInterests(value);
  };

  const handleSubmit = async () => {
    setStatus("loading");
    setErrorMessage(null);

    try {
      const result = await joinWaitlist({ email, interests });

      if (!result.success) {
        setStatus("error");
        setErrorMessage(result.message ?? COPY.modal.error);
        return;
      }

      setStatus("success");
      setPosition(result.position ?? null);
      setAlreadyRegistered(Boolean(result.alreadyRegistered));

      setTimeout(() => {
        handleOpenChange(false);
      }, 2500);
    } catch {
      setStatus("error");
      setErrorMessage(COPY.modal.error);
    }
  };

  const isValidEmail = EMAIL_REGEX.test(email);

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-w-md rounded-2xl border-border bg-surface p-8 text-text-primary">
        {status === "success" ? (
          <div className="py-6 text-center">
            <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-accent/15 ring-1 ring-accent/30">
              <Check className="h-6 w-6 text-accent" strokeWidth={2} />
            </div>
            <h2 className="font-display text-2xl font-medium text-text-primary">
              {alreadyRegistered
                ? COPY.modal.alreadyRegistered
                : COPY.modal.success}
            </h2>
            {position && !alreadyRegistered && (
              <p className="mt-2 text-text-secondary">
                {COPY.modal.successPosition(position)}
              </p>
            )}
          </div>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle className="font-display text-2xl font-medium text-text-primary">
                {COPY.modal.title}
              </DialogTitle>
              <DialogDescription className="text-base text-text-secondary">
                {COPY.modal.subtitle}
              </DialogDescription>
            </DialogHeader>

            <div className="mt-6 space-y-6">
              <Input
                type="email"
                inputMode="email"
                autoComplete="email"
                placeholder={COPY.modal.emailPlaceholder}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={status === "loading"}
                className="h-12 rounded-xl border-border bg-bg text-base text-text-primary placeholder:text-text-tertiary focus-visible:border-accent focus-visible:ring-accent/40"
              />

              <div className="space-y-3">
                <label className="block font-body text-[11px] uppercase tracking-wider text-text-secondary">
                  {COPY.modal.interestsLabel}
                </label>
                <ToggleGroup
                  type="multiple"
                  value={interests}
                  onValueChange={handleInterestsChange}
                  className="flex flex-wrap justify-start gap-2"
                  disabled={status === "loading"}
                >
                  {COPY.modal.interests.map((cat) => (
                    <ToggleGroupItem
                      key={cat.value}
                      value={cat.value}
                      aria-label={cat.label}
                      className="rounded-full border border-border px-4 text-sm text-text-secondary transition hover:border-text-tertiary hover:text-text-primary data-[state=on]:border-accent data-[state=on]:bg-accent data-[state=on]:text-bg"
                    >
                      {cat.label}
                    </ToggleGroupItem>
                  ))}
                </ToggleGroup>
              </div>

              <Button
                type="button"
                onClick={handleSubmit}
                disabled={!isValidEmail || status === "loading"}
                className="h-12 w-full rounded-xl bg-accent text-base font-medium text-bg transition-all hover:bg-accent hover:shadow-[0_0_40px_rgba(255,45,149,0.35)] disabled:opacity-50 disabled:hover:shadow-none"
              >
                {status === "loading" ? COPY.modal.submitting : COPY.modal.submit}
              </Button>

              {status === "error" && errorMessage && (
                <p className="text-center text-sm text-red-400">
                  {errorMessage}
                </p>
              )}

              <p className="text-center text-xs leading-relaxed text-text-tertiary">
                {COPY.modal.legal1}{" "}
                <a
                  href="/terms"
                  className="underline underline-offset-2 hover:text-text-secondary"
                >
                  {COPY.modal.legalTerms}
                </a>{" "}
                {COPY.modal.legal2}{" "}
                <a
                  href="/privacy"
                  className="underline underline-offset-2 hover:text-text-secondary"
                >
                  {COPY.modal.legalPrivacy}
                </a>
                {COPY.modal.legal3}
              </p>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
