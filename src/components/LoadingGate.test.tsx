import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { LoadingGate } from "./LoadingGate";

describe("LoadingGate", () => {
  it("shows CatLoader when loading is true", () => {
    const { container } = render(
      <LoadingGate loading={true}>
        <p>Content</p>
      </LoadingGate>,
    );
    expect(container.querySelector(".loading-cat")).toBeInTheDocument();
    expect(screen.queryByText("Content")).not.toBeInTheDocument();
  });

  it("shows children when loading is false", () => {
    render(
      <LoadingGate loading={false}>
        <p>Content</p>
      </LoadingGate>,
    );
    expect(screen.getByText("Content")).toBeInTheDocument();
  });

  it("passes label to CatLoader", () => {
    render(
      <LoadingGate loading={true} label="Loading...">
        <p>Content</p>
      </LoadingGate>,
    );
    expect(screen.getByText("Loading...")).toBeInTheDocument();
  });

  it("accepts onReady callback without crashing", () => {
    const onReady = vi.fn();
    const { unmount } = render(
      <LoadingGate loading={false} onReady={onReady}>
        <p>Content</p>
      </LoadingGate>,
    );
    // onReady is invoked during AnimatePresence exit transition
    // In tests without real animation, we verify it doesn't crash
    unmount();
  });
});
