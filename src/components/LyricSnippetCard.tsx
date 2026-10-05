import { motion } from "motion/react";
import { cn } from "../lib/cn";

interface LyricSnippetCardProps {
  readonly lines: readonly string[];
  readonly className?: string;
}

export function LyricSnippetCard({ lines, className }: LyricSnippetCardProps) {
  const keyedLines = lines.map((line, position) => ({
    line,
    key: `${lines.slice(0, position).filter((earlier) => earlier === line).length}:${line}`,
  }));

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: "spring", stiffness: 300, damping: 30 }}
      className={cn("rounded-2xl border border-border bg-card p-6", className)}
    >
      <div className="flex flex-col gap-3">
        {keyedLines.map(({ line, key }) => (
          <p
            key={key}
            className="text-center text-lg italic leading-relaxed text-foreground"
            style={{ lineHeight: 1.8 }}
          >
            &ldquo;{line}&rdquo;
          </p>
        ))}
      </div>
    </motion.div>
  );
}
