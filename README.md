# certbot-local-dns
certbot acme authentication hook for a local domain name server

## Short description

This project is a single bash script certbot-local-dns-auth.sh usable as hook by EFF's acme client "certbot" for authentication via dns challenge. It makes it easy to obtain wildcard certificates from letsencrypt. Its limit and its advantage is the usage of a domain name server running on the same host as certbot.

After editing the configuration section of the script it can be used by certbot in this way:
```
certbot certonly [...] --manual \
   --manual-auth-hook [path/]certbot-local-dns-auth.sh \
   --manual-cleanup-hook "[path/]certbot-local-dns-auth.sh cleanup" [...]
```
If the name server is limited to serve the subdomain \_acme-challenge of your domain, it is possible to deactivate it when certbot is not running. In this case certbot is invoked in this way:
```
certbot certonly [...] --manual \
   --manual-auth-hook "[path/]certbot-local-dns-auth.sh start" \
   --manual-cleanup-hook "[path/]certbot-local-dns-auth.sh stop" [...]
```
After a successful run the normal renewal invocation of certbot will renew the wildcard certificate without human intervention.

If additional actions have to take place after each renewal of the certificate(s) you may add a hook to the invocation of renew:
```
certbot renew --renew-hook '/etc/letsencrypt/certbot-renew-hook.sh'
```

## Long description

*Note: Wherever example.com is mentioned in this README, you have to substitute it by your own domain.
Wherever 999.888.777.666 is mentioned, it has to be substituted by the external IP of your server.*

### Why this script?

Letsencrypt has become quite popular to obtain SSL certificates for single (sub-)domains. It is a bit more complicated to obtain a wildcard certificate (e.g. \*.example.com or \*.subdom.example.com), since letsencrypt will deliver such certificates only on the base of a dns authentication. If a DNS providers does not offer an API which allows such a modification, a solution may be to delegate a subdomain to a name server on a host under your control.

### What does certbot-local-dns-auth.sh?

certbot used with dns challenges makes it necessary to change certain DNS records in a specific way while certbot is running. The hook certbot-local-dns-auth.sh will apply these changes to a local master zone file. Thus it needs a domain name server running on the local host.

The script is prepared for the name server **yadifa**, but may as well be used for other nameservers which support the common zone file syntax.

### Installation

#### 1. Install certbot 
Use the package provider of your system (e.g. **apt install letsencrypt** or **apt install certbot**) and/or the instructions at https://certbot.eff.org.

#### 2. Install and configure DNS
Follow the instructions of the domain name server you have installed or want to install. The author of this script used yadifad in the configuration of his Ubuntu 18.04 (**apt install yadifa**, config file: /etc/yadifa/yadifad.conf).

Special attention is needed to create the master zone file. There are two scenarios:

##### Scenario A

The master zone file describes the zone \_acme-challenge.subdom.example.com. In this way you will obtain certificates for the domains \*.subdom.example.com.

If you want to get certificates valid for all subdomains \*.example.com, the master zone must describe the zone \_acme-challenge.example.com. In this case drop just "subdom." in the following example:

```
$TTL    86400   ; 24 hours
$ORIGIN _acme-challenge.subdom.example.com.
_acme-challenge.subdom.example.com. 86400   IN  SOA ns._acme-challenge.subdom.example.com.  webmaster.example.com. (
                                                1               ; serial EDITED BY ACME HOOK
                                                3600            ; refresh
                                                1800            ; retry
                                                3600000         ; expire
                                                10              ; minimum ttl
                                                )
_acme-challenge.subdom.example.com.  1800   IN  A           999.888.777.666
_acme-challenge.subdom.example.com.  1800   IN  NS          ns._acme-challenge.subdom.example.com.
ns                                   1800   IN  A           999.888.777.666
```
An advantage of scenario A is: The name server is used only to obtain the certificate and may be shutdown afterwards - until the time has come to renew the certificate.


##### Scenario B

The master zone file describes the zone subdom.example.com. In this way you will obtain certificates for \*.subdom.example.com, and the zone file should start more or less like this:
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
An advantage of scenario B is: You may easily add or modify subdomains \*.subdom.example.com by editing this zone file (and making the name server reload it).

##### For both scenarios

The number 999.888.777.666 has to be substituted by the external IP of your server (in case you do not know it, try ```/sbin/ifconfig``` and look for "inet").

For the script to work it is important to have the serial number in a row for itself, commented by "; serial EDITED BY ACME HOOK" as shown above. Please also note the low value of minimum ttl. Remember to put always a dot behind any top level domain to prevent $ORIGIN to be appended.

Finally start the nameserver. In case of yadifa on Ubuntu this is done by ```systemctl start yadifa.service```.

To look whether port 53 (DNS) is really served by your name server, you may call ```lsof -Pi | grep :53```.

