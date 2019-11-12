#!/bin/sh
set -e

sudo supervisord -c /etc/supervisor/conf.d/supervisord.conf

exec "$@"
