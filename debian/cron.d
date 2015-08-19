# Run system health checks every hour, at 27 minutes past the hour
27 *  * * *    root  if [ -x /usr/sbin/check-health ] && [ -f /etc/pov/check-health ]; then /usr/sbin/check-health; fi

# Run website health checks every 15 minutes
*/15 *  * * *  root  if [ -x /usr/sbin/check-web-health ] && [ -f /etc/pov/check-web-health ]; then /usr/sbin/check-web-health; fi

# Run SSL certificate checks every day
@daily         root  if [ -x /usr/sbin/check-ssl-certs ] && [ -f /etc/pov/check-ssl-certs ]; then /usr/sbin/check-ssl-certs; fi
