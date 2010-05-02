# $Rev: 267 $ - $Date: 2010-05-02 13:49:29 +0200 (dom 02 de may de 2010) $

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
use XML::Simple;
use IO::File;
use DBI;
use File::Copy;
use Config::Std;

my %rblconfig;

# XML files and directories
my $redir = "/tmp";
my $evdir = "/tmp";
my $stdir = "/tmp";
my $tmpstdir = "";
my $evidence;
my $record;
my $filehandle;

# XML attributes
my $ip;
my $epoch;
my $file;
my $rules;
my $subject;
my $score;
my $to;
my $from;

# Database connection
my $dbh;
my $sth;
my $matches;

# Database record
my $entry;
my $txt;
my $a;
my $times;
my $active;
my $permanent;
my $processed;

my $storeevidence;

###########################################################################
# THERE IS ALMOST NO ERROR DETECTION IN THIS CODE. USE IT AT YOU OWN RISK #
###########################################################################

eval {
	read_config '/tmp/gauzak/simplerbl.cfg' => %rblconfig;
	$stdir = $rblconfig{Worker}{stdir};
	
	$dbh = DBI->connect("DBI:Pg:dbname=$rblconfig{General}{dbname};host=$rblconfig{General}{dbhost}", $rblconfig{General}{dbuser}, $rblconfig{General}{dbpassword}, {RaiseError => 1, ShowErrorStatement => 1} );

	$filehandle = new IO::File($rblconfig{Worker}{sacfgfile}, "r") or die "simplerblWorker: Unable to open $rblconfig{Worker}{sacfgfile}: $!\n";
	while (my $line = $filehandle->getline()) {
		next if ($line =~ /^\s*#/);
		if ($line =~ /^simplerbl_redir\s+(\S*)/i) {
			$redir = $1;
		}
		if ($line =~ /^simplerbl_evdir\s+(\S*)/i) {
			$evdir = $1;
		}
	}
};
if ($@) {
	die "simplerblWorker: Error opening spamassassin config. Pluging config path/permissions are probably incorrect\n";
}

print "simplerblWorker: Record directory is $redir\n\n";

opendir my $DIR, $redir || die "simplerblWorker: Error opening $redir: $!\n";

for $record ( grep /^record\.\S{10}\.data$/, readdir($DIR) ){
	$storeevidence = 0;
	# Security checks. Files should probably be checked before processing. To Do
	
	eval {
		open my $utf8in, "<:encoding(utf8)", "$redir/$record";
		#$evidence = XMLin("$redir/$record");
		$evidence = XMLin($utf8in);
		close $utf8in;
	};
	if ($@) {
		print "simplerblWorker: Unable to open $record: $@\n";
		next;
	}
	
	print "simplerblWorker: Processing $redir/$record ";
	
	$ip = $evidence->{lasthop};
	$rules = $evidence->{rules};
	$subject = $evidence->{subject};
	$epoch = $evidence->{date};
	$score = $evidence->{score};
	$to = $evidence->{to};
	$from = $evidence->{from};
	$file = $evidence->{file};
	
	$file =~ s#/\S*(evidence\.)(\S{2})(\S{8}\.msg)$#$stdir/$2/$1$2$3#;
	$tmpstdir = "$stdir/$2";
	
	# We should choose what list to put the entry into. We can use origin, or score, or triggered rules or whatever.
	# This example is simple. I only use the score. 
	
	if ($score <= 10) {
		$a = '127.0.0.2';
	}
	if ($score > 10 and $score <= 15) {
		$a = '127.0.0.3';
	}
	if ($score > 15) {
		$a = '127.0.0.4';
	}
	
	# Is the IP already listed? This is a simple check to be extended.
	# Assertions might be useful here. Like entries not processed but marked as solved.
	$sth = $dbh->prepare("SELECT * FROM rblentry where ip = ?");
	$sth->execute("$ip");
	$matches=$sth->rows();
	
	if ($matches > 1){
		die "simplerblWorker: There cannot be more than one entry. Stopping now. Check $record\n";
	}
	if ($matches == 0) {
		# New entry
		$sth = $dbh->prepare("INSERT INTO rblentry (ip, epoch, a, file) VALUES (?,?,?,?)");
		$sth->execute("$ip", "$epoch", "$a", "$file");
		$storeevidence = 1;
	}
	if ($matches == 1){
		# We should check if the message was stored in the database with a different score, but we dont.
		$entry = $sth->fetchrow_hashref();
		if ($entry->{solved}) {
			# The entry was marked as solved. This means that it must not be active. We could double check here, but we don't.
			# We remove the solved flag, store the new evidence and remove the old one.
			# The processed flag must be active. The report generator will notify the sender about the new evidence.
			# We increase the times value.
			print "Received spam from an address marked as solved. Updating evidence";
			$sth = $dbh->prepare("UPDATE rblentry SET times = times + 1, solved = FALSE, a = ?, epoch = ?, file = ? where ip = ?");
			$sth->execute("$a", "$epoch", "$file", "$ip");
			unlink($entry->{file}) || die "simplerblWorker: Something went wrong with unlink $entry->{file}: $!. Stopping now. Check\n";
			$storeevidence = 1;
		} else {
			# The entry is not solved. It must be either active or reincident and not yet processed. We don't worry about it. 
			# We increase times value. The simplerblDNS will act upon this times value.
			$sth = $dbh->prepare("UPDATE rblentry SET times = times + 1 where ip = ?");
			$sth->execute("$ip");
		}
	}
	
	print "... Done\n";

	if ($storeevidence == 0) {
		# We already had an entry, no need to store the evidence in this example.
		print "simplerblWorker: No need to store the evidence. Already have one\n";
		unlink($evidence->{file}) || die "simplerblWorker: Something went wrong with unlink $evidence->{file}: $!. Stopping now. Check\n";
	} else {
		# The record is either new or from a formerly solved case. We store the evidence.
		print "simplerblWorker: Moving evidence to permanent storage\n";
		if (! -d $tmpstdir) {
			mkdir $tmpstdir || die "simplerblWorker: Unable to create $tmpstdir: $!. Stopping now. Check\n";
		}
		move($evidence->{file},$file) || die "simplerblWorker: Unable to move $file: $!. Stopping now. Check\n";
	}
	
	# Do we really want to delete the record or should we keep it.
	# This example deletes it. If we choosed not to, we should probably store it somewhere else.

	print "simplerblWorker: Deleting record $redir/$record\n";
	unlink("$redir/$record") || die "simplerblWorker: Something went wrong with unlink $redir/$record: $!. Stopping now. Check\n";
}

# clean up
$dbh->disconnect();

closedir $DIR;
