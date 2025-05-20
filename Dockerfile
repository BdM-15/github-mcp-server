# Dockerfile for GitHub MCP Server
#
# Multi-stage build for a minimal, secure, and reproducible container image.
#
# Stage 1: Build the Go binary with version, commit, and date metadata.
ARG VERSION="dev"

FROM golang:1.22.3-slim AS build

# allow this step access to build arg
ARG VERSION

# Set working directory for build
WORKDIR /build

# Use a persistent Go build cache for faster builds
RUN go env -w GOMODCACHE=/root/.cache/go-build

# Copy Go module files and download dependencies
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build go mod download

# Copy the rest of the source code
COPY . ./

# Build the server binary with version, commit, and date info
# Reason: Embeds build metadata for traceability and debugging
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build \
    -ldflags="-s -w -X main.version=${VERSION} -X main.commit=$(git rev-parse HEAD) -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o github-mcp-server cmd/github-mcp-server/main.go

# Stage 2: Minimal runtime image using distroless for security
FROM gcr.io/distroless/base-debian12

# Set working directory for runtime
WORKDIR /server

# Copy the built binary from the build stage
COPY --from=build /build/github-mcp-server .

# Run the server in stdio mode (default entrypoint)
CMD ["./github-mcp-server", "stdio"]
