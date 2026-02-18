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
    expect(screen.getByText(/Your Best Friend/)).toBeInTheDocument();
    expect(screen.getByText(/Satanshu/)).toBeInTheDocument();
  });

  it("renders the addressee", () => {
    render(<BirthdayCard isOpen={true} onClose={vi.fn()} />);
    expect(screen.getByText("Dear Ana,")).toBeInTheDocument();
  });

  it("renders the header with cake icons", () => {
    const { container } = render(
      <BirthdayCard isOpen={true} onClose={vi.fn()} />,
    );
    expect(screen.getByText("Happy Birthday!")).toBeInTheDocument();
    const svgs = container.querySelectorAll("svg");
    expect(svgs.length).toBeGreaterThanOrEqual(3);
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
