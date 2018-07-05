#!/bin/sh
set -e

BE_TEMPLATE=/etc/varnish/be_template.vcl
VARNISH_CONFIG=/etc/varnish/default.vcl
VARNISH_NEW=/etc/varnish/varnish_new.vcl
VARNISH_TEMPLATE=/etc/varnish/varnish_template.vcl

genConfig () {
cp $VARNISH_TEMPLATE $VARNISH_NEW
#If curl and Rancher
if hash curl 2>/dev/null && curl rancher-metadata 2>/dev/null >/dev/null; then
  services=$(curl http://rancher-metadata/latest/self/service/links)
#  if [ "$services" = "Not found" ]; then
 #     # Keep old configuration if service not found
  #    cp $VARNISH_CONFIG $VARNISH_NEW
  #else
      echo "Servicos encontrados:"
      echo $services
    
      services_san=$(echo $services | sed -e "s/.*%2F\(.*\)/\1/g")
      for s in $services_san; do
        kind=$(curl http://rancher-metadata/latest/services/$s/kind)
        case $kind in
          service)
            echo "Criando backends para $s ..."
            backends=$(curl http://rancher-metadata/latest/services/$s/containers| cut -d'=' -f 2)
              for be in $backends; do
                be_san=$(echo $be | tr '-' '_')
                echo "Backend $be_san ..."
                ip=$(curl http://rancher-metadata/latest/containers/$be/ips/0)
    
                #Include backend template
                sed -i -e "/%CREATE_BE%/r $BE_TEMPLATE" $VARNISH_NEW
                #Add backend to director
                sed -i -e "s/\%ADD_BE\%/bar.add_backend($be_san);\n    \%ADD_BE\%/g" $VARNISH_NEW 
    
                #Insert backend name 
                sed -i -e "s/\%BE_NAME\%/$be_san/g" $VARNISH_NEW 
                #Insert IP address 
                sed -i -e "s/\%BE_IP\%/$ip/g" $VARNISH_NEW 
              done
            ;;
          externalService)
            echo "Criando backends para $s ..."
            backends=$(curl http://rancher-metadata/latest/services/$s/external_ips)
              for be in $backends; do
                s_san=$(echo $s | tr '-' '_')
                echo "Backend $s_san\_$be ..."
                ip=$(curl http://rancher-metadata/latest/services/$s/external_ips/$be)
    
                #Include backend template
                sed -i -e "/%CREATE_BE%/r $BE_TEMPLATE" $VARNISH_NEW
                #Add backend to director
                sed -i -e "s/\%ADD_BE\%/bar.add_backend($s_san\_$be);\n    \%ADD_BE\%/g" $VARNISH_NEW
     
                #Insert backend name 
                sed -i -e "s/\%BE_NAME\%/$s_san\_$be/g" $VARNISH_NEW
                #Insert IP address 
                sed -i -e "s/\%BE_IP\%/$ip/g" $VARNISH_NEW
              done
            ;;       
          *)
              echo "Servico $s não será considerado"
            ;;
        esac
      done
      
      #Caso não existam backends no Rancher - cria um backend para 127.0.0.1
      if [ ! $services ]; then
        sed -i -e "/%CREATE_BE%/r $BE_TEMPLATE" $VARNISH_NEW
        #Add backend to director
        sed -i -e "s/\%ADD_BE\%/bar.add_backend(default);/g" $VARNISH_NEW
    
        #Insert backend name 
        sed -i -e "s/\%BE_NAME\%/default/g" $VARNISH_NEW
        #Insert IP address 
        sed -i -e "s/\%BE_IP\%/127.0.0.1/g" $VARNISH_NEW    
      fi  
   #fi
fi

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
}

reloadVarnish () {
TIME=$(date +%s)

echo Coping new config to /etc/varnish/default.vcl
# Copy new to default
cp $VARNISH_NEW $VARNISH_CONFIG

# Load the file into memory
ReloadCmd="varnishadm -S /etc/varnish/secret vcl.load varnish_$1_$TIME $VARNISH_CONFIG"

# Active this Varnish config
StartCmd="varnishadm -S /etc/varnish/secret vcl.use varnish_$1_$TIME"

#Discard
getColdCmd="varnishadm -S /etc/varnish/secret vcl.list" 
DiscardCmd="varnishadm -S /etc/varnish/secret vcl.discard "

$ReloadCmd
$StartCmd

echo "Lista de vcl a apagar:"
discard=$($getColdCmd | grep "cold" | cut -d' ' -f4)
echo Apagando $discard
for d in $discard; do
  $DiscardCmd $d
done
}

#/etc/init.d/varnish start &
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
  #Gera nova configuração
  genConfig
 
  #Compara hashs dos arquivos
  oldHash=$(md5sum $VARNISH_CONFIG | cut -d' ' -f1)
  newHash=$(md5sum $VARNISH_NEW | cut -d' ' -f1)
  
  echo "Old Config:"
  cat $VARNISH_CONFIG

  echo "Gerada configuração - $oldHash:$newHash"
  #Caso diferente - nova configuração
  if [ $oldHash != $newHash ]; then
    echo "Aplicando nova configuração ..." 
    echo "New Config:"
    cat $VARNISH_CONFIG
    #Chama reloadVarnish.sh para carregar a nova configuração em varnish_new.vcl
    reloadVarnish $newHash

  fi
  
  varnishadm -S /etc/varnish/secret backend.list
  echo "..."

 
  sleep 10 
done
