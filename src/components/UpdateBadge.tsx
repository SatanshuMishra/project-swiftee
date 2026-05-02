import {
  Download,
  Loader2,
  AlertCircle,
  RefreshCcw,
  type LucideIcon,
} from "lucide-react";

import { useUpdater } from "../hooks/useUpdater";
import { cn } from "../lib/cn";
import type { UpdaterMachineState } from "../types";

interface UpdateBadgeProps {
  readonly onClick: () => void;
}

type VisibleKind = Extract<
  UpdaterMachineState,
  { kind: "available" | "downloading" | "ready" | "error" }
>["kind"];

interface BadgeVisuals {
  readonly Icon: LucideIcon;
  readonly colorClass: string;
  readonly spinning?: boolean;
}

const VARIANTS: Record<VisibleKind, BadgeVisuals> = {
  available: { Icon: Download, colorClass: "bg-violet-600" },
  downloading: { Icon: Loader2, colorClass: "bg-blue-600", spinning: true },
  ready: { Icon: RefreshCcw, colorClass: "bg-emerald-600" },
  error: { Icon: AlertCircle, colorClass: "bg-yellow-600" },
};

function labelFor(state: UpdaterMachineState): string {
  switch (state.kind) {
    case "available":
      return `Update available (${state.manifest.version})`;
    case "downloading":
      return `Downloading update… ${state.progress}%`;
    case "ready":
      return `Restart to install ${state.manifest.version}`;
    case "error":
      return "Update issue — click for details";
    default:
      return "";
  }
}

export function UpdateBadge({ onClick }: UpdateBadgeProps) {
  const { state } = useUpdater();
  const visible =
    state.kind === "available" ||
    state.kind === "downloading" ||
    state.kind === "ready" ||
    state.kind === "error";
  if (!visible) return null;

  const variant = VARIANTS[state.kind as VisibleKind];
  const label = labelFor(state);

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        "fixed bottom-6 right-6 z-40 flex items-center gap-2 rounded-full px-4 py-2 text-sm text-white shadow-lg transition-colors",
        variant.colorClass,
      )}
    >
      <variant.Icon
        className={cn("h-4 w-4", variant.spinning && "motion-safe:animate-spin")}
      />
      <span>{label}</span>
    </button>
  );
}
