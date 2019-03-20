FROM debian

ENV BE_PORT 80
ENV BE_PATH /
ENV PROBE_TIMEOUT 1s
ENV PROBE_INTERVAL 5s
ENV PROBE_WINDOW 5
ENV PROBE_THRESHOLD 3


RUN apt-get -y update
RUN apt-get -y install varnish curl

ENV VARNISH_VCL_CONF /etc/varnish/default.vcl
ENV VARNISH_LISTEN_ADDRESS 0.0.0.0 
ENV VARNISH_LISTEN_PORT 6081
ENV VARNISH_ADMIN_LISTEN_ADDRESS 127.0.0.1
ENV VARNISH_ADMIN_LISTEN_PORT 6082
ENV VARNISH_STORAGE_FILE /var/lib/varnish/varnish_storage.bin
ENV VARNISH_STORAGE_SIZE 1G
ENV VARNISH_SECRET_FILE /etc/varnish/secret
ENV VARNISH_STORAGE "file,${VARNISH_STORAGE_FILE},${VARNISH_STORAGE_SIZE}"
ENV VARNISH_TTL 120
ENV CACHE_TTL 5m
ENV CACHE_GRACE 2h
ENV CACHE_KEEP 5d

COPY varnish /etc/default/varnish
COPY varnish.vcl /etc/varnish/varnish_template.vcl
COPY be_template.vcl /etc/varnish/be_template.vcl
COPY genConfig.sh /etc/varnish/genConfig.sh
COPY backends.sh /etc/varnish/backends.sh
COPY logs.sh /etc/varnish/logs.sh
COPY check.sh /etc/varnish/check.sh

CMD /etc/varnish/check.sh