If a local resolver is blocking the internal (i.e. localhost) port 53 (as in my case), you may either substitute the internal resolver by your newly installed name server or limit the name server to serve port 53 only for external access (e.g. in yadifa's config file by "listen 999.888.777.666:53" instead of "listen :53").

To test the name server, you may call e.g. ```host subdom.example.com 999.888.777.666```

Now you have to instruct the provider of your domain name example.com to delegate a subdomain to your new name server:

##### For scenario A

In your dns provider's zone file of example.com you will need a "glue record" for the nameserver of your zone \_acme-challenge.subdom.example.com. Thus the necessary entries should look this way:
```
_acme-challenge.subdom.example.com.          86400    IN NS   ns._acme-challenge.subdom.example.com
ns._acme-challenge.subdom.example.com.       86400    IN A    999.888.777.666
```

resp.

```
_acme-challenge.example.com.          86400    IN NS   ns._acme-challenge.example.com
ns._acme-challenge.example.com.       86400    IN A    999.888.777.666
```

##### For scenario B

In your dns provider's zone file of example.com (with a "glue record" of ns.subdom.example.com) it should look this way:
```
subdom.example.com.          86400    IN NS   ns.subdom.example.com
ns.subdom.example.com.       86400    IN A    999.888.777.666
```

Remember that the A (and AAAA) records of your subdomains \*.subdom.example.com must not be defined here, but in the master zone file of your new nameserver. If all your subdomains will be served on the same host, it may be sufficient to add:
```
*.subdom.example.com.      1800   IN  A           999.888.777.666
```

#### 3. Install certbot-local-dns hook

Download the script and make it executable:
```
curl -o /etc/letsencrypt/certbot-local-dns-auth.sh \
        https://raw.githubusercontent.com/hatzfeld/certbot-local-dns/master/certbot-local-dns-auth.sh
chmod 755 /etc/letsencrypt/certbot-local-dns-auth.sh
```

Use an editor to make eventually necessary modifications in the configuration section, e.g. by ```nano /etc/letsencrypt/certbot-local-dns-auth.sh```.

#### 4. Test the hook

If after calling
```
CERTBOT_DOMAIN=subdom.example.com /etc/letsencrypt/certbot-local-dns-auth.sh
```
the zone file contains the serial number increased by 1 and a (last) line starting with \_acme-challenge, the hook seems to work.

To test the domain name system, call
```
host -t TXT _acme-challenge.subdom.example.com
```
This should show the descriptive text of the TXT record in the master zone file. Keep in mind that the changes made in your domain name provider's zone file will need some time to propagate.

### Usage

Use this command, substituting subdom.example.com by your (sub-)domain:
```
certbot certonly --server https://acme-v02.api.letsencrypt.org/directory \
  --manual --manual-auth-hook /etc/letsencrypt/certbot-local-dns-auth.sh \
  --manual-cleanup-hook "/etc/letsencrypt/certbot-local-dns-auth.sh cleanup" \
  --manual-public-ip-logging-ok --preferred-challenges dns --debug-challenges \
  -d subdom.example.com -d '*.subdom.example.com'
```

With scenario B (see above) it is possible to start the nameserver with the invocation of certbot and to shut it down afterwards. If you wish to use this possibility, check the configuration section of the script for necessary changes and use this modified command to run certbot:
```
certbot certonly --server https://acme-v02.api.letsencrypt.org/directory \
  --manual --manual-auth-hook "/etc/letsencrypt/certbot-local-dns-auth.sh start" \
  --manual-cleanup-hook "/etc/letsencrypt/certbot-local-dns-auth.sh stop" \
  --manual-public-ip-logging-ok --preferred-challenges dns --debug-challenges \
  -d subdom.example.com -d '*.subdom.example.com'
```

Be patient when running on of these commands; some steps may need a few minutes which may pass without giving any message.

If no errors occur, you will find (soft links to) your certificates in /etc/letsencrypt/live/subdom.example.com. If the certificate file will be used on the local host, it is a good option to write the paths to these softlinks into the config files of your server software (e.g. apache). Do not use the filenames the softlinks point to; these may change with renewals.

The certificates expire after (about) 90 days. To **renew** them it is sufficient to run ```certbot renew```. To test this manually before the certificates are about to expire, use ```certbot renew --dry-run```. 

### Unattended use

Some distributions (e.g. Ubuntu) have an active systemd-timer which will initiate certificate renewal automatically. You can look for such an active time by calling ```systemctl list-timers | grep certbot```.

Alternativly automatic renewal is possible by creating a call in root's crontab (for more informations see ```man crontab```):
```
39 5 * * 1 certbot renew
```

If you have to restart a service when a certificate has been renewed this way, you may use certbot with ```--renew-hook```. To do this in a cron job e.g. for apache and postfix, put a line similar to this into the crontab:
```
39 5 * * 1 certbot renew --renew-hook 'systemctl restart apache2.service' --renew-hook 'systemctl restart postfix.service'
```
If more complicated actions have to be done after the renewal of any certificates you will prefer to use an own script:
```
39 5 * * 1 certbot renew --renew-hook '/etc/letsencrypt/certbot-renew-hook.sh'
```
You will find the stub of a script file certbot-renew-hook.sh.sh in this project.

If you are an experienced user, you can change some renewal parameters by editing your domain file in /etc/letsencrypt/renewal. But be careful, since you may break the renewal process!
