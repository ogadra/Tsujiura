FROM --platform=$BUILDPLATFORM golang:1.27.4@sha256:205c7636d74e0ffbe3d007162df7d74f859f5a8c8322dfb9f907977686c126cf AS build
ARG TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY internal/server ./internal/server
COPY web ./web
COPY ecs/frontend ./ecs/frontend
RUN CGO_ENABLED=0 GOARCH=$TARGETARCH go build -trimpath -o /main ./ecs/frontend

FROM scratch
COPY --from=build /main /main
USER 65534:65534
HEALTHCHECK CMD ["/main", "-healthcheck"]
ENTRYPOINT ["/main"]
