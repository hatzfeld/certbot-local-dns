#!/bin/bash
#
# certbot renew-hook script
#
# Syntax:
#   certbot renew --renew-hook [path/]certbot-renewal-hook.sh
#
# This file is intended to contain the commands you want to be executed
# after a renewal of any of the certificates configured in your system.
#
# You may comment out and adjust one or more of these examples or insert 
# your own commands.

## adapt this to your needs
MYDOMAIN=subdom.example.com


## copy cert files to a place where e.g. apache will need them
# cd /etc/letsencrypt/live/$MYDOMAIN/
# cp -L fullchain.pem /etc/ssl/certs/$MYDOMAIN.pem
# cp -L privkey.pem /etc/ssl/private/$MYDOMAIN.pem

## restart apache2 webserver
# systemctl restart apache2.service

## reload postfix mailserver
# systemctl reload postfix.service


## copy cert files to another host - adapt path to your (sub)domain!
## to make this work you must set up ssh key authentication 
# cd /etc/letsencrypt/live/$MYDOMAIN/
# scp *.pem otherserver.example.com:/somewhere/
