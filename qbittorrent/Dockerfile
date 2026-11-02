FROM lscr.io/linuxserver/qbittorrent:latest

# Need ffmpeg for the video conversion script
RUN apk add --no-cache ffmpeg

# Bake the conversion script into the image itself, so it's always
# present regardless of volume mounts.
COPY scripts/convert-for-tv.sh /scripts/convert-for-tv.sh
RUN chmod +x /scripts/convert-for-tv.sh

# custom-cont-init.d is for linuxservers overlay to run things before qbittorrent client starts
# we copy 10-autorun-tv-convert.sh script into it
# 10-autorun-tv-convert.sh will alter qbittorrent config to always run
# a conversion script on finished torrent downloads
COPY custom-cont-init.d/10-autorun-tv-convert.sh /custom-cont-init.d/10-autorun-tv-convert.sh
RUN chmod +x /custom-cont-init.d/10-autorun-tv-convert.sh