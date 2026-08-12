FROM docker:cli

RUN apk add --no-cache make

WORKDIR /workspace
ENTRYPOINT ["make"]
