#!/bin/sh
set -e

. /etc/varnish/logs.sh

if hash curl 2>/dev/null && curl rancher-metadata 2>/dev/null >/dev/null; then
  services=$(curl http://rancher-metadata/latest/self/service/links 2>/dev/null)
  services_san=$(echo $services | sed -e "s/.*%2F\(.*\)/\1/g")
    for s in $services_san; do
      kind=$(curl http://rancher-metadata/latest/services/$s/kind 2>/dev/null)
      case $kind in
        service)
          backends=$(curl http://rancher-metadata/latest/services/$s/containers 2>/dev/null| cut -d'=' -f 2)
            for be in $backends; do
              be_san=$(echo $be | tr '-' '_')
              ip=$(curl http://rancher-metadata/latest/containers/$be/ips/0 2>/dev/null)
              if [ "$ip" != "Not found" ]; then
                echo $ip
              else
                log_debug "IP not found"
              fi
            done
          ;;
        externalService)
          backends=$(curl http://rancher-metadata/latest/services/$s/external_ips 2>/dev/null)
            for be in $backends; do
              s_san=$(echo $s | tr '-' '_')
              ip=$(curl http://rancher-metadata/latest/services/$s/external_ips/$be 2>/dev/null)
              if [ "$ip" != "Not found" ]; then
                echo $ip
              else
                log_debug "IP not found"
              fi
            done
          ;;
        *)
        ;;
      esac
    done
fi
