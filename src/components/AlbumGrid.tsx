import { useEffect } from "react";
import { useGameStore } from "../stores/gameStore";
import { useFetchAlbums } from "../hooks/useDeezer";

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
    <div className="flex min-h-screen flex-col items-center gap-6 p-8">
      <div className="flex w-full items-center justify-between">
        <button
          onClick={() => setPhase("menu")}
          className="text-sm"
          style={{ color: "var(--color-text-secondary)" }}
        >
          ← Back
        </button>
        <h2
          className="text-2xl font-bold"
          style={{ color: "var(--color-text-primary)" }}
        >
          Pick Albums
        </h2>
        <div className="w-12" />
      </div>

      {loading && (
        <p style={{ color: "var(--color-text-secondary)" }}>
          Loading albums...
        </p>
      )}

      {error && <p style={{ color: "var(--color-incorrect)" }}>{error}</p>}

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
        {albums.map((album) => {
          const selected = selectedAlbumIds.includes(album.id);
          return (
            <button
              key={album.id}
              onClick={() => toggleAlbum(album.id)}
              className="flex flex-col items-center gap-2 rounded-lg p-3 transition-all"
              style={{
                backgroundColor: "var(--color-surface)",
                border: selected
                  ? "2px solid var(--color-accent)"
                  : "2px solid var(--color-border)",
                opacity: selected ? 1 : 0.7,
              }}
            >
              {album.coverMedium ? (
                <img
                  src={album.coverMedium}
                  alt={album.title}
                  className="h-32 w-32 rounded object-cover"
                />
              ) : (
                <div
                  className="flex h-32 w-32 items-center justify-center rounded"
                  style={{ backgroundColor: "var(--color-border)" }}
                >
                  <span style={{ color: "var(--color-text-secondary)" }}>
                    ♪
                  </span>
                </div>
              )}
              <span
                className="text-center text-xs"
                style={{ color: "var(--color-text-primary)" }}
              >
                {album.title}
              </span>
            </button>
          );
        })}
      </div>

      {selectedAlbumIds.length > 0 && (
        <button
          onClick={handleStart}
          className="fixed bottom-8 rounded-lg px-8 py-3 text-lg font-bold text-white"
          style={{ backgroundColor: "var(--color-accent)" }}
        >
          Start Quiz ({selectedAlbumIds.length} album
          {selectedAlbumIds.length > 1 ? "s" : ""})
        </button>
      )}
    </div>
  );
}
