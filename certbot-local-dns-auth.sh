#!/bin/bash

# Authentication hook for certbot 
# using a local dns server with a master zone file

# Version 0.9.1

# Note: When setting up your zone file please take care that: 
# * the serial number (i.e. the 1st number in the brackets behind SOA)
#   is put in its own line commented by "; serial EDITED BY ACME HOOK"
# * the ttl is set to a low value
# Example: 
# subdom.example.com.      86400   IN  SOA ns.subdom.example.com.  admin.example.com. (
#                                                3               ; serial EDITED BY ACME HOOK
#                                                3600            ; refresh
#                                                1800            ; retry
#                                                3600000         ; expire
#                                                10              ; minimum ttl
#						)

# Read https://github.com/hatzfeld/certbot-local-dns for further explanations!

###########################################################################
                ###  Configuration Section  ###

# Before using this script, make sure that $ZONEFILE and at least 
# those $DNS*CMD you intend to use contain the correct values!

# where your master zone file is located
# (you may use $CERTBOT_DOMAIN which will contain your (sub-)domain)
ZONEFILE="/var/lib/yadifa/masters/$CERTBOT_DOMAIN.zone"

# command to make the dns server apply changes in the master zone file
# (used when invoked without arg or with arg "cleanup")
DNSRELOADCMD="systemctl reload yadifa.service"

# command to start the dns server when it's inactive
# (used when invoked with arg "start")
DNSSTARTCMD="systemctl start yadifa.service"

# command to stop the dns server
# (used when invoked with arg "stop")
DNSSTOPCMD="systemctl stop yadifa.service"

# ttl of challenge TXT record (do not change it unless necessary)
TTL=10

# how long to wait for DNS changes to propagate (seconds)
WAIT=30

# how long to wait when script run in terminal for testing (instead of $WAIT)
TESTWAIT=3

              ###  End of configuration section  ###
###########################################################################

MODE=$1
if [ "$MODE" != "" -a "$MODE" != "cleanup" -a "$MODE" != "start" -a "$MODE" != "stop" ]; then
  echo "Script $0 called with unknown arg $MODE"
  exit 2
fi

ACMESUBDOMAIN="_acme-challenge"

if [ ! -f "$ZONEFILE" ]; then
  echo "Zone file $ZONEFILE not found."
  exit 1
fi

error=""

if [ "$CERTBOT_DOMAIN" = "" ]; then
  acmesd="$ACMESUBDOMAIN"
  if [ "$MODE" != "cleanup" -a "$MODE" != "stop" ]; then
    error="$error\nWARNING: missing environment variable CERTBOT_DOMAIN"
  fi
else
  acmesd="$ACMESUBDOMAIN.$CERTBOT_DOMAIN."
fi

if [ "$CERTBOT_VALIDATION" = "" ]; then
  ts=$(date -Iseconds)
  CERTBOT_VALIDATION="_No_validation_string_provided_at_${ts}_"
  if [ "$MODE" != "cleanup" -a "$MODE" != "stop" ]; then
    error="$error\nWARNING: missing environment variable CERTBOT_VALIDATION - using dummy value instead"
  fi
fi

if [ -t 1 ]; then
  WAIT=$TESTWAIT
fi

# update serial number in zone file copy
# get line containing the serial number ...
serialline=$(grep 'serial EDITED BY ACME HOOK' "$ZONEFILE")
if [ $? -ne 0 ]; then
  error="$error\nERROR: serial number not found in SOA, will not be changed."
  snr=""
  if [ "$MODE" = "" -o "$MODE" = "start" ]; then
    cat "$ZONEFILE" >"$ZONEFILE.$$"
  else
    # delete eventual old validation code
    grep -v "^$ACMESUBDOMAIN.*TXT.*changed" "$ZONEFILE" >"$ZONEFILE.$$"
  fi
else
  # get serial number
  snr=${serialline//[^0-9]/}
  # increase it
  snr=$(($snr+1))
  if [ "$MODE" = "" -o "$MODE" = "start" ]; then
    cat "$ZONEFILE" | sed -r 's/^.*serial EDITED BY ACME HOOK.*$/                                  '"$snr"' ; serial EDITED BY ACME HOOK/' >"$ZONEFILE.$$"
  else
    # delete eventual old validation code
    grep -v "^$ACMESUBDOMAIN.*TXT.*changed" "$ZONEFILE" | sed -r 's/^.*serial EDITED BY ACME HOOK.*$/                                  '"$snr"' ; serial EDITED BY ACME HOOK/' >"$ZONEFILE.$$"
  fi
fi

if [ "$MODE" = "" -o "$MODE" = "start" ]; then
  # add challenge validation code
  echo -n "$acmesd $TTL IN TXT $CERTBOT_VALIDATION ; changed by $0 on " >>"$ZONEFILE.$$"
  date -R >>"$ZONEFILE.$$"
fi

# replace zone file
mv "$ZONEFILE.$$" "$ZONEFILE"

# restart/reload/start/stop dns server
if [ "$MODE" = "" -o "$MODE" = "cleanup" ]; then
  $DNSRELOADCMD
fi
if [ "$MODE" = "start" ]; then
  $DNSSTARTCMD
fi
if [ "$MODE" = "stop" ]; then
  $DNSSTOPCMD
fi

# wait for new value to propagate
if [ "$MODE" = "" -o "$MODE" = "start" ]; then
  sleep $WAIT
fi

# show eventual error messages
if [ "$error" != "" ]; then
  echo -e "Errors occured:$error"
  exit 2
fi
