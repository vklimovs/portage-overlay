#!/sbin/openrc-run

command="/usr/sbin/smcrouted"
pidfile="/var/run/smcroute.pid"
command_args="-p smcroute:smcroute -P ${pidfile} -N"

depend() {
	need localmount net
	use logger
}
