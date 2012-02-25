main.cf(5) -- Configuración principal de Postfix
================================================

## SYNOPSIS

`main.cf` - Fichero de configuración principal de Postfix.

## DESCRIPTION

El fichero `main.cf` define gran parte de los cambios sobre la instalación base que se hacen a Postfix. Por lo tanto, cualquier cambio que se realice en este fichero debe ser probado en servidores de pre producción.


`main.cf` es gestionado por `puppet(1)`. Los cambios que se apliquen directamente sobre este fichero serán sobreescritos.


En la siguiente lista se encuentran las modificaciones más significativas que se han ido aplicando al fichero:

* `message_size_limit`=20000:
     Se aplicó este límite de 20000 bytes a la configuración bla bla bla.

* `dovecot_destination_recipient_limit`=1:
     Opción más segura para controlar las entregas locales bla bla bla. El transport dovecot se define en `master.cf(5)`

* `smtpd_client_restrictions`=check_client_access cdb:/etc/postfix/clientes.out:
     Se define el fichero `clientes.out(5)`, como parte del grupo de restricciones en fase cliente, para rechazar aquellos clientes que no cumplan las normas de uso de la plataforma.

## INCIDENCIAS

[1234](http://bugtrack.example.com/?id=1234) - Cliente x con problemas de envío.

[5678](http://bugtrack.example.com/?id=5678) - Cliente z que envía miles de mensajes spam.

## HISTORY

2012-02-20, Versión inicial.

## AUTHOR

2012, Forondarena.net postmaster

## COPYRIGHT

Forondarena.net 

## SEE ALSO

`puppet(1)`, `master.cf(5)`, `clientes.out(5)`
