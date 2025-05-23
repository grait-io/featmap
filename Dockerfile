# Use multi-stage build for smaller final image
FROM golang:1.21-alpine AS builder

WORKDIR /src

# Install system dependencies
RUN apk add --update npm git

# Install go-bindata using modern Go install
RUN go install github.com/jteeuwen/go-bindata/...@latest

# Copy and install npm dependencies first for better caching
COPY ./webapp/package.json ./webapp/package-lock.json ./webapp/
RUN cd ./webapp && \
    npm install --legacy-peer-deps

# Copy remaining source files
COPY . .

# Build React app with OpenSSL legacy provider
RUN cd ./webapp && \
    NODE_OPTIONS=--openssl-legacy-provider npm run build

# Generate bindata assets
RUN cd ./migrations && \
    go-bindata -pkg migrations .
    
RUN go-bindata -pkg tmpl -o ./tmpl/bindata.go ./tmpl/ && \
    go-bindata -pkg webapp -o ./webapp/bindata.go ./webapp/build/...

# Build final binary
RUN go build -o /opt/featmap/featmap && \
    chmod 775 /opt/featmap/featmap

# Create minimal runtime image
FROM alpine:3.19
COPY --from=builder /opt/featmap/featmap /opt/featmap/featmap

EXPOSE 8080
ENTRYPOINT ["/opt/featmap/featmap"]
