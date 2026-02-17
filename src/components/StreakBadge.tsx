import { Sparkles } from "lucide-react";

interface StreakBadgeProps {
  readonly streak: number;
}

export function StreakBadge({ streak }: StreakBadgeProps) {
  return (
    <div className="flex items-center gap-1.5 rounded-full border border-orange-500/20 bg-orange-500/10 px-3 py-1.5 text-sm font-medium text-orange-400">
      <Sparkles className="h-4 w-4" />
      {streak}
    </div>
  );
}
