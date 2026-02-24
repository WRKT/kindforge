FROM alpine:3.22.1

ARG VELERO_VERSION=1.14.1

RUN apk add --no-cache curl bash bash-completion

RUN set -e && \
    DOWNLOAD_URL="https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-amd64.tar.gz" && \
    curl -L "${DOWNLOAD_URL}" | tar -xz -C /tmp && \
    mv "/tmp/velero-v${VELERO_VERSION}-linux-amd64/velero" /usr/local/bin/velero && \
    chmod +x /usr/local/bin/velero && \
    rm -rf /tmp/velero-*

COPY scripts/velero-schedule.sh /usr/local/bin/velero-schedule

RUN chmod +x /usr/local/bin/velero-schedule

RUN adduser -D -s /bin/sh velero
COPY --chown=velero:velero scripts/.bashrc /home/velero/.bashrc

USER velero
WORKDIR /home/velero

CMD ["/bin/bash"]
