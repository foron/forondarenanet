# $Rev: 257 $ - $Date: 2010-03-19 20:30:57 +0100 (vie 19 de mar de 2010) $

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
use Net::DNS;
use Net::IP qw(:PROC);
use IO::File;
use Getopt::Std;
#use Data::Dumper;


my $filehandle;
my $file="/tmp/ips.txt";

my $sleepcount=20;
my $tmpsleepcount=0;
my $sleeptime=5;

my $resolver;   
my $query;
my @resolverdata;

my $ip;
my $reverse1;
my $reverse2;

my $tmpiprange;
my $tmpbiniprange;

my $tmpbinip;

my $found=0;

# If an ASN is listed more than this number of times we give more information.
my $infoextend=6;

my %byip;
my %byasn;

our ($opt_h, $opt_f);


getopts('hf:');

if ($opt_h) { &help; };

if ($opt_f) {
	$file = $opt_f;
}

$resolver = Net::DNS::Resolver->new;

$filehandle = new IO::File($file, "r") or die "Could not open $file: $!\n";
while (my $tmpline = $filehandle->getline()) {
	if ( ($tmpsleepcount > 0) and ($tmpsleepcount % $sleepcount == 0) ) {
		# Be polite. Sleep for a while.
		sleep $sleeptime;
	}

	$found=0;
	chomp $tmpline;
	$tmpline =~ s/^\s+//;
	$tmpline =~ s/\s+$//;
	
	if (!ip_is_ipv4($tmpline)) {
		print "$tmpline is not an IP address\n";
		next;
	}
	$tmpbinip=new Net::IP ($tmpline,4) || die (Net::IP::Error());

	# Do we have the IP already listed ?
	foreach my $tmpipr (keys %byip) {
		$tmpiprange = $tmpipr;
		$tmpbiniprange=new Net::IP ($tmpiprange,4) || die (Net::IP::Error()); 
		if ($tmpbinip->overlaps($tmpbiniprange) == $IP_A_IN_B_OVERLAP) {
			$found=1;
			last;
		}
	}
	
	if ($found) {
		# We already have the IP listed.
		$byip{$tmpiprange}->{times} +=1;
	} else {
		# Prepare the DNS query.
		$ip = ip_reverse ($tmpline);
		$ip =~ s/\.in-addr.arpa\.//;

		$reverse1 = $ip . "\.origin\.asn\.cymru\.com";
		# We could use reverse2 to list BGP peers. We won't in this example.
		$reverse2 = $ip . "\.peer\.asn\.cymru\.com";

		$query = $resolver->query("$reverse1","TXT");
		$tmpsleepcount += 1;
		if ($query) {  
			foreach my $rr ($query->answer) {
				@resolverdata=split(/ \| /, $rr->txtdata);
				if (!defined $byip{$resolverdata[1]}) {
					$byip{$resolverdata[1]} = { 'asn' => $resolverdata[0], 'country' => $resolverdata[2], 'times' => 1 };
				}
			}
		} else {
			warn "$tmpiprange does not have a txt record\n";
			exit;
		}
	}
}

foreach my $key (keys %byip) {
	if (defined $byasn{$byip{$key}->{asn}}) {
		$byasn{$byip{$key}->{asn}}->{times} += $byip{$key}->{times};
		if ( $byasn{$byip{$key}->{asn}}->{ip} !~ /$key/ ) {
			$byasn{$byip{$key}->{asn}}->{ip} .= " $key";
		}
		if ( $byasn{$byip{$key}->{asn}}->{times} > $infoextend ) {
			$reverse1 = "AS" . $byip{$key}->{asn} . "\.asn\.cymru\.com";
			$query = $resolver->query("$reverse1","TXT");
			if ($query) {
				foreach my $rr ($query->answer) {
					@resolverdata=split(/ \| /, $rr->txtdata);
					$byasn{$byip{$key}->{asn}}->{desc} = $resolverdata[4];
				}
			}
		}

	} else {
		$byasn{$byip{$key}->{asn}} = { 'ip' => $key, 'country' => $byip{$key}->{country}, 'times' => $byip{$key}->{times}, 'desc' => '' };
	}
}


# This block would give information ordered by IP address.
#foreach my $key (keys %byip) {
#	if ( $byip{$key}->{times} > $infoextend) {
#		$reverse1 = "AS" . $byip{$key}->{asn} . "\.asn\.cymru\.com";
#		$query = $resolver->query("$reverse1","TXT");
#		if ($query) {
#			foreach my $rr ($query->answer) {
#			@resolverdata=split(/ \| /, $rr->txtdata);
#			print "The IP $key that belongs to AS $byip{$key}->{asn} \($resolverdata[4]\) from $byip{$key}->{country}, has appeared $byip{$key}->{times}";
#			}
#		}
#	} else { 
#		print "$byip{$key}->{times} times ha aparecido $key, perteneciente al AS $byip{$key}->{asn} de $byip{$key}->{country}\n";
#	}
#}



foreach my $key (keys %byasn) {
	print "$byasn{$key}->{times} ";
	print "times has appeared the ASN $key ";
	print "from \( $byasn{$key}->{country} $byasn{$key}->{desc}\) ";
	print "and the following address ranges: $byasn{$key}->{ip}\n";
}

##print Dumper (%byip);
##print Dumper (%byasn);

sub help () {
print <<HELP;
usage: findASN.pl <param>
This software gives information about the ASN of a list of IPv4 (only) addresses.
Params:
\t-h: this help
\t-f: file with IP addresses
HELP
	
	exit 1;
}
