import { useState, useCallback, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { CatLoader } from "./CatLoader";

interface LoadingGateProps {
  readonly loading: boolean;
  readonly children: React.ReactNode;
  readonly size?: "sm" | "lg";
  readonly label?: string;
  readonly onReady?: () => void;
}

/**
 * Orchestrates a smooth transition between a loading animation and content.
 *
 * When `loading` transitions from true → false, the cat loader fades out first,
 * then `onReady` fires, then children fade in. This ensures side effects like
 * audio playback can be deferred until the visual transition is complete.
 */
export function LoadingGate({
  loading,
  children,
  size = "lg",
  label,
  onReady,
}: LoadingGateProps) {
  const [showContent, setShowContent] = useState(!loading);
  const onReadyRef = useRef(onReady);
  onReadyRef.current = onReady;
  const loadingRef = useRef(loading);
  loadingRef.current = loading;

  // When loading becomes true, hide content immediately
  useEffect(() => {
    if (loading) {
      setShowContent(false);
    }
  }, [loading]);

  const handleExitComplete = useCallback(() => {
    // Use ref to avoid stale closure if loading toggled during animation
    if (!loadingRef.current) {
      setShowContent(true);
      onReadyRef.current?.();
    }
  }, []);

  return (
    <AnimatePresence mode="wait" onExitComplete={handleExitComplete}>
      {loading ? (
        <motion.div
          key="loader"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          transition={{ duration: 0.3 }}
          className="flex flex-1 w-full items-center justify-center"
        >
          <CatLoader size={size} label={label} />
        </motion.div>
      ) : showContent ? (
        <motion.div
          key="content"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.3 }}
        >
          {children}
        </motion.div>
      ) : null}
    </AnimatePresence>
  );
}
