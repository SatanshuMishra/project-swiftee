import { Download, Loader2, AlertCircle, RefreshCcw } from "lucide-react";
import type { ComponentType, SVGProps } from "react";

import { useUpdater } from "../hooks/useUpdater";
import { cn } from "../lib/cn";

interface UpdateBadgeProps {
  readonly onClick: () => void;
}

type IconType = ComponentType<SVGProps<SVGSVGElement>>;

export function UpdateBadge({ onClick }: UpdateBadgeProps) {
  const { state } = useUpdater();
  const visible =
    state.kind === "available" ||
    state.kind === "downloading" ||
    state.kind === "ready" ||
    state.kind === "error";

  if (!visible) return null;

  let label: string;
  let Icon: IconType;
  let colorClass: string;

  switch (state.kind) {
    case "available":
      label = `Update available (${state.manifest.version})`;
      Icon = Download;
      colorClass = "bg-violet-600";
      break;
    case "downloading":
      label = `Downloading update… ${state.progress}%`;
      Icon = Loader2;
      colorClass = "bg-blue-600";
      break;
    case "ready":
      label = `Restart to install ${state.manifest.version}`;
      Icon = RefreshCcw;
      colorClass = "bg-emerald-600";
      break;
    case "error":
      label = "Update issue — click for details";
      Icon = AlertCircle;
      colorClass = "bg-yellow-600";
      break;
  }

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={cn(
        "fixed bottom-6 right-6 z-40 flex items-center gap-2 rounded-full px-4 py-2 text-sm text-white shadow-lg transition-colors",
        colorClass,
      )}
    >
      <Icon
        className={cn(
          "h-4 w-4",
          state.kind === "downloading" && "animate-spin",
        )}
      />
      <span>{label}</span>
    </button>
  );
}
