FROM dart:3.13.4@sha256:33faf91bc941466a767ce845b4bbb5d578ecd180abe5ee243e9c8c039109d215 AS build
WORKDIR /src
COPY packages/together_protocol packages/together_protocol
COPY relay relay
WORKDIR /src/relay
RUN dart pub get --enforce-lockfile
RUN dart build cli --target bin/relay.dart -o output

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /src/relay/output/bundle/ /app/
USER 1000:1000
EXPOSE 8080
ENTRYPOINT ["/app/bin/relay"]
