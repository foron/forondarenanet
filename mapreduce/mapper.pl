#!/usr/bin/perl

# $Rev: 265 $ - $Date: 2010-03-21 19:33:53 +0100 (dom 21 de mar de 2010) $

# Copyright 2010 Forondarena.net

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

use warnings;
use strict;

# Este ejemplo se recibe correo, que es analizado siempre por amavis o similar en modo after queue
# Una vez hecho esto los correos que pasen o se entregan en local con maildrop (no hay expansion de alias en el ejemplo) o se envia a un servidor remoto


my $linea = "";

my %estructura = ();

while (<>) {
	$linea = $_;
	chomp $linea;

	##############################################
	### Se tratan diferentes formatos de linea ###
	### El sistema debe reconocerlas todas     ###
	##############################################
	#
	# Mensaje nuevo desde smtp:
	#
	if ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/smtpd\[\d+\]: (\w+): client=(\S+)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2; $estructura{host} = $3;

		print $estructura{qid} . "\t" . "Conexion," . join (",",$estructura{fecha},$estructura{host}) . "\n";
	}
	##################################################################################################
	# msg_id
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/cleanup\[\d+\]: (\w+): message-id=<(\S+)>$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;	$estructura{msgid} = $3;

		print $estructura{qid} . "\t" . "Msgid," . join (",",$estructura{fecha},$estructura{msgid}) . "\n";
	}
	##################################################################################################
	# Origen y tamaño del mensaje.
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/qmgr\[\d+\]: (\w+): from\=\<(.*)\>, size=(\d+)/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;	$estructura{from} = $3 eq ""?"MAILER-DAEMON":$3; $estructura{size} = $4; 

		print $estructura{qid} . "\t" . "Origen," . join (",",$estructura{fecha},$estructura{from},$estructura{size}) . "\n";
	}
	##################################################################################################
	# Entregas via smtp a amavis local.
	# Importante, no hay address expansion aqui.
	#
	# Caso 1: pasa y se reencola. Guardamos el qid relacionado en rqid
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/smtp\[\d+\]: (\w+): to\=\<([^ ]+)\>, relay=127.0.0.1.*status=(.*) (\w+)\)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;	$estructura{to} = $3; $estructura{origto} = $3; $estructura{status} = $4; $estructura{relay} = "Antispam"; $estructura{rqid} = $5; $estructura{status} =~ s/,//g;

		print $estructura{qid} . "\t" . "Antispam," . join (",",$estructura{fecha},$estructura{to},$estructura{to},$estructura{relay},$estructura{status},$estructura{rqid}) . "\n";
	}
	# Caso 2: Se bloquea, no se reencola. Ponemos el rqid como 0
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/smtp\[\d+\]: (\w+): to\=\<([^ ]+)\>, relay=127.0.0.1.*status=(.*) \)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;	$estructura{to} = $3; $estructura{origto} = $3; $estructura{status} =$4; $estructura{relay} = "Antispam"; $estructura{rqid} = "0"; $estructura{status} =~ s/,//g;

		print $estructura{qid} . "\t" . "Antispam," . join (",",$estructura{fecha},$estructura{to},$estructura{to},$estructura{relay},$estructura{status},$estructura{rqid}) . "\n";
	}
	##################################################################################################
	# Entregas a remoto usando smtp, con address expansion
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/smtp\[\d+\]: (\w+): to\=\<(.*)\>, orig_to\=\<(.*)\>, relay=(.+), delay=.* status=(.*)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;	$estructura{to} = $3; $estructura{origto} = $4; $estructura{relay} = $5; $estructura{status} =$6; $estructura{rqid} = "-1"; $estructura{status} =~ s/,//g; $estructura{relay} =~ s/,//g;

		print $estructura{qid} . "\t" . "Smtp," . join (",",$estructura{fecha},$estructura{to},$estructura{origto},$estructura{relay},$estructura{status},$estructura{rqid}) . "\n";
	}
	# Entregas a remoto usando smtp, sin address expansion
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/smtp\[\d+\]: (\w+): to\=\<(.*)\>, relay=(.+), delay=.* status=(.*)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;	$estructura{to} = $3; $estructura{origto} = $3; $estructura{relay} = $4; $estructura{status} =$5; $estructura{rqid} = "-1"; $estructura{status} =~ s/,//g; $estructura{relay} =~ s/,//g;

		print $estructura{qid} . "\t" . "Smtp," . join (",",$estructura{fecha},$estructura{to},$estructura{origto},$estructura{relay},$estructura{status},$estructura{rqid}) . "\n";
	}
	#################################################################################################
	# Entregas locales con maildrop, con address expansion 
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/pipe\[\d+\]: (\w+): to\=\<([^ ]+)\>, orig_to\=\<(.*)\>, relay=maildrop,.*status=(.+)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2; $estructura{to} = $3; $estructura{origto} = $4; $estructura{relay} = "Maildrop"; $estructura{status} =$5; $estructura{rqid} = "-1"; $estructura{status} =~ s/,//g; $estructura{relay} =~ s/,//g;

		print $estructura{qid} . "\t" . "Maildrop," . join (",",$estructura{fecha},$estructura{to},$estructura{origto},$estructura{relay},$estructura{status},$estructura{rqid}) . "\n";
	}
	# Entregas locales con maildrop, sin address expansion 
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/pipe\[\d+\]: (\w+): to\=\<([^ ]+)\>, relay=maildrop,.*status=(.+)$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2; $estructura{to} = $3; $estructura{origto} = $3; $estructura{relay} = "Maildrop"; $estructura{status} =$4; $estructura{rqid} = "-1"; $estructura{status} =~ s/,//g; $estructura{relay} =~ s/,//g;

		print $estructura{qid} . "\t" . "Maildrop," . join (",",$estructura{fecha},$estructura{to},$estructura{origto},$estructura{relay},$estructura{status},$estructura{rqid}) . "\n";
	}
	#################################################################################################
	# Mensaje cerrado
	elsif ($linea =~ /^(\w{3} \d{2} \d{2}:\d{2}:\d{2}) .+ postfix\/qmgr\[\d+\]: (\w+): removed$/) {
		$estructura{fecha} = $1; $estructura{qid} = $2;

		print $estructura{qid} . "\t" . "Cierre," . join (",",$estructura{fecha}) . "\n";
	}
} # while

