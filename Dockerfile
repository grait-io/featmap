# Use Node.js LTS for builder stage
FROM node:18.20-alpine AS frontend-builder

# Webapp dependencies
WORKDIR /src/webapp
COPY webapp/package.json webapp/package-lock.json ./
RUN npm install --legacy-peer-deps

# Build React app with OpenSSL fix
COPY webapp .
RUN NODE_OPTIONS=--openssl-legacy-provider npm run build

# Final Go build stage
FROM golang:1.21-alpine
WORKDIR /src
RUN apk add --update npm git
RUN go install github.com/jteeuwen/go-bindata/...@latest

# Copy pre-built React assets from frontend-builder
COPY --from=frontend-builder /src/webapp/build ./webapp/build

# Remaining build steps
COPY . .
RUN cd ./migrations && go-bindata -pkg migrations .
RUN go-bindata -pkg tmpl -o ./tmpl/bindata.go ./tmpl/
RUN go-bindata -pkg webapp -o ./webapp/bindata.go ./webapp/build/...
RUN go build -o /opt/featmap/featmap && chmod 775 /opt/featmap/featmap

ENTRYPOINT ["/opt/featmap/featmap"]
