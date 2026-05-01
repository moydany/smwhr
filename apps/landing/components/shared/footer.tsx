import { Instagram, Twitter } from "lucide-react";
import { COPY } from "@/lib/copy";
import { Wordmark } from "./wordmark";

export function Footer() {
  return (
    <footer className="border-t border-surface-elevated px-6 py-10 sm:px-12">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 md:flex-row md:items-end md:justify-between">
        <div className="space-y-1">
          <Wordmark size="sm" />
          <p className="font-body text-xs text-text-tertiary">
            {COPY.footer.studio}
          </p>
        </div>

        <div className="flex items-center justify-between gap-6 md:flex-col md:items-end md:gap-3">
          <p className="font-body text-xs text-text-tertiary">
            {COPY.footer.location}
          </p>
          <div className="flex items-center gap-3">
            <a
              href={COPY.footer.twitter.url}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={`Twitter ${COPY.footer.twitter.handle}`}
              className="text-text-tertiary transition hover:text-text-secondary"
            >
              <Twitter className="h-[18px] w-[18px]" strokeWidth={1.5} />
            </a>
            <a
              href={COPY.footer.instagram.url}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={`Instagram ${COPY.footer.instagram.handle}`}
              className="text-text-tertiary transition hover:text-text-secondary"
            >
              <Instagram className="h-[18px] w-[18px]" strokeWidth={1.5} />
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
