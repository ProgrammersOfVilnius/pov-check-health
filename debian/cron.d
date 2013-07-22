# Run system health checks every hour, at 27 minutes past the hour
27 *  * * *  root  if [ -x /usr/sbin/check-health ] && [ -f /etc/pov/check-health ]; then /usr/sbin/check-health; fi
