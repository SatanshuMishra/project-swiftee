import { useEffect } from "react";
import { motion } from "motion/react";
import { ArrowLeft } from "lucide-react";
import { useGameStore } from "../stores/gameStore";
import { useFetchAlbums } from "../hooks/useDeezer";
import { LoadingGate } from "./LoadingGate";
import { cn } from "../lib/cn";

export function AlbumGrid() {
  const albums = useGameStore((s) => s.albums);
  const selectedAlbumIds = useGameStore((s) => s.selectedAlbumIds);
  const toggleAlbum = useGameStore((s) => s.toggleAlbum);
  const setAlbums = useGameStore((s) => s.setAlbums);
  const setPhase = useGameStore((s) => s.setPhase);
  const { data, loading, error, fetch } = useFetchAlbums();

  useEffect(() => {
    if (albums.length === 0) {
      fetch();
    }
  }, [albums.length, fetch]);

  useEffect(() => {
    if (data) {
      setAlbums(data);
    }
  }, [data, setAlbums]);

  const handleStart = () => {
    if (selectedAlbumIds.length > 0) {
      setPhase("difficulty-select");
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center gap-8 bg-gradient-to-br from-background to-muted/20 p-8">
      {/* Header */}
      <div className="flex w-full max-w-5xl items-center justify-between">
        <motion.button
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ type: "spring", stiffness: 300, damping: 30 }}
          onClick={() => setPhase("menu")}
          className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back
        </motion.button>
        <div />
      </div>

      {/* Title */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        className="text-center"
      >
        <h2 className="text-4xl font-bold tracking-tight">Pick Albums</h2>
        <p className="mt-2 text-muted-foreground">
          Select the albums you want to be quizzed on
        </p>
      </motion.div>

      {error && <p className="text-incorrect">{error}</p>}

      <LoadingGate
        loading={loading && albums.length === 0}
        label="Loading albums..."
      >
        {/* Album Grid */}
        <div className="grid w-full max-w-5xl grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {albums.map((album, index) => {
            const selected = selectedAlbumIds.includes(album.id);
            return (
              <motion.button
                key={album.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{
                  delay: Math.min(index * 0.03, 0.5),
                  type: "spring",
                  stiffness: 300,
                  damping: 30,
                }}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.97 }}
                onClick={() => toggleAlbum(album.id)}
                className={cn(
                  "group relative flex flex-col overflow-hidden rounded-2xl",
                  "bg-card border transition-[color,background-color,border-color,box-shadow,opacity] duration-300",
                  "hover:shadow-xl",
                  selected
                    ? "border-primary ring-2 ring-primary/20"
                    : "border-border opacity-70",
                )}
              >
                {/* Album art */}
                {album.coverMedium ? (
                  <div className="relative aspect-square w-full overflow-hidden">
                    <img
                      src={album.coverMedium}
                      alt={album.title}
                      className="h-full w-full object-cover"
                    />
                    {/* Gradient overlay */}
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
                    {/* Album info over overlay */}
                    <div className="absolute bottom-0 left-0 right-0 p-3">
                      <p className="truncate text-sm font-semibold text-white">
                        {album.title}
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="flex aspect-square w-full items-center justify-center bg-muted">
                    <span className="text-2xl text-muted-foreground">
                      &#9835;
                    </span>
                  </div>
                )}
              </motion.button>
            );
          })}
        </div>

        {/* Start button */}
        {selectedAlbumIds.length > 0 && (
          <motion.button
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.97 }}
            onClick={handleStart}
            className="fixed bottom-8 rounded-xl bg-primary px-8 py-3 text-lg font-bold text-primary-foreground shadow-lg transition-[color,background-color,border-color,box-shadow,opacity]"
          >
            Start Quiz ({selectedAlbumIds.length} album
            {selectedAlbumIds.length > 1 ? "s" : ""})
          </motion.button>
        )}
      </LoadingGate>
    </div>
  );
}
