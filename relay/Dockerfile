FROM dart:3.13 AS build
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
