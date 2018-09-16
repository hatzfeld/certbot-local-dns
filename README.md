# certbot-local-dns
certbot acme authentication hook for a local domain name server

## Why?

Letsencrypt has become quite popular to obtain SSL certificates for single (sub-)domains. It is a bit more complicated to obtain a wildcard certificate (e.g. \*.example.com or \*.subdom.example.com), since letsencrypt will deliver such certificates only on the base of a dns authentication. If a DNS providers does not offer an API which allows such a modification, a solution may be to delegate a subdomain to a name server on a host under your control.

## What does certbot-local-dns-auth.sh?

certbot-local-dns-auth.sh is a small bash script which may be used as a hook by EFF's certbot for authentication.

It does this by modifying a master zone file of a domain name server running on the local host. This allows the automatic renewal of the wildcard certificate.

The script is prepared for the name server **yadifa**, but may as well be used for other nameservers which support the common zone file syntax.

## Installation

### 1. Install certbot 
Use the package provider of your system (e.g. **apt install letsencrypt** or **apt install certbot**) and/or the instructions at https://certbot.eff.org.

### 2. Install and configure DNS
Follow the instructions of the domain name server you have installed or want to install. The author of this script used yadifad in the configuration of his Ubuntu 18.04 (**apt install yadifa**, config file: /etc/yadifa/yadifad.conf).

Special attention is needed to create the master zone file. If you want to obtain certificates for \*.subdom.example.com, it should start more or less like this:
```
$TTL    86400   ; 24 hours
$ORIGIN subdom.example.com.
subdom.example.com.     86400   IN  SOA ns.subdom.example.com.  webmaster.example.com. (
                                                1               ; serial EDITED BY ACME HOOK
                                                3600            ; refresh
                                                1800            ; retry
                                                3600000         ; expire
                                                10              ; minimum ttl
                                                )
subdom.example.com.      1800   IN  A           999.888.777.666
subdom.example.com.      1800   IN  NS          ns.subdom.example.com.
ns                       1800   IN  A           999.888.777.666
...
```
The number 999.888.777.666 has to be substituted by the external IP of your server (in case you do not know it, try /sbin/ifconfig).

For the script to work it is important to have the serial number in a row for itself, commented by "; serial EDITED BY ACME HOOK" as shown above. Please also note the low value of minimum ttl.

Obviously you must (now or later) add records for the (sub-)subdomains you want use with the wildcard certicate. If all your subdomains will be used on the same host, it may be sufficient to add:
```
*.subdom.example.com.      1800   IN  A           999.888.777.666
```

Finally start the nameserver. In case of yadifa on Ubuntu this is done by
```
systemctl start yadifa.service
```

To look whether port 53 (DNS) is really served by your name server, you may call:
```
lsof -Pi | grep :53
```

If a local resolver is blocking the internal (i.e. localhost) port 53 (as in my case), you may either substitute the internal resolver by your newly installed name server or limit the name server to serve port 53 only for external access (e.g. in yadifa's config file by "listen 999.888.777.666:53" instead of "listen :53").

To test the name server, you may use e.g. this command:
```
host subdom.example.com 999.888.777.666
```

Now you have to instruct the provider of your domain name example.com to delegate subdom.example.com to your new name server. In the zone file of example.com (with a "glue record" of ns.subdom.example.com) it should look this way:
```
subdom.example.com.          86400    IN NS   ns.subdom.example.com
ns.subdom.example.com.       86400    IN A    999.888.777.666
```

### 3. Install certbot-local-dns hook

Download the script and make it executable:
```
curl -o /etc/letsencrypt/certbot-local-dns-auth.sh https://raw.githubusercontent.com/hatzfeld/certbot-local-dns/master/certbot-local-dns-auth.sh
chmod 755 /etc/letsencrypt/certbot-local-dns-auth.sh
```

Use an editor to modify (at least) the values of ZONEFILE and DNSRELOADCMD in the configuration section, e.g. by
```
nano /etc/letsencrypt/certbot-local-dns-auth.sh
```

### 4. Test the hook

If after calling
```
/etc/letsencrypt/certbot-local-dns-auth.sh
```
the zone file contains the serial number increased by 1 and a (last) line starting with \_acme-challenge, the hook seems to work.

To test the domain name system, call
```
host -t TXT _acme-challenge.subdom.example.com
```
This should show the descriptive text of the TXT record in the master zone file.

### 5. Obtain the first certificate

Use this command, substituting subdom.example.com by your (sub-)domain
```
certbot certonly --server https://acme-v02.api.letsencrypt.org/directory \
  --manual --manual-auth-hook /etc/letsencrypt/certbot-local-dns-auth.sh \
  --manual-cleanup-hook "/etc/letsencrypt/certbot-local-dns-auth.sh cleanup" \
  --manual-public-ip-logging-ok --preferred-challenges dns --debug-challenges \
  -d subdom.example.com -d '*.subdom.example.com'
```

Be patient when running this command; some steps may need a few minutes which may pass without giving any message.

If no errors occur, you will find (soft links to) your certificates in /etc/letsencrypt/live/subdom.example.com.

### 6. Renew the certificate

The certificates expire after (about) 90 days. To renew them it is sufficient to run
```
certbot renew
```
