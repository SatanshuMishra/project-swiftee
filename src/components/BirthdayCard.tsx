import { motion, AnimatePresence } from "motion/react";
import { X, Cake } from "lucide-react";

interface BirthdayCardProps {
  readonly isOpen: boolean;
  readonly onClose: () => void;
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
              className="relative max-w-lg w-full"
            >
              {/* Close Button */}
              <button
                onClick={onClose}
                className="absolute -top-3 -right-3 z-10 p-2 rounded-full bg-card border-2 border-border shadow-lg hover:bg-muted transition-colors"
              >
                <X className="w-5 h-5" />
              </button>

              {/* Birthday Card */}
              <div className="flex flex-col max-h-[calc(100vh-2rem)] bg-gradient-to-br from-card to-muted/50 rounded-2xl shadow-2xl border-4 border-border overflow-hidden">
                {/* Card Header with decorative elements */}
                <div
                  className="relative shrink-0 bg-gradient-to-br from-[#e97f6a] to-[#FD5E53] p-5 pb-10 sm:p-8 sm:pb-12"
                  style={{
                    clipPath:
                      "polygon(0 0, 100% 0, 100% 100%, 50% calc(100% - 2rem), 0 100%)",
                  }}
                >
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
                      <Cake className="w-8 h-8" />
                      <Cake className="w-8 h-8" />
                    </motion.div>
                    <h2 className="text-2xl sm:text-3xl font-bold">
                      Happy Birthday!
                    </h2>
                  </div>
                </div>

                {/* Card Body */}
                <div className="flex-1 overflow-y-auto min-h-0 p-5 pt-4 sm:p-8 sm:pt-6 space-y-6 text-white text-base">
                  {/* Greeting */}
                  <p className="font-medium">Dear Ana,</p>

                  {/* Message */}
                  <div className="space-y-3">
                    <p className="leading-relaxed">
                      Sending you the warmest of wishes for a very Happy
                      Birthday!
                    </p>
                    <p className="leading-relaxed">
                      Thank you for always being there for me over these past
                      couple of years. I&apos;m very grateful and lucky to have
                      a friend like you.
                    </p>
                    <p className="leading-relaxed">
                      I&apos;ve said it before, and I&apos;ll say it again:
                      there is nothing you can&apos;t accomplish once you put
                      your mind to it. As you enter this next year, which will
                      hopefully be filled with exciting opportunities and
                      unforgettable memories, I have no doubt in my mind that
                      you will find success and reach the goals you set for
                      yourself!
                    </p>
                    <p className="leading-relaxed">
                      I can&apos;t wait to see what you accomplish in the year
                      ahead! Know that I am always rooting for you!
                    </p>
                  </div>

                  {/* Signature */}
                  <div className="pt-4">
                    <p className="text-[#e97f6a] mb-1">Your Best Friend,</p>
                    <p className="text-[#e97f6a]">Satanshu :)</p>
                  </div>

                  {/* P.S. */}
                  <p className="italic">P.S. Meowwwww Meow Meaaww ~ Clef</p>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
