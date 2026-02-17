import { motion, AnimatePresence } from "motion/react";
import { X, Mail, Cake } from "lucide-react";
import { SwiftieLogo } from "./SwiftieLogo";

interface BirthdayCardProps {
  readonly isOpen: boolean;
  readonly onClose: () => void;
}

function PenguinIcon({ className }: { readonly className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="currentColor"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <ellipse cx="12" cy="14" rx="6" ry="8" fill="currentColor" />
      <ellipse cx="12" cy="14" rx="4" ry="6" fill="white" />
      <circle cx="12" cy="6" r="4" fill="currentColor" />
      <circle cx="10.5" cy="6" r="0.8" fill="white" />
      <circle cx="13.5" cy="6" r="0.8" fill="white" />
      <circle cx="10.5" cy="6" r="0.4" fill="currentColor" />
      <circle cx="13.5" cy="6" r="0.4" fill="currentColor" />
      <path d="M 12 7.5 L 13 8.5 L 11 8.5 Z" fill="#FF9500" />
      <ellipse cx="7.5" cy="14" rx="1.5" ry="4" fill="currentColor" />
      <ellipse cx="16.5" cy="14" rx="1.5" ry="4" fill="currentColor" />
      <ellipse cx="10" cy="21.5" rx="1.5" ry="0.8" fill="#FF9500" />
      <ellipse cx="14" cy="21.5" rx="1.5" ry="0.8" fill="#FF9500" />
    </svg>
  );
}

