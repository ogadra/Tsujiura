# Build from the repository root, which holds go.mod.
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY internal ./internal
COPY lambda/result-api ./lambda/result-api
RUN CGO_ENABLED=0 go build -tags lambda.norpc -o /main ./lambda/result-api

FROM public.ecr.aws/lambda/provided:al2023
COPY --from=build /main ./main
ENTRYPOINT ["./main"]
