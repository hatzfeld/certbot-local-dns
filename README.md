# certbot-local-dns
certbot authentication hook for a local domain name server

## Why?

Letsencrypt has become quite popular to obtain SSL certificates for single (sub-)domains.
It is a bit more complicated to obtain a wildcard certificate (e.g. \*.example.com),
since letsencrypt will deliver such certificates only on the base of a dns authentication.
If a DNS providers does not offer an API which allows such a modification, a solution may
be to delegate a subdomain to a name server on a host under your control.

## What does certbot-local-dns-auth.sh?

certbot-local-dns-auth.sh is a small script which may be used by EFF's certbot for authentication.

It does this by modifying a master zone file of a domain name server running on the local host.
This allows the automatic renewal of the wildcard certificate.
