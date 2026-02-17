import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { BirthdayCard } from "./BirthdayCard";

describe("BirthdayCard", () => {
  it("renders nothing when isOpen is false", () => {
    render(<BirthdayCard isOpen={false} onClose={vi.fn()} />);
    expect(screen.queryByText("Happy Birthday!")).not.toBeInTheDocument();
  });

  it("renders the birthday message when isOpen is true", () => {
    render(<BirthdayCard isOpen={true} onClose={vi.fn()} />);
    expect(screen.getByText("Happy Birthday!")).toBeInTheDocument();
  });

  it("renders the signature text", () => {
    render(<BirthdayCard isOpen={true} onClose={vi.fn()} />);
    expect(screen.getByText(/With Love/)).toBeInTheDocument();
    expect(screen.getByText(/Satanshu/)).toBeInTheDocument();
  });

  it("renders the addressee", () => {
    render(<BirthdayCard isOpen={true} onClose={vi.fn()} />);
    expect(screen.getByText("Dear Swiftie")).toBeInTheDocument();
  });

  it("renders the postage stamp with SwiftieLogo", () => {
    const { container } = render(
      <BirthdayCard isOpen={true} onClose={vi.fn()} />,
    );
    const svgs = container.querySelectorAll("svg");
    const logoSvg = Array.from(svgs).find(
      (svg) => svg.getAttribute("viewBox") === "0 0 64 64",
    );
    expect(logoSvg).toBeInTheDocument();
  });

  it("renders the penguin SVG", () => {
    const { container } = render(
      <BirthdayCard isOpen={true} onClose={vi.fn()} />,
    );
    const svgs = container.querySelectorAll("svg");
    const penguinSvg = Array.from(svgs).find(
      (svg) => svg.getAttribute("viewBox") === "0 0 24 24",
    );
    expect(penguinSvg).toBeInTheDocument();
  });

  it("calls onClose when close button is clicked", () => {
    const onClose = vi.fn();
    const { container } = render(
      <BirthdayCard isOpen={true} onClose={onClose} />,
    );
    const closeButtons = container.querySelectorAll("button");
    expect(closeButtons.length).toBe(1);
    fireEvent.click(closeButtons[0]);
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("does not call onClose when card body is clicked", () => {
    const onClose = vi.fn();
    render(<BirthdayCard isOpen={true} onClose={onClose} />);
    fireEvent.click(screen.getByText("Happy Birthday!"));
    expect(onClose).not.toHaveBeenCalled();
  });
});
