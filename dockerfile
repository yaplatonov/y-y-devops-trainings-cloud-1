FROM golang:1.21 AS builder
WORKDIR /src
COPY catgpt .
RUN go mod download
RUN CGO_ENABLED=0 go build -o /build/catgpt

FROM gcr.io/distroless/static-debian12:latest-amd64

WORKDIR /build

COPY --from=builder /build/catgpt /build/catgpt

# CMD ["/build/catgpt"]
ENTRYPOINT ["/build/catgpt"]