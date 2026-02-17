import { describe, it, expect } from "vitest";
import { render } from "@testing-library/react";
import { SwiftieLogo } from "./SwiftieLogo";

describe("SwiftieLogo", () => {
  it("renders an SVG element", () => {
    const { container } = render(<SwiftieLogo />);
    const svg = container.querySelector("svg");
    expect(svg).toBeInTheDocument();
  });

  it("uses default size of 80", () => {
    const { container } = render(<SwiftieLogo />);
    const svg = container.querySelector("svg")!;
    expect(svg.getAttribute("width")).toBe("80");
    expect(svg.getAttribute("height")).toBe("80");
  });

  it("accepts custom size", () => {
    const { container } = render(<SwiftieLogo size={32} />);
    const svg = container.querySelector("svg")!;
    expect(svg.getAttribute("width")).toBe("32");
    expect(svg.getAttribute("height")).toBe("32");
  });

  it("applies className prop", () => {
    const { container } = render(<SwiftieLogo className="drop-shadow-2xl" />);
    const svg = container.querySelector("svg")!;
    expect(svg.classList.contains("drop-shadow-2xl")).toBe(true);
  });

  it("is aria-hidden", () => {
    const { container } = render(<SwiftieLogo />);
    const svg = container.querySelector("svg")!;
    expect(svg.getAttribute("aria-hidden")).toBe("true");
  });
});
