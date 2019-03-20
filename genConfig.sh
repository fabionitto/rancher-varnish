#!/bin/sh
set -e

BE_TEMPLATE=/etc/varnish/be_template.vcl
VARNISH_CONFIG=/etc/varnish/default.vcl
VARNISH_NEW=/etc/varnish/varnish_new.vcl
VARNISH_TEMPLATE=/etc/varnish/varnish_template.vcl

. /etc/varnish/logs.sh

genConfig () {
cp $VARNISH_TEMPLATE $VARNISH_NEW
  log_debug "Configuring $1"
  for i in $1; do
    #Include backend template
    sed -i -e "/%CREATE_BE%/r $BE_TEMPLATE" $VARNISH_NEW
    #Add backend to director
    sed -i -e "s/\%ADD_BE\%/bar.add_backend($(echo be$i | tr . _));\n    \%ADD_BE\%/g" $VARNISH_NEW 
    
    #Insert backend name 
    sed -i -e "s/\%BE_NAME\%/$(echo be$i | tr . _)/g" $VARNISH_NEW 
    #Insert IP address 
    sed -i -e "s/\%BE_IP\%/$i/g" $VARNISH_NEW 
    log_debug "Backend with IP $i configured"
  done
  
  #Remove %CREATE_BE% indicator and %ADD_BE%
  sed -i -e "s/\%CREATE_BE\%//g" $VARNISH_NEW
  sed -i -e "s/\%ADD_BE\%//g" $VARNISH_NEW

  #Temporary port mapping to backend
  sed -i -e "s/\%BE_PORT\%/${BE_PORT}/g" $VARNISH_NEW
  sed -i -e "s|\%BE_PATH\%|${BE_PATH}|g" $VARNISH_NEW
  sed -i -e "s|\%PROBE_TIMEOUT\%|${PROBE_TIMEOUT}|g" $VARNISH_NEW
  sed -i -e "s|\%PROBE_INTERVAL\%|${PROBE_INTERVAL}|g" $VARNISH_NEW
  sed -i -e "s|\%PROBE_WINDOW\%|${PROBE_WINDOW}|g" $VARNISH_NEW
  sed -i -e "s|\%PROBE_THRESHOLD\%|${PROBE_THRESHOLD}|g" $VARNISH_NEW
  sed -i -e "s|\%CACHE_TTL\%|${CACHE_TTL}|g" $VARNISH_NEW
  sed -i -e "s|\%CACHE_GRACE\%|${CACHE_GRACE}|g" $VARNISH_NEW
  sed -i -e "s|\%CACHE_KEEP\%|${CACHE_KEEP}|g" $VARNISH_NEW
}

reloadVarnish () {
TIME=$(date +%s)

# Copy new to default
cp $VARNISH_NEW $VARNISH_CONFIG

# Load the file into memory
ReloadCmd="varnishadm -S /etc/varnish/secret vcl.load varnish_$TIME $VARNISH_CONFIG"

# Active this Varnish config
StartCmd="varnishadm -S /etc/varnish/secret vcl.use varnish_$TIME"

$ReloadCmd
$StartCmd
}

genConfig "$1"
reloadVarnish
