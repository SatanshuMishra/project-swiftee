interface CatIconButtonProps {
  readonly onClick: () => void;
  readonly className?: string;
  readonly size?: number;
}

/**
 * Full-body Siamese cat icon button. Source: src/assets/cat-icon.svg.
 * Uses the CatLoader palette: #3B2F2F dark, #F5E5D4 cream, #6FA8DC blue eyes,
 * #D4A0A0 pink belly, #FBF0E6 linen tummy, #EBE9E9 toe lines.
 */
export function CatIconButton({
  onClick,
  className,
  size = 44,
}: CatIconButtonProps) {
  return (
    <button
      onClick={onClick}
      className={`cursor-pointer inline-flex items-center justify-center min-w-[44px] min-h-[44px]${className ? ` ${className}` : ""}`}
      aria-label="Open birthday card"
      type="button"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 87 174"
        width={Math.round(size / 2)}
        height={size}
        fill="none"
        aria-hidden="true"
      >
        {/* Body */}
        <path
          d="M13.1324 3.98926C15.2156 4.96099 18.0555 6.22996 21.2682 7.50391C27.8457 10.1121 36.3427 12.8988 43.0953 13C50.3741 13.109 58.8982 10.3085 65.3883 7.6377C68.4499 6.37778 71.1346 5.11106 73.1324 4.11914V141.5H13.1324V3.98926Z"
          fill="#F5E5D4"
          stroke="#3B2F2F"
          strokeWidth="5"
        />

        {/* Eyes — Siamese blue */}
        <circle cx="31.1324" cy="32.5" r="3.5" fill="#6FA8DC" />
        <circle cx="56.1324" cy="31.5" r="3.5" fill="#6FA8DC" />

        {/* Dark face mask */}
        <ellipse cx="43.6324" cy="36" rx="8" ry="6" fill="#3B2F2F" />

        {/* Mouth circles */}
        <circle
          cx="39.1324"
          cy="41.5"
          r="3.5"
          stroke="#3B2F2F"
          strokeWidth="2"
        />
        <circle
          cx="47.1324"
          cy="41.5"
          r="3.5"
          stroke="#3B2F2F"
          strokeWidth="2"
        />

        {/* Tummy — linen */}
        <path
          d="M59.5827 94.1763C59.0985 120.014 52.2176 123.95 43.1324 123.95C34.0471 123.95 26.2339 117.132 26.6821 94.1763C27.6792 43.107 34.0471 63.8408 43.1324 63.8408C52.2176 63.8408 60.5798 40.9602 59.5827 94.1763Z"
          fill="#FBF0E6"
        />

        {/* Belly circle — pink */}
        <circle cx="43.6324" cy="67" r="15" fill="#D4A0A0" />

        {/* Front paws */}
        <path
          d="M23.6324 100C20.871 100 18.6324 97.7614 18.6324 95L18.6324 75H31.9966L31.9966 95C31.9966 97.7614 29.758 100 26.9966 100H23.6324Z"
          fill="#3B2F2F"
        />
        <path
          d="M57.6324 100C54.871 100 52.6324 97.7614 52.6324 95V75H65.9966V95C65.9966 97.7614 63.758 100 60.9966 100H57.6324Z"
          fill="#3B2F2F"
        />

        {/* Back paws */}
        <path
          d="M23.6324 155C20.871 155 18.6324 152.761 18.6324 150L18.6324 130H31.9966L31.9966 150C31.9966 152.761 29.758 155 26.9966 155H23.6324Z"
          fill="#3B2F2F"
        />
        <path
          d="M57.6324 155C54.871 155 52.6324 152.761 52.6324 150V130H65.9966V150C65.9966 152.761 63.758 155 60.9966 155H57.6324Z"
          fill="#3B2F2F"
        />

        {/* Paw toe lines */}
        <line x1="25.1324" y1="133" x2="25.1324" y2="155" stroke="#EBE9E9" />
        <line x1="59.1324" y1="133" x2="59.1324" y2="155" stroke="#EBE9E9" />

        {/* Tail */}
        <path
          d="M39.8146 174C37.0532 174 34.8146 171.761 34.8146 169V140H47.8146V169C47.8146 171.761 45.576 174 42.8146 174H39.8146Z"
          fill="#3B2F2F"
        />
        <line x1="41.3146" y1="144" x2="41.3146" y2="174" stroke="#EBE9E9" />

        {/* Right whiskers */}
        <line
          x1="67.27"
          y1="32.068"
          x2="85.27"
          y2="25.068"
          stroke="#3B2F2F"
          strokeWidth="2"
        />
        <line
          x1="67.6324"
          y1="35"
          x2="85.6324"
          y2="35"
          stroke="#3B2F2F"
          strokeWidth="2"
        />
        <line
          x1="67.9001"
          y1="38.0365"
          x2="85.9001"
          y2="43.0365"
          stroke="#3B2F2F"
          strokeWidth="2"
        />

        {/* Left whiskers */}
        <line
          x1="18.3162"
          y1="32.9487"
          x2="0.316219"
          y2="26.9487"
          stroke="#3B2F2F"
          strokeWidth="2"
        />
        <line
          x1="18.6324"
          y1="36"
          x2="0.632446"
          y2="36"
          stroke="#3B2F2F"
          strokeWidth="2"
        />
        <line
          x1="18.8615"
          y1="39.9734"
          x2="1.86149"
          y2="43.9734"
          stroke="#3B2F2F"
          strokeWidth="2"
        />
      </svg>
    </button>
  );
}
