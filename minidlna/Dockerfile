FROM alpine:latest

# Install ReadyMedia (formerly MiniDLNA).
# tzdata allows the container to use the configured timezone.
RUN apk add --no-cache \
    minidlna \
    tzdata

# Create the directories used by ReadyMedia.
# /media will be mounted from the host and contains our media library.
# /var/cache/minidlna will be mounted from the host and contains
# persistent database and log files.
RUN mkdir -p /media /var/cache/minidlna/db /var/cache/minidlna/logs

# Copy our ReadyMedia configuration into the image.
COPY minidlna.conf /minidlna.conf

# Expose the ReadyMedia HTTP/status port.
# With host networking, Docker does not perform normal port mapping.
EXPOSE 8200

# Start ReadyMedia in the foreground.
# Using an absolute path avoids ambiguity about the working directory.
CMD ["minidlnad", "-d", "-f", "/minidlna.conf"]
