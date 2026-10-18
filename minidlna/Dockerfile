FROM alpine:latest

RUN apk add --no-cache \
    minidlna \
    tzdata

RUN mkdir -p /media /var/cache/minidlna/db /var/cache/minidlna/logs

COPY minidlna.conf ./minidlna.conf

EXPOSE 8200

CMD ["minidlnad", "-d", "-P", "/tmp/minidlna.pid", "-f", "/minidlna.conf"]
