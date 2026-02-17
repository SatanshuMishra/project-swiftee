interface SwiftieLogoProps {
  readonly size?: number;
  readonly className?: string;
}

export function SwiftieLogo({ size = 80, className }: SwiftieLogoProps) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 64 64"
      width={size}
      height={size}
      aria-hidden="true"
      className={className}
    >
      <circle cx="32" cy="32" r="32" fill="#E97F6A" />
      <g fill="#ffffff" transform="translate(18, 12)">
        <rect x="20" y="0" width="4" height="28" rx="2" />
        <circle cx="8" cy="34" r="8" />
        <rect x="20" y="0" width="10" height="4" rx="2" />
      </g>
    </svg>
  );
}
