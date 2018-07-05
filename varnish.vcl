vcl 4.0;
#
# Fabio Nitto
#
# Este e um template para o VCL padrao do container.
#
# Ele possui as seguintes diretivas:
# CREATE_BE
# ADD_BE
#
# e utiliza o arquivo padrao be_template, copiado no container.
#
# Seu funcionamento ocorre da seguinte forma:
#
# Ao ser executado o entrypoint do container verifica se está rodando em um rancher, caso positivo, 
# ele busca nos metadados do Rancher quais os links(backends) o varnish possui.
# Para cada Backend(Link) é consultado o ip de cada conteiner participante do serviço, e para cada um
# é criado um backend na diretiva CREATE_BE, e adicionado ao Director padrão bar, em ADD_BE.
#
# Caso deseja inutilizar esse template, basta montar o container no Rancher montando um volume com o VCL
# desejado. O container funcionará com qualquer VCL padrão do varnish.

import directors;
import std;

%CREATE_BE%

sub vcl_init {
    new bar = directors.round_robin();
    %ADD_BE%
}

sub vcl_recv {
    set req.backend_hint = bar.backend();

    unset req.http.Cookie;    

}

sub vcl_hit {
    if (!std.healthy(req.backend_hint) && (obj.ttl + obj.grace + obj.keep > 0s)) {
        return (deliver);
    }
}

sub vcl_backend_response {

    if (beresp.status == 503) {
        return (abandon);
    }

    ##unset beresp.http.Expires;  
    #unset beresp.http.Cache-Control;  
    #unset beresp.http.Pragma;  

    # Marker for vcl_deliver to reset Age: /  
    #set beresp.http.magicmarker = "1";  

    # Leveraging browser, cache set the clients TTL on this object /  
    set beresp.http.Cache-Control = "public, max-age=60";  

    # cache set the clients TTL on this object /  
    set beresp.ttl = 1m;  

    # Allow stale content, in case the backend goes down.  
    # make Varnish keep all objects for 6 hours beyond their TTL  
    ##set beresp.grace = 6h;    
    set beresp.grace = 2h;
    set beresp.keep = 2d;

    unset beresp.http.Cookie;

}
