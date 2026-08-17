# Use a minimal base image
FROM alpine:latest

RUN apk add --no-cache curl jq

WORKDIR /app

COPY do_ddns_updater.sh /app/script.sh

RUN chmod +x /app/script.sh

CMD ["/bin/sh", "/app/script.sh"]

