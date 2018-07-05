#!/bin/sh
set -e

. /etc/varnish/logs.sh

applyConfig () {
  log_info "Configuration applied: $1"
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
    apply_backends=$backends_new
    log_info "Novos backends - $backends_new"
    log_debug "Wait set: $(</tmp/wait)"
  fi
 
  if [ "$(</tmp/wait)" = "1" ]; then 
    log_debug "Wait apply: $(</tmp/wait)"
    # Fork, Wait sometime and Apply new configuration
    (sleep 10; applyConfig $apply_backends; echo 0 >/tmp/wait) &    
  fi 
done
