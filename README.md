# MyVarnish

Varnish integrado ao Rancher
============================

Ao subir um container varnish, para configurá-lo com um backend customizado, basta utilizar os
service links do rancher. Ou seja, o service link configurado ao criar o servico Varnish é utilizado para criar o Backend do servidor, independente da Stack ao qual o Servico pertence.

Nesta versão é suportado a criação de backend de um Service comum do Rancher e de um External Servic..
No caso de External Service, é suportado apenas o servico que aponta para um ou mais IPs. External services que utilizam o hostname não são suportados.

O próprio container se encarreda de criar um director e um backend para cada IP encontrado, tanto para o Service quanto para o ExternalService.


