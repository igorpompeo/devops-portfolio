# Estágio 1: build - imagem completa, com compilador Go
FROM golang:1.27-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o server main.go

# Estágio 2: runtime - imagem vazia, só o binário
FROM scratch

COPY --from=builder /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]