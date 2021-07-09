FROM ubuntu:20.04

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
    kpcli

VOLUME /data
WORKDIR /data

ENTRYPOINT ["kpcli"]