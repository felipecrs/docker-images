#!/bin/sh
set -e

supervisord -c /etc/supervisor/conf.d/supervisord.conf

exec gosu jenkins "$@"
