# $Rev: 203 $ - $Date: 2009-10-24 16:43:49 +0200 (sáb 24 de oct de 2009) $

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


package Mail::SpamAssassin::Plugin::simplerbl;
use strict;
use warnings;
use Mail::SpamAssassin;
use Mail::SpamAssassin::Plugin;
use XML::Writer;
use IO::File;
use File::Temp qw(tempfile);

use vars qw(@ISA);
@ISA = qw(Mail::SpamAssassin::Plugin);

sub dbg { 
	my $msg = shift;
	Mail::SpamAssassin::Plugin::dbg(sprintf("SIMPLERBL: $msg",@_));
}

sub new {
  my ($class, $mailsa) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new($mailsa);
  bless ($self, $class);
  $self->set_config($mailsa->{conf});
  $self->register_eval_rule ("simplerbl");
  return $self;
}

sub set_config {
  my ($self, $conf) = @_;
  my @cmds = ();
  push(@cmds, {
        setting => 'simplerbl_score',
        default => 0,
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_NUMERIC
  });

  push(@cmds, {
        setting => 'simplerbl_evdir',
        default => '/tmp/',
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_STRING
  });

  push(@cmds, {
        setting => 'simplerbl_redir',
        default => '/tmp/',
        type => $Mail::SpamAssassin::Conf::CONF_TYPE_STRING
  });
  
 $conf->{parser}->register_commands(\@cmds);
}

sub simplerbl {
  my ($self, $permsgstatus) = @_;
  my $evidencefile;
  my $recordfile;
  my $xmlfile;
  my %data;
  
  my $lasthop;
  my @addressparts;

  my $threshold = $permsgstatus->{main}->{conf}->{'simplerbl_score'};
  my $redir = $permsgstatus->{main}->{conf}->{'simplerbl_redir'};
  my $evdir = $permsgstatus->{main}->{conf}->{'simplerbl_evdir'};
  my $msg;

  if ($permsgstatus->{score} > $threshold )  {
  	eval {
  		$evidencefile = new File::Temp( UNLINK => 0, TEMPLATE => "evidence.XXXXXXXXXX", DIR => $evdir, SUFFIX => '.msg' );
  		$recordfile = new File::Temp( UNLINK => 0, TEMPLATE => "record.XXXXXXXXXX", DIR => $redir, SUFFIX => '.data' );
  		$xmlfile = new XML::Writer ( OUTPUT => $recordfile, ENCODING => 'utf-8' );
  	};
  	if ($@) {
  		dbg("Something went wrong opening files: $@\n");
  		return 0;
  	}

  	$data{from} = $permsgstatus->get('From:addr') || '';
  	chomp $data{from};
  	$data{to} = $permsgstatus->get('To:addr') || '';
  	chomp $data{to};
  	$data{date} = $permsgstatus->get_message()->receive_date();
  	$data{subject} = $permsgstatus->get('Subject') || '';
  	chomp $data{subject};
  	$data{score} = $permsgstatus->{score} || 0;
  	$lasthop = $permsgstatus->{relays_external}->[0];
  	$data{lasthop} = $lasthop->{ip} || '';
  	$data{file} = $evidencefile;
  	@addressparts = split('@', $data{to}); 
  	
  	# Write the file with the evidence. We try to hide the recipient address.
  	# You will CERTAINLY want to adapt this to your server's Received: header style. 
  	foreach my $line ( $permsgstatus->get('ALL') ) {
  		# First, the email address.
  		$line =~ s/$data{to}/MODIFIED/gi;
  		# Second, the user part of the address.
  		my $localpart = "for <$addressparts[0]";
  		$line =~ s/$localpart/for \<MODIFIED/gi;
  		print $evidencefile "$line";
  	}
  	
  	$data{rules} = $permsgstatus->get_names_of_tests_hit();
  	
  	# Create the xml record that will be processed and stored in the database.
  	$xmlfile->startTag('Record');
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('from',$data{from});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('to',$data{to});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('date',$data{date});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('subject',$data{subject});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('score',$data{score});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('lasthop',$data{lasthop});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('file',$data{file});
  	print $recordfile "\n\t";
  	$xmlfile->dataElement('rules',$data{rules});
  	print $recordfile "\n";
  	$xmlfile->endTag;
  	$xmlfile->end;
  	close $evidencefile;
  }
}

1;
