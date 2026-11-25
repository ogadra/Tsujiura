# checkov:skip=CKV_DOCKER_2:Lambda does not run the Docker HEALTHCHECK
# checkov:skip=CKV_DOCKER_3:Lambda runs the image as its own non-root user
FROM golang:1.27.4@sha256:205c7636d74e0ffbe3d007162df7d74f859f5a8c8322dfb9f907977686c126cf AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY internal ./internal
COPY lambda/result-api ./lambda/result-api
RUN CGO_ENABLED=0 go build -tags lambda.norpc -o /main ./lambda/result-api

FROM public.ecr.aws/lambda/provided:al2023.2026.11.16.23@sha256:5a37b8e2fea3e6d53fe6d5d909b3180e88110409acaa175c1ba2d20cd38c33b3
COPY --from=build /main ./main
ENTRYPOINT ["./main"]
