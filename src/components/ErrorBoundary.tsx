import { Component, type ReactNode } from "react";

interface Props {
  readonly children: ReactNode;
}

interface State {
  readonly hasError: boolean;
  readonly error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-8">
          <h1
            className="text-2xl font-bold"
            style={{ color: "var(--color-incorrect)" }}
          >
            Something went wrong
          </h1>
          <p
            className="text-center text-sm"
            style={{ color: "var(--color-text-secondary)" }}
          >
            {this.state.error?.message ?? "An unexpected error occurred."}
          </p>
          <button
            onClick={() => {
              this.setState({ hasError: false, error: null });
              window.location.reload();
            }}
            className="rounded-lg px-6 py-3 font-medium text-white"
            style={{ backgroundColor: "var(--color-accent)" }}
          >
            Restart
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
