import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { StreakBadge } from "./StreakBadge";

describe("StreakBadge", () => {
  it("renders the streak count", () => {
    render(<StreakBadge streak={5} />);
    expect(screen.getByText("5")).toBeInTheDocument();
  });

  it("renders a Sparkles icon (svg) instead of the fire emoji", () => {
    const { container } = render(<StreakBadge streak={3} />);
    const svg = container.querySelector("svg");
    expect(svg).toBeInTheDocument();
    // Fire emoji (🔥 / &#128293;) must NOT appear
    expect(container.textContent).not.toMatch(/🔥/);
  });

  it("renders streak 0 without crashing", () => {
    render(<StreakBadge streak={0} />);
    expect(screen.getByText("0")).toBeInTheDocument();
  });
});
