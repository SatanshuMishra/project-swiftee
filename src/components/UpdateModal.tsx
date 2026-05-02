import type { ButtonHTMLAttributes, ReactNode } from "react";
import { useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";

import { useUpdater } from "../hooks/useUpdater";

interface UpdateModalProps {
  readonly isOpen: boolean;
  readonly onClose: () => void;
}

export function UpdateModal({ isOpen, onClose }: UpdateModalProps) {
  const updater = useUpdater();

  useEffect(() => {
    if (!isOpen) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-6"
        onClick={onClose}
      >
        <motion.div
          initial={{ scale: 0.95, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.95, opacity: 0 }}
          className="w-full max-w-lg rounded-2xl border border-border bg-card p-6 shadow-2xl"
          onClick={(e) => e.stopPropagation()}
          role="dialog"
          aria-modal="true"
        >
          <ModalContent updater={updater} onClose={onClose} />
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

function ModalContent({
  updater,
  onClose,
}: {
  readonly updater: ReturnType<typeof useUpdater>;
  readonly onClose: () => void;
}) {
  const { state } = updater;

  if (state.kind === "available") {
    return (
      <>
        <Header title={`Version ${state.manifest.version} available`} />
        <Notes notes={state.manifest.notes} />
        <Actions>
          <Primary onClick={() => updater.download()}>Download</Primary>
          <Secondary onClick={() => updater.skipVersion(state.manifest.version)}>
            Skip this version
          </Secondary>
          <Secondary onClick={() => updater.remindLater()}>Remind me later</Secondary>
          <Tertiary onClick={onClose}>Close</Tertiary>
        </Actions>
      </>
    );
  }

  if (state.kind === "downloading") {
    return (
      <>
        <Header title={`Downloading ${state.manifest.version}`} />
        <ProgressBar value={state.progress} />
        <Actions>
          <Tertiary onClick={onClose}>Hide</Tertiary>
        </Actions>
      </>
    );
  }

  if (state.kind === "ready") {
    return (
      <>
        <Header title={`Version ${state.manifest.version} ready`} />
        <p className="text-muted-foreground">
          Restart the app to apply the update.
        </p>
        <Actions>
          <Primary onClick={() => updater.install()}>Install &amp; Restart</Primary>
          <Tertiary onClick={onClose}>Close</Tertiary>
        </Actions>
      </>
    );
  }

  if (state.kind === "error") {
    if (state.subtype === "signature") {
      return (
        <>
          <Header title="Update verification failed" tone="danger" />
          <p className="rounded-md bg-red-500/10 p-3 text-sm text-red-200">
            The downloaded update could not be verified. The download may be
            corrupted or the release may be misconfigured.
          </p>
          <Actions>
            <Primary onClick={() => updater.dismiss()}>Dismiss</Primary>
          </Actions>
        </>
      );
    }
    const subtype = state.subtype;
    return (
      <>
        <Header title="Update failed" tone="warn" />
        <p className="rounded-md bg-yellow-500/10 p-3 text-sm text-yellow-200">
          {state.message}
        </p>
        <Actions>
          <Primary
            onClick={() =>
              subtype === "download" ? updater.download() : updater.install()
            }
          >
            Retry
          </Primary>
          <Tertiary onClick={() => updater.dismiss()}>Close</Tertiary>
        </Actions>
      </>
    );
  }

  // idle / checking / up-to-date / installing — no body to show, just close
  return (
    <>
      <Header title="No update information" />
      <Actions>
        <Tertiary onClick={onClose}>Close</Tertiary>
      </Actions>
    </>
  );
}

function Header({
  title,
  tone = "default",
}: {
  readonly title: string;
  readonly tone?: "default" | "warn" | "danger";
}) {
  const color =
    tone === "danger"
      ? "text-red-200"
      : tone === "warn"
        ? "text-yellow-200"
        : "text-foreground";
  return <h2 className={`mb-3 text-xl font-semibold ${color}`}>{title}</h2>;
}

function Notes({ notes }: { readonly notes: string }) {
  return (
    <pre className="mb-4 max-h-64 overflow-y-auto whitespace-pre-wrap rounded-md bg-muted/40 p-3 text-sm text-muted-foreground">
      {notes || "(no release notes provided)"}
    </pre>
  );
}

function ProgressBar({ value }: { readonly value: number }) {
  return (
    <div
      role="progressbar"
      aria-valuenow={value}
      aria-valuemin={0}
      aria-valuemax={100}
      className="my-4 h-2 w-full overflow-hidden rounded-full bg-muted"
    >
      <div
        className="h-full bg-blue-600 transition-all"
        style={{ width: `${value}%` }}
      />
    </div>
  );
}

function Actions({ children }: { readonly children: ReactNode }) {
  return (
    <div className="mt-4 flex flex-wrap justify-end gap-2">{children}</div>
  );
}

function Primary(props: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      {...props}
      className="rounded-md bg-violet-600 px-4 py-2 text-sm font-medium text-white hover:bg-violet-700"
    />
  );
}

function Secondary(props: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      {...props}
      className="rounded-md border border-border bg-card px-4 py-2 text-sm hover:bg-muted/40"
    />
  );
}

function Tertiary(props: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      {...props}
      className="rounded-md px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
    />
  );
}
