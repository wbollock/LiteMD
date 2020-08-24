# Dockerfile for LMD
# docker build -t wbollock/litemd:1.0 .
FROM alpine:latest

# Packages
RUN apk update && \
apk add curl && \
apk add bash && \
mkdir -p /etc/litemd

# Setup
COPY litemd_docker.sh /etc/litemd/litemd.sh
COPY install_docker.sh /etc/litemd/install.sh




# Program actions
ENTRYPOINT ["bash"]
CMD ["/etc/litemd/install.sh"]

# still not sure about the volumes
VOLUME /monitoring