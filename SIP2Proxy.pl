#! /usr/bin/perl -w

################################################################################
### Copyright (c) Michael Oehme (m.m.oehme@gmail.com)
### Last Modified: 2021-03-12
### Version 0.2 - 20210323
###
### License: GPLv3
###
### This program is free software; you can redistribute it and/or modify
### it under the terms of the GNU General Public License version 2 as
### published by the Free Software Foundation.
###
### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License for more details.
###
### You should have received a copy of the GNU General Public License
### along with this program; if not, write to the Free Software
### Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
###
################################################################################
################################################################################

################################################################################
### This program acts as a SIP2 proxy server. It also can modify the sip2 data
### on both ends (request and answer).
###
### For data modification you have to change the two functions &modifyRequest()
### and &modifyAnswer() to fit your needs.
###
### For me:
### - &modifyRequest(): returns the original request (no modifications).
###
### - &modifyAnswer(): koha (my LMS) did not give CL fields for sorting machines
###                    in the checkin response. On the other side the sorting
###                    machine has only the ability to use 1 field as sorting
###                    criteria (normaly set to CL). The manufacturer of my
###                    sorting machine is not able to adapt the software.
###                    Therefore i have to do it myself.
###                    So i take the checkin response from koha and add the
###                    CL field depending on the fields CV and CR.
###
################################################################################
################################################################################


################################################################################
### Changelog:
###
### 20210312 - mmo
### --------------
### start project
###
### 20210318 - mmo
### --------------
### first running version
### I hope all functions are present and no mayor bugs ...
###
### 20210323 - mmo
### --------------
### switched from IO::Socket to Net::Server::Fork for the main loop
### this makes the client handling much easier
###
### 20210329 - mmo
### --------------
### Listen on all interfaces for incomming connections
### changed CL-mapping
### dropped some useless lines
### dropped Proc:Deamon and use functions from NET:Server to run as daemon

################################################################################
### ToDo:
### - tell me

##################################################################################
package SIP2Proxy;

use strict;
use warnings;
use base qw/Net::Server::Fork/;
use IO::Socket qw/AF_INET AF_UNIX SOCK_STREAM/;
use Getopt::Long;

##################################################################################
my $PROGNAME=__FILE__;
my $VERSION="0.9 - 20210329";

################################################################################
### variables for command line parameters
my $version;
my $help;
my $daemon;
my $port=4004;
my $sip2serverIP='127.0.0.1';
my $sip2serverPort=4000;
my $logfilename;
my $logfile_fh;

################################################################################
### read command line parameters
Getopt::Long::Configure('bundling');
GetOptions(
  "v|version"       => \$version,
  "h|help"          => \$help,
  "d|daemonize"     => \$daemon,
  "p|port=i"        => \$port,
  "s|sip2server=s"  => \$sip2serverIP,
  "S|sip2port=i"    => \$sip2serverPort,
  "l|logfile=s"     => \$logfilename,
);

# disable buffering
#$|=1;

################################################################################
################################################################################
## SIP2 MODIFICATIONS

sub modifyRequest($){
## for now no modifications on the request. This sub is here just to be prepared
  return $_[0];
}

