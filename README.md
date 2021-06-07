# SIP2Proxy

# Quick installation
Copy the script SIP2Proxy.pl to a place of your choice (i.e. /opt/sip2proxy/)
and start it.


#Synopsis
This Script takes some command line parameters (Defaults in brackets). 

|short|long|description|default
|---|---|---|
|-v |--version    | print out the version
|-h |--help       | give some intructions
|-d |--daemonize  | run in background
|-p |--port       | port to listen on| (4004)
|-s |--sip2server | IP of the SIP2 server| (127.0.0.1)
|-S |--sip2port   | port of the SIP2 server| (4000)
|-l |--logfile    | name of the logfilename


# Purpose
This program acts as a SIP2 proxy server. It also can modify the SIP2 data on
both ends (request and answer).

This program listens on a tcp port (default 4004) and adds the CL fields to the
checkin response message, based on the CV and CR fields. Feel free to modify to
fit your own special needs.

For data modification you have to change the two functions &modifyRequest()and
&modifyAnswer() to fit your needs.

For me:

- &modifyRequest(): returns the original request (no modifications).

- &modifyAnswer():  koha (my LMS) did not give CL fields for sorting machines in
                    the checkin response. On the other side the sorting machine
                    has only the ability to use 1 field as sorting criteria
                    (normaly set to CL).
                    The manufacturer of my sorting machine is not able to adapt
                    the software. (Thank you for nothing)
                    Therefore i have to do it by myself. So i take the checkin
                    response from koha and add the CL field depending on the
                    fields CV and CR. (see source code)


# Longer installation instructions
Copy the file SIP2Proxy.pl to a place of your choice. *(I use the directory
/opt/sip2proxy)*. Now the script is ready to run.

A systemd unit file and a logrotate file is also provided and can copied to the
corresponding locations on the target system. Finally the files needs to get
adjusted to the local system (file path). Restart systemd and if necessary
logrotate.


# License
GPLv3

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License version 3 as published by the Free
Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 675 Mass Ave,
Cambridge, MA 02139, USA.
(see file LICENSE)

