import { useEffect, useRef, useState } from "react";

interface TimerProps {
  readonly duration: number;
  readonly onExpire: () => void;
  readonly active: boolean;
}

export function Timer({ duration, onExpire, active }: TimerProps) {
  const [remaining, setRemaining] = useState(duration);
  const onExpireRef = useRef(onExpire);
  onExpireRef.current = onExpire;

  useEffect(() => {
    setRemaining(duration);
  }, [duration]);

  useEffect(() => {
    if (!active) return;

    const interval = setInterval(() => {
      setRemaining((prev) => {
        const next = prev - 0.1;
        if (next <= 0) {
          clearInterval(interval);
          onExpireRef.current();
          return 0;
        }
        return next;
      });
    }, 100);

    return () => clearInterval(interval);
  }, [active]);

  const percentage = (remaining / duration) * 100;
  const color =
    remaining > duration * 0.3
      ? "var(--color-accent)"
      : "var(--color-incorrect)";

  return (
    <div className="flex flex-col items-center gap-1">
      <div
        className="h-2 w-full overflow-hidden rounded-full"
        style={{ backgroundColor: "var(--color-border)" }}
      >
        <div
          className="h-full rounded-full transition-all"
          style={{
            width: `${percentage}%`,
            backgroundColor: color,
          }}
        />
      </div>
      <span className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
        {Math.ceil(remaining)}s remaining
      </span>
    </div>
  );
}
