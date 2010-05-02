#!/usr/bin/perl

# $Rev: 266 $ - $Date: 2010-03-21 19:34:01 +0100 (dom 21 de mar de 2010) $

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

use strict;
use warnings;
use Switch;
use MIME::Base64;

my $qidanterior = "";
my $qid = "";
my $valor = "";
my @datos = ();
my %mensaje = (qid => "",
				fecha => "",
				servidor => "",
				msgid => "",
				origen => "",
				size => "",
				to => "",
				origto => "",
				rqid => "",
				relay => "",
				status => "",
				cierre => ""
			);

# rqid = 0:Bloqueado.
# 		-1:No procede.
#		qid: QueueID relacionado

while (<>) {
	chomp;
    ($qid, $valor) = split /\t/;
	
	if ($qid ne $qidanterior) {
		# tenemos un queueid nuevo
		if ($qidanterior ne "") {
			&mostrar_datos();

			%mensaje = (qid => "",
				fecha => "",
				desdeip => "",
				msgid => "",
				origen => "",
				size => "",
				to => "",
				origto => "",
				rqid => "",
				status => "",
				cierre => ""
			);
		}
		$qidanterior = $qid;
	}

	# seguimos procesando los datos del mismo qid
	$mensaje{qid} = $qid;
	@datos = split(",",$valor);

	# Dependiendo del tipo de linea. En los casos de clientes smtp
	#  $datos[0] = tipo de linea
	#  $datos[1] = fecha
	#  $datos[2] = to
	#  $datos[3] = origto
	#  $datos[4] = relay
	#  $datos[5] = status

	switch ($datos[0]) {
		case "Conexion" {
			$mensaje{fecha} = $datos[1];
			$mensaje{desdeip} = $datos[2];
		}
		case "Msgid" {
			$mensaje{msgid} = $datos[2];
		}
		case "Origen" {
			$mensaje{origen} = $datos[2];
			$mensaje{size} = $datos[3];
		}
		case "Antispam" {
			$mensaje{to} .= $datos[2] . "-separador-";
			$mensaje{origto} .= $datos[3] . "-separador-";
			$mensaje{status} .= $datos[1] . " " .$datos[2] . " " . $datos[3] . " " . $datos[4] . " " . $datos[5] . "-separador-";
			$mensaje{rqid} = $datos[6];
		}
		case "Smtp" {
			$mensaje{to} .= $datos[2] . "-separador-";
			$mensaje{origto} .= $datos[3] . "-separador-";
			$mensaje{status} .= $datos[1] . " " .$datos[2] . " " . $datos[3] . " " . $datos[4] . " " . $datos[5] . "-separador-";
			$mensaje{rqid} = $datos[6];
		}
		case "Maildrop" {
			$mensaje{to} .= $datos[2] . "-separador-";
			$mensaje{origto} .= $datos[3] . "-separador-";
			$mensaje{status} .= $datos[1] . " " .$datos[2] . " " . $datos[3] . " " . $datos[4] . " " . $datos[5] . "-separador-";
			$mensaje{rqid} = $datos[6];
		}
		case "Cierre" {
			$mensaje{cierre} = $datos[1];
		}
	}
	
}

# Falta la ultima linea de log, pero no quiero alargar el ejemplo.
&mostrar_datos(%mensaje);

sub mostrar_datos {
	my $resto = "";
	my $datoscodificables = "";
	my $fechaentrada = "";
	my $fechasalida = "";

	$mensaje{to} =~ s/-separador-$//g;
	$mensaje{origto} =~ s/-separador-$//g;
	$mensaje{status} =~ s/-separador-$//g;

	if ( ($mensaje{fecha} ne "") && ($mensaje{cierre} ne "") ) {
		# mensaje completo: Salida estandar
		# hay que revisar que se haya pasado por todas las fases 
		# y realizar comprobaciones, que aqui no se hacen
		# Voy a pasar la fecha a epoch. Deberia usar algo nativo de perl, pero es una prueba

		$fechaentrada = `date -u -d '$mensaje{fecha}' '+%s'`; chomp $fechaentrada;
		$fechasalida = `date -u -d '$mensaje{cierre}' '+%s'`; chomp $fechasalida;
		$datoscodificables = $mensaje{desdeip} .",".$mensaje{size}.",".$fechasalida.",".$mensaje{qid}.",".$mensaje{rqid}.",".$mensaje{status};
		$resto = encode_base64($datoscodificables,""); 

		print $mensaje{msgid} . "\t" . $fechaentrada . " " . $mensaje{origen} . " " . $mensaje{to} . " " . $mensaje{origto} . $resto . "\n";

	} else {
		# mensaje incompleto. Guardar
		#print "se guarda $mensaje{qid}\n";
	}
}
