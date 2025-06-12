FROM bash:latest

RUN apk add --no-cache logrotate
RUN apk add --no-cache kubectl
RUN apk add --no-cache jq

RUN touch /etc/logrotate.conf
RUN alias kubectl=oc

COPY oc_backup_secrets.sh /usr/local/bin/oc_backup_secrets

CMD [ \
    "bash", \
    "-c", \
    "oc_backup_secrets $NAMESPACES" \
]