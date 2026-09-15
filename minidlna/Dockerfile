FROM alpine:latest

# Install ReadyMedia (formerly MiniDLNA).
# We also install tzdata so the container can use the correct timezone.
RUN apk add --no-cache \
    minidlna \
    tzdata

# Create the directories that will exist inside the container.
# /config will contain our persistent ReadyMedia configuration/database.
# /media will be the mount point for the actual movie/music/photo library.
RUN mkdir -p /config /media

# Tell ReadyMedia where its configuration file is located.
ENV MINIDLNA_CONFIG_FILE=/config/minidlna.conf

# Expose the normal ReadyMedia HTTP/status port.
# NOTE: Because we use host networking, Docker does not actually
# perform a normal port mapping for this port.
EXPOSE 8200

# Start ReadyMedia in the foreground.
# Keeping the main process in the foreground is important for Docker,
# because the container stays alive while this process is running.
CMD ["minidlnad", "-d", "-f", "/config/minidlna.conf"]