sub modifyAnswer($){
  my $request =$_[0];
  my $answer=$request;  #default: no modifications so return the original request

# only change the checkin response (10)
  if (($request =~ m/^10.*/) and ! ($request =~ m/.*\|CL.*/)){
    my $CV=$request; $CV =~ s/.*\|(CV[^|]*)\|.*/$1/; #extract CV-field, if exists
    my $CR=$request; $CR =~ s/.*\|(CR[^|]*)\|.*/$1/; #extract CR-field, if exists (this should exist!)

    ############################################################################
    ## CL field mapping
    ## for me: CV takes precedence over CR!
    my $CL='CL70';        #default: CL70 here is overflow bin

    # Which bin for which CV field
    if    ($CV eq "CV01")   { $CL="CL60"} #01 Vormerkung - 60
    elsif ($CV eq "CV02")   { $CL="CL60"} #02 Vormerkung andere Zweigstelle - 60
    elsif ($CV eq "CV04")   { $CL="CL62"} #04 alle Transfer - 62
    elsif ($CV =~ m/^CV.*/) { $CL="CL70"} #sonstige CVs
    # no CV field, so sorting from CR field
    elsif ($CR eq "CR0")    { $CL="CL61"}  #0	ZB - EG	EG	61
    elsif ($CR eq "CR1")    { $CL="CL61"}  #1	ZB - EG Info	EG	61
    elsif ($CR eq "CR10")   { $CL="CL66"}  #10	ZB - 1. OG	1. OG	66
    elsif ($CR eq "CR11")   { $CL="CL66"}  #11	ZB - 1. OG Info	1. OG	66
    elsif ($CR eq "CR20")   { $CL="CL63"}  #20	ZB - 2. OG	2. OG	63
    elsif ($CR eq "CR21")   { $CL="CL63"}  #21	ZB - 2. OG Info	2. OG	63
    elsif ($CR eq "CR22")   { $CL="CL65"}  #22	ZB - 2. OG AV-Medien	2. OG	65
    elsif ($CR eq "CR30")   { $CL="CL67"}  #30	ZB - 3. OG	3. OG	67
    elsif ($CR eq "CR31")   { $CL="CL67"}  #31	ZB - 3. OG Info	3. OG	67
    elsif ($CR eq "CR102")  { $CL="CL61"}  #102	ZB Magazin	EG	61
    elsif ($CR eq "CR106")  { $CL="CL61"}  #106	ZB Bestseller	EG	61
    elsif ($CR eq "CR107")  { $CL="CL65"}  #107	ZB Charts	2. OG	65
    elsif ($CR eq "CR120")  { $CL="CL66"}  #120	ZB Kinderbibliothek	1. OG	66
    elsif ($CR eq "CR122")  { $CL="CL64"}; #122	ZB Jugendbibliothek	1. OG	64
    ## END: CL field mapping
    ############################################################################

    #Build answer string
    my $AY=$request; $AY =~ s/.*\|(AY\d)AZ.*/$1/;  #preserve sequence number
    $answer =~ s/(.*)\|AY.*/$1/;     #drop SIP2 sequence number and checksum (AZ....)
    $answer .= "|".$CL."|".$AY."AZ"; #add CL field and sequence number
    $answer .= &SIP2Checksum($answer)."\r"; #add new checksum
  }
  return $answer;
}

sub SIP2Checksum($){
  my $checksum = 0;

  # summarize all characters
  foreach my $char (split('', $_[0])) {
    $checksum += ord($char);
  }
  # calculate 2's complement
  $checksum=(~$checksum)+1;
  # Mask out to the last 16bit
  $checksum = $checksum & 0xffff;
  return sprintf("%X", $checksum );
}

## END SIP2 MODIFICATIONS
################################################################################
################################################################################

################################################################################
### write data to logfile or STDOUT if no logfile is given
sub writeToLog($){
#  $logfile_fh->autoflush(1);
  # with valid logfile handle, ...
  if (defined $logfile_fh && $_[0]){
    # write the current local time ...
    print $logfile_fh "[".localtime(time())."] ";
    # ... and the message to the given logfile
    print $logfile_fh shift;
    print $logfile_fh "\n";
  } #else { warn "KEIN LOGFILE"}

}

##################################################################################
### check requirements and paramters
if (defined $version) {
  &print_version();
  exit 0;
  }

if (defined $help) {
  &print_help();
  exit 0;
  }

# is port a valid port?
if (  ! defined($port) && ! &check_Port($port)) {
    print "wrong port (must be numeric between 0 and 65535)";
    &print_help();
    exit 1;
}

# is SIP2serverPort a valid port?
if ( ! defined($sip2serverPort) && ! &check_Port($sip2serverPort) ) {
    print "wrong SIP2serverPort (must be numeric between 0 and 65535)";
    &print_help();
    exit 1;
}

# is $SIP2serverIP a valid IP?
if ( ! defined($sip2serverIP) && ! &check_IP($sip2serverIP) ) {
    print "wrong SIP2serverIP.";
    &print_help();
    exit 1;
}

# if logfile is set, it must be writable
if (defined $logfilename) {
  open($logfile_fh, ">>",$logfilename) or
  die "Cannot open logfile $logfilename. $!";
  # disable buffering
  $logfile_fh->autoflush(1);
#  $|=1;
#  select($logfile_fh);
} else {
  $logfile_fh = *STDERR; #STDERR because Net::Server redefines STDOUT
}

