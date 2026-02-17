import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { CatLoader } from "./CatLoader";

describe("CatLoader", () => {
  it("renders without crashing at default (lg) size", () => {
    const { container } = render(<CatLoader />);
    expect(container.querySelector(".loading-cat")).toBeInTheDocument();
  });

  it("renders at sm size", () => {
    const { container } = render(<CatLoader size="sm" />);
    const cat = container.querySelector(".loading-cat") as HTMLElement;
    expect(cat).toBeInTheDocument();
    expect(cat.style.transform).toContain("scale(0.27)");
  });

  it("renders label text when provided", () => {
    render(<CatLoader label="Loading tracks..." />);
    expect(screen.getByText("Loading tracks...")).toBeInTheDocument();
  });

  it("does not render label when not provided", () => {
    const { container } = render(<CatLoader />);
    const paragraphs = container.querySelectorAll("p");
    expect(paragraphs).toHaveLength(0);
  });

  it("uses div-based structure (no SVG)", () => {
    const { container } = render(<CatLoader />);
    expect(container.querySelector("svg")).not.toBeInTheDocument();
  });
});
