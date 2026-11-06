# Build from the repository root, which holds go.mod and the page.
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY lambda/frontend ./lambda/frontend
RUN CGO_ENABLED=0 go build -tags lambda.norpc -o /main ./lambda/frontend

FROM public.ecr.aws/lambda/provided:al2023
COPY web ./web
COPY --from=build /main ./main
ENTRYPOINT ["./main"]
