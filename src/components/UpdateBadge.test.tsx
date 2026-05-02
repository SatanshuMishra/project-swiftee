import { render, screen } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";

import { UpdateBadge } from "./UpdateBadge";

vi.mock("../hooks/useUpdater", () => ({
  useUpdater: vi.fn(),
}));

import { useUpdater } from "../hooks/useUpdater";
const mockUseUpdater = vi.mocked(useUpdater);

describe("UpdateBadge", () => {
  it("renders nothing when state is idle", () => {
    mockUseUpdater.mockReturnValue({
      state: { kind: "idle" },
    } as ReturnType<typeof useUpdater>);
    const { container } = render(<UpdateBadge onClick={() => {}} />);
    expect(container.firstChild).toBeNull();
  });

  it("renders nothing when state is checking", () => {
    mockUseUpdater.mockReturnValue({
      state: { kind: "checking" },
    } as ReturnType<typeof useUpdater>);
    const { container } = render(<UpdateBadge onClick={() => {}} />);
    expect(container.firstChild).toBeNull();
  });

  it("renders nothing when state is up-to-date", () => {
    mockUseUpdater.mockReturnValue({
      state: { kind: "up-to-date" },
    } as ReturnType<typeof useUpdater>);
    const { container } = render(<UpdateBadge onClick={() => {}} />);
    expect(container.firstChild).toBeNull();
  });

  it("renders 'Update available' text when state is available", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "available",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/update available/i)).toBeInTheDocument();
    expect(screen.getByText(/0\.3\.0/)).toBeInTheDocument();
  });

  it("renders progress percentage when downloading", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "downloading",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
        progress: 47,
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/47/)).toBeInTheDocument();
  });

  it("renders 'Restart to install' when ready", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "ready",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/restart to install/i)).toBeInTheDocument();
  });

  it("renders an issue label when state is error", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "error",
        subtype: "download",
        message: "network",
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    expect(screen.getByText(/issue/i)).toBeInTheDocument();
  });

  it("renders nothing when state is installing", () => {
    mockUseUpdater.mockReturnValue({
      state: { kind: "installing" },
    } as ReturnType<typeof useUpdater>);
    const { container } = render(<UpdateBadge onClick={() => {}} />);
    expect(container.firstChild).toBeNull();
  });

  it("calls onClick when clicked", async () => {
    const onClick = vi.fn();
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "available",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={onClick} />);
    screen.getByRole("button").click();
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it("has an accessible label per state", () => {
    mockUseUpdater.mockReturnValue({
      state: {
        kind: "available",
        manifest: { version: "0.3.0", notes: "", pubDate: "" },
      },
    } as ReturnType<typeof useUpdater>);
    render(<UpdateBadge onClick={() => {}} />);
    const button = screen.getByRole("button");
    expect(button).toHaveAttribute("aria-label");
    expect(button.getAttribute("aria-label") ?? "").toMatch(/update/i);
  });
});
