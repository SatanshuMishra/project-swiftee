import { render, screen, fireEvent } from "@testing-library/react";
import { describe, it, expect, vi, beforeEach } from "vitest";

import { UpdateModal } from "./UpdateModal";
import type { UpdaterMachineState } from "../types";

const mockUpdater = {
  state: { kind: "idle" } as UpdaterMachineState,
  check: vi.fn(),
  download: vi.fn(),
  install: vi.fn(),
  cancel: vi.fn(),
  skipVersion: vi.fn(),
  remindLater: vi.fn(),
  dismiss: vi.fn(),
};

vi.mock("../hooks/useUpdater", () => ({
  useUpdater: () => mockUpdater,
}));

beforeEach(() => {
  vi.clearAllMocks();
  mockUpdater.state = { kind: "idle" };
});

describe("UpdateModal", () => {
  it("returns null when isOpen is false", () => {
    const { container } = render(
      <UpdateModal isOpen={false} onClose={() => {}} />,
    );
    expect(container.firstChild).toBeNull();
  });

  it("renders release notes and Download/Skip/Remind buttons when state is available", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: {
        version: "0.3.0",
        notes: "## What's new\n- foo\n- bar",
        pubDate: "2026-05-01T00:00:00Z",
      },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(screen.getByText(/0\.3\.0/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /^download$/i })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /skip this version/i }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /remind me later/i }),
    ).toBeInTheDocument();
  });

  it("clicking Download invokes useUpdater.download()", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /^download$/i }));
    expect(mockUpdater.download).toHaveBeenCalledTimes(1);
  });

  it("clicking Skip this version invokes useUpdater.skipVersion(version)", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /skip this version/i }));
    expect(mockUpdater.skipVersion).toHaveBeenCalledWith("0.3.0");
  });

  it("clicking Remind me later invokes useUpdater.remindLater()", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /remind me later/i }));
    expect(mockUpdater.remindLater).toHaveBeenCalledTimes(1);
  });

  it("renders progress bar with aria-valuenow when downloading", () => {
    mockUpdater.state = {
      kind: "downloading",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
      progress: 73,
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    const bar = screen.getByRole("progressbar");
    expect(bar).toHaveAttribute("aria-valuenow", "73");
    expect(bar).toHaveAttribute("aria-valuemin", "0");
    expect(bar).toHaveAttribute("aria-valuemax", "100");
  });

  it("clicking Cancel during downloading invokes useUpdater.cancel()", () => {
    mockUpdater.state = {
      kind: "downloading",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
      progress: 50,
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /^cancel$/i }));
    expect(mockUpdater.cancel).toHaveBeenCalledTimes(1);
  });

  it("renders Install & Restart button when state is ready", () => {
    mockUpdater.state = {
      kind: "ready",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(
      screen.getByRole("button", { name: /install.*restart/i }),
    ).toBeInTheDocument();
  });

  it("clicking Install & Restart invokes useUpdater.install()", () => {
    mockUpdater.state = {
      kind: "ready",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /install.*restart/i }));
    expect(mockUpdater.install).toHaveBeenCalledTimes(1);
  });

  it("renders red signature-error banner with no auto-retry button", () => {
    mockUpdater.state = {
      kind: "error",
      subtype: "signature",
      message: "Signature mismatch",
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(screen.getByText(/verification failed/i)).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /^retry$/i }),
    ).not.toBeInTheDocument();
  });

  it("renders Retry button for download error", () => {
    mockUpdater.state = {
      kind: "error",
      subtype: "download",
      message: "Connection reset",
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    expect(screen.getByRole("button", { name: /^retry$/i })).toBeInTheDocument();
  });

  it("Retry on download error invokes useUpdater.download()", () => {
    mockUpdater.state = {
      kind: "error",
      subtype: "download",
      message: "Connection reset",
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    fireEvent.click(screen.getByRole("button", { name: /^retry$/i }));
    expect(mockUpdater.download).toHaveBeenCalledTimes(1);
  });

  it("Escape key closes the modal", () => {
    const onClose = vi.fn();
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={onClose} />);
    fireEvent.keyDown(window, { key: "Escape" });
    expect(onClose).toHaveBeenCalled();
  });

  it("dialog has aria-modal=true", () => {
    mockUpdater.state = {
      kind: "available",
      manifest: { version: "0.3.0", notes: "", pubDate: "" },
    };
    render(<UpdateModal isOpen onClose={() => {}} />);
    const dialog = screen.getByRole("dialog");
    expect(dialog).toHaveAttribute("aria-modal", "true");
  });
});
