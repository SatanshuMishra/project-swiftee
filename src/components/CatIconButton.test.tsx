import { describe, it, expect, vi } from "vitest";
import { render, fireEvent } from "@testing-library/react";
import { CatIconButton } from "./CatIconButton";

describe("CatIconButton", () => {
  it("renders an SVG element", () => {
    const { container } = render(<CatIconButton onClick={() => {}} />);
    const svg = container.querySelector("svg");
    expect(svg).toBeInTheDocument();
  });

  it("uses default size of 44", () => {
    const { container } = render(<CatIconButton onClick={() => {}} />);
    const svg = container.querySelector("svg")!;
    expect(svg.getAttribute("height")).toBe("44");
    expect(svg.getAttribute("width")).toBe("22");
  });

  it("accepts custom size", () => {
    const { container } = render(
      <CatIconButton onClick={() => {}} size={60} />,
    );
    const svg = container.querySelector("svg")!;
    expect(svg.getAttribute("height")).toBe("60");
    expect(svg.getAttribute("width")).toBe("30");
  });

  it("SVG is aria-hidden", () => {
    const { container } = render(<CatIconButton onClick={() => {}} />);
    const svg = container.querySelector("svg")!;
    expect(svg.getAttribute("aria-hidden")).toBe("true");
  });

  it("button has aria-label", () => {
    const { getByRole } = render(<CatIconButton onClick={() => {}} />);
    const button = getByRole("button");
    expect(button).toHaveAttribute("aria-label", "Open birthday card");
  });

  it("calls onClick when clicked", () => {
    const handleClick = vi.fn();
    const { getByRole } = render(<CatIconButton onClick={handleClick} />);
    fireEvent.click(getByRole("button"));
    expect(handleClick).toHaveBeenCalledOnce();
  });

  it("applies className prop", () => {
    const { getByRole } = render(
      <CatIconButton onClick={() => {}} className="test-class" />,
    );
    expect(getByRole("button").classList.contains("test-class")).toBe(true);
  });

  it("renders Siamese color palette elements", () => {
    const { container } = render(<CatIconButton onClick={() => {}} />);
    const svg = container.querySelector("svg")!;
    // Blue eyes
    const blueElements = svg.querySelectorAll('[fill="#6FA8DC"]');
    expect(blueElements.length).toBeGreaterThan(0);
    // Pink belly
    const pinkElements = svg.querySelectorAll('[fill="#D4A0A0"]');
    expect(pinkElements.length).toBeGreaterThan(0);
    // Dark outline/paws
    const darkElements = svg.querySelectorAll('[fill="#3B2F2F"]');
    expect(darkElements.length).toBeGreaterThan(0);
  });
});