export function BirthdayCard({ isOpen, onClose }: BirthdayCardProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          >
            {/* Card Container */}
            <motion.div
              initial={{ scale: 0.8, opacity: 0, rotateY: -15 }}
              animate={{ scale: 1, opacity: 1, rotateY: 0 }}
              exit={{ scale: 0.8, opacity: 0, rotateY: 15 }}
              transition={{ type: "spring", stiffness: 300, damping: 30 }}
              onClick={(e) => e.stopPropagation()}
              className="relative max-w-md w-full"
            >
              {/* Close Button */}
              <button
                onClick={onClose}
                className="absolute -top-3 -right-3 z-10 p-2 rounded-full bg-card border-2 border-border shadow-lg hover:bg-muted transition-colors"
              >
                <X className="w-5 h-5" />
              </button>

              {/* Birthday Card */}
              <div className="bg-gradient-to-br from-card to-muted/50 rounded-2xl shadow-2xl border-4 border-border overflow-hidden">
                {/* Postage Stamp */}
                <div className="absolute top-4 right-4 z-10">
                  <div className="relative">
                    <div
                      className="absolute inset-0 bg-gradient-to-br from-[#e97f6a] to-[#d96b56]"
                      style={{
                        clipPath:
                          "polygon(0 5%, 5% 5%, 5% 0, 10% 0, 10% 5%, 15% 5%, 15% 0, 20% 0, 20% 5%, 25% 5%, 25% 0, 30% 0, 30% 5%, 35% 5%, 35% 0, 40% 0, 40% 5%, 45% 5%, 45% 0, 50% 0, 50% 5%, 55% 5%, 55% 0, 60% 0, 60% 5%, 65% 5%, 65% 0, 70% 0, 70% 5%, 75% 5%, 75% 0, 80% 0, 80% 5%, 85% 5%, 85% 0, 90% 0, 90% 5%, 95% 5%, 95% 0, 100% 0, 100% 5%, 100% 10%, 95% 10%, 95% 15%, 100% 15%, 100% 20%, 95% 20%, 95% 25%, 100% 25%, 100% 30%, 95% 30%, 95% 35%, 100% 35%, 100% 40%, 95% 40%, 95% 45%, 100% 45%, 100% 50%, 95% 50%, 95% 55%, 100% 55%, 100% 60%, 95% 60%, 95% 65%, 100% 65%, 100% 70%, 95% 70%, 95% 75%, 100% 75%, 100% 80%, 95% 80%, 95% 85%, 100% 85%, 100% 90%, 95% 90%, 95% 95%, 100% 95%, 100% 100%, 95% 100%, 95% 95%, 90% 95%, 90% 100%, 85% 100%, 85% 95%, 80% 95%, 80% 100%, 75% 100%, 75% 95%, 70% 95%, 70% 100%, 65% 100%, 65% 95%, 60% 95%, 60% 100%, 55% 100%, 55% 95%, 50% 95%, 50% 100%, 45% 100%, 45% 95%, 40% 95%, 40% 100%, 35% 100%, 35% 95%, 30% 95%, 30% 100%, 25% 100%, 25% 95%, 20% 95%, 20% 100%, 15% 100%, 15% 95%, 10% 95%, 10% 100%, 5% 100%, 5% 95%, 0 95%, 0 90%, 5% 90%, 5% 85%, 0 85%, 0 80%, 5% 80%, 5% 75%, 0 75%, 0 70%, 5% 70%, 5% 65%, 0 65%, 0 60%, 5% 60%, 5% 55%, 0 55%, 0 50%, 5% 50%, 5% 45%, 0 45%, 0 40%, 5% 40%, 5% 35%, 0 35%, 0 30%, 5% 30%, 5% 25%, 0 25%, 0 20%, 5% 20%, 5% 15%, 0 15%, 0 10%, 5% 10%, 5% 5%, 0 5%)",
                      }}
                    />
                    <div className="relative w-16 h-20 flex flex-col items-center justify-center bg-gradient-to-br from-[#e97f6a] to-[#d96b56] p-2">
                      <SwiftieLogo size={32} className="mb-1" />
                      <div className="text-[8px] font-bold text-white/90 text-center leading-tight">
                        SWIFTIE
                        <br />
                        QUIZ
                      </div>
                    </div>
                  </div>
                </div>

                {/* Card Header with decorative elements */}
                <div className="relative bg-gradient-to-br from-[#e97f6a] to-[#d96b56] p-8 pb-12">
                  <div className="absolute top-4 left-4 w-20 h-20 rounded-full bg-white/10 blur-2xl" />
                  <div className="absolute bottom-4 right-8 w-32 h-32 rounded-full bg-white/10 blur-3xl" />

                  <div className="relative z-10 text-center text-white">
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      transition={{
                        delay: 0.3,
                        type: "spring",
                        stiffness: 300,
                        damping: 30,
                      }}
                      className="inline-flex items-center justify-center gap-2 mb-3"
                    >
                      <Cake className="w-8 h-8" />
                      <PenguinIcon className="w-7 h-7" />
                      <Cake className="w-8 h-8" />
                    </motion.div>
                    <h2 className="text-3xl font-bold mb-2">Happy Birthday!</h2>
                    <p className="text-white/90 text-sm">
                      A special message just for you
                    </p>
                  </div>

                  {/* Envelope flap effect */}
                  <div
                    className="absolute bottom-0 left-0 right-0 h-8 bg-card"
                    style={{
                      clipPath: "polygon(0 100%, 50% 0, 100% 100%)",
                    }}
                  />
                </div>

                {/* Card Body */}
                <div className="p-8 pt-6 space-y-6">
                  {/* Address To Section */}
                  <div className="flex items-center gap-3">
                    <div className="flex-shrink-0 p-2 rounded-lg bg-[#e97f6a]/10">
                      <Mail className="w-5 h-5 text-[#e97f6a]" />
                    </div>
                    <div className="flex-1 flex items-baseline gap-2">
                      <p className="text-sm text-muted-foreground">To:</p>
                      <p className="font-medium text-lg">Dear Swiftie</p>
                    </div>
                  </div>

                  {/* Message */}
                  <div className="space-y-3 pt-2">
                    <p className="text-muted-foreground leading-relaxed">
                      Wishing you a day filled with love, laughter, and all your
                      favorite Taylor Swift songs!
                    </p>
                    <p className="text-muted-foreground leading-relaxed">
                      May your year ahead be as magical as a surprise album drop
                      and as unforgettable as an Eras Tour concert!
                    </p>
                    <p className="text-muted-foreground leading-relaxed">
                      Keep being the amazing Swiftie you are! 🎉
                    </p>
                  </div>

                  {/* Signature */}
                  <div className="pt-4 text-right">
                    <p className="font-handwriting text-xl text-[#e97f6a] mb-1">
                      With Love...,
                    </p>
                    <p className="font-handwriting text-2xl text-[#e97f6a]">
                      Your Friend, Satanshu
                    </p>
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
