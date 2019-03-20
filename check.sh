#!/bin/sh
set -e

. /etc/varnish/logs.sh

applyConfig () {
  # Remove duplicates entries
  config=$(echo "$1" | tr ' ' '\n' | sort -u)
  
  log_info "Configuration applied: $config"
  sh /etc/varnish/genConfig.sh "$config"
}

backend_health () {
  while sleep $PROBE_INTERVAL
  do
    varnishadm -S /etc/varnish/secret backend.list >&2
  done
}

#echo $DAEMON_OPTS
DAEMON_OPTS="-a ${VARNISH_LISTEN_ADDRESS}:${VARNISH_LISTEN_PORT} \
             -f ${VARNISH_VCL_CONF} \
             -T ${VARNISH_ADMIN_LISTEN_ADDRESS}:${VARNISH_ADMIN_LISTEN_PORT} \
             -t ${VARNISH_TTL} \
             -S ${VARNISH_SECRET_FILE} \
             -s ${VARNISH_STORAGE}"

echo $DAEMON_OPTS
/usr/sbin/varnishd -j unix,user=varnish -F $DAEMON_OPTS > /dev/stdout 2>/dev/stderr &
# Wait for varnish to go up
sleep 5

backend_health &

varnishncsa -c -F '[ CLIENT ] %{X-Forwarded-For}i %l %u %t "%r" %s %b "%{Referer}i" "%{User-agent}i"' &

varnishncsa -b -F '[ BACKEND ] %{X-Forwarded-For}i %l %u %t "%r" %s %b "%{Referer}i" "%{User-agent}i"' &

while [ 1 ]
do
  # Shared wait variable
  echo 0 >/tmp/wait

  backends_old=$backends_new
  backends_new=$(sh /etc/varnish/backends.sh)
 
  #Compara hashs dos arquivos
  oldHash=$(echo $backends_old | md5sum | cut -d' ' -f1)
  newHash=$(echo $backends_new | md5sum | cut -d' ' -f1)
  emptyHash=$(echo "" | md5sum | cut -d' ' -f1) 

  #Caso diferente - nova configuração
  if [ "$newHash" = "$emptyHash" ]; then
    log_debug "No backends found - waiting for new backends ... "
  elif [ $oldHash != $newHash ]; then
    # Iterate wait variable
    echo $(($(</tmp/wait)+1)) >/dev/shm/wait
    log_info "Novos backends - $backends_new"
    applyConfig "$backends_new"
  fi
done
