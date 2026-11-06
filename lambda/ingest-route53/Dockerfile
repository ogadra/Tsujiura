# Build from the repository root, which holds go.mod and the GeoLite2 ASN database.
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY internal ./internal
COPY lambda/ingest-route53 ./lambda/ingest-route53
RUN CGO_ENABLED=0 go build -tags lambda.norpc -o /main ./lambda/ingest-route53

FROM public.ecr.aws/lambda/provided:al2023
COPY GeoLite2-ASN.mmdb ./
COPY --from=build /main ./main
ENTRYPOINT ["./main"]