##################################################################################
sub check_IP($) {
  my $ip = shift;
  if ( ($ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/o) ) {
    return (1);
    }
  return (0);
}

##################################################################################
sub check_Port($) {
    my $port = shift;
    if ( $port*1 eq $port) {
  if ( $port >=0 || $port <=65535 ) {
      return (1);
  }
    }
    return (0);
}

##################################################################################
sub print_usage () {
  print "Usage: $PROGNAME [-v] [-h] [-d] [-l <logfile>] [-p <LOCALPORT>] [-s <SIP2serverIP] [-S <SIP2serverPort>]\n";
}

##################################################################################
sub print_version () {
  print "$PROGNAME $VERSION\n";
}

##################################################################################
sub print_help () {
  print "Copyright (c) 2021 Michael Oehme (m.m.oehme\@gmail.com)
SIP2 proxy server. This program listens on a tcp port (default 4004).
(This version adds the CL fields to the checkin response message, based on the CV and CR fields)
Feel free to modify to fit your own special needs. Functions to change: &modifyRequest and &modifyAnswer.

";
  &print_usage();
  print "-v, --version\t\tPrint version information
-h, --help\t\tPrint help
-d, --daemonize\t\trun programm as daemon
-l, --logfile=FILENAME\tFilename to write the logs to (default: STDERR)
-p, --port=PORT\t\tPort to listen on (default: 4004)
-s, --sip2server=IP\tIP of the LMS/SIP2-server (default: 127.0.0.1)
-S, --sip2port=PORT\tPort of the LMS/SIP2-server (default: 4000)
";
}


################################################################################
### START MAINLOOP
sub process_request{
  my $self = shift;

  # set record separator to \r (carriage return) as defined in 3M SIP2 documentation
  local $/ = "\r";

  # For logging we write the process ID with each message, because this code
  # can handle more than one client. With Net::Server::Fork every new client
  # connection gets its own PID;
  my $PID=$$;
  &writeToLog("[".$PID."] Connection established: ".$self->{server}->{client}->peerhost.':'.$self->{server}->{client}->peerport);

  # create socket to SIP2 server
  my $sip2server = new IO::Socket::INET(
    Proto    => 'TCP',
    PeerAddr => $sip2serverIP,
    PeerPort => $sip2serverPort,
    ) or die 'Could not connect to SIP2 server!';
    &writeToLog("[".$PID."] SIP2 server $sip2serverIP on port $sip2serverPort ");

  while (<STDIN>) {
    my $sip2request = $_;
    my $modrequest="";
    my $answer="";
    my $modanswer="";

    ## if modifications in the request before sending to SIP2 server are
    ## necessary, then change the function &modifyRequest to fit your needs
    ## and return the modified string.
    $modrequest=&modifyRequest($sip2request);
    ## Info to log
    if ($sip2request eq $modrequest){
      &writeToLog("[".$PID."] I: ".$sip2request);
    } else {
#      &writeToLog("[".$PID."] I: Request modified:\n\t\tfrom: ".$sip2request."\n\t\tto  : ".$modrequest);
      &writeToLog("[".$PID."] I: ".$sip2request);
      &writeToLog("[".$PID."] >: modified to: ".$modrequest);
    }
    ## send the (possible modified) request to the SIP2 server (your LMS) ...
    $sip2server->send($modrequest);

    # and receive the answer
    my $ok = $sip2server->recv($answer, 1024);

    ## if modifications in the answer before sending to the client are
    ## necessary, then change the function &modifyAnswer to fit your needs
    ## and return the modified string.
    $modanswer = &modifyAnswer($answer);
    # Info to log
    if ($modanswer eq $answer){
      &writeToLog("[".$PID."] O: ".$answer);
    } else {
#      &writeToLog("[".$PID."] O: Answer modified:\n\t\tfrom: ".$answer."\n\t\tto  : ".$modanswer);
      &writeToLog("[".$PID."] O: ".$modanswer);
      &writeToLog("[".$PID."] >: modified from: ".$answer);
    }
    # write response data to the connected client
    print $modanswer;
  }

  $sip2server->close;
  &writeToLog("[".$PID."] Connection closed.");
}

### END MAINLOOP
################################################################################

SIP2Proxy->run(port=>"*:".$port, background=>($daemon?1:0));
1;
