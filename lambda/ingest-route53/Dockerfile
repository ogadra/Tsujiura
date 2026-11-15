# checkov:skip=CKV_DOCKER_2:Lambda does not run the Docker HEALTHCHECK
# checkov:skip=CKV_DOCKER_3:Lambda runs the image as its own non-root user
# Build with the repository root as the context.
FROM golang:1.27 AS build
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
