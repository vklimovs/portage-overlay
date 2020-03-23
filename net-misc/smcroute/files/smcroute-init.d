#!/sbin/openrc-run
# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

command="/usr/sbin/smcrouted"
pidfile="/run/smcrouted.pid"
command_args="-P ${pidfile} -N"

depend() {
        need localmount net
        use logger
}
