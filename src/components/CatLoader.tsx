import "./CatLoader.css";

interface CatLoaderProps {
  readonly size?: "sm" | "lg";
  readonly label?: string;
}

export function CatLoader({ size = "lg", label }: CatLoaderProps) {
  const scale = size === "sm" ? 0.27 : 1;

  return (
    <div className="flex flex-col items-center gap-4">
      <div
        className="loading-cat"
        style={{
          transform: `scale(${scale})`,
          width: 480 * scale,
          height: 360 * scale,
        }}
      >
        <div className="loading-cat__body" />
        <div className="loading-cat__head">
          <div className="loading-cat__face" />
        </div>
        <div className="loading-cat__foot">
          <div className="loading-cat__tummy-end" />
          <div className="loading-cat__bottom" />
          <div className="loading-cat__legs loading-cat__legs--left" />
          <div className="loading-cat__legs loading-cat__legs--right" />
        </div>
        <div className="loading-cat__hands loading-cat__hands--left" />
        <div className="loading-cat__hands loading-cat__hands--right" />
      </div>
      {label && (
        <p className="text-sm font-medium text-muted-foreground">{label}</p>
      )}
    </div>
  );
}
