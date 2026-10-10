#!/usr/bin/env bash

# Script to run Filebeat in foreground with the same path settings that
# the init script / systemd unit file would do.
umask 0027
exec /usr/share/filebeat/bin/filebeat \
  --path.home /usr/share/filebeat \
  --path.config /etc/filebeat \
  --path.data /var/lib/filebeat \
  --path.logs /var/log/filebeat \
  "$@"
