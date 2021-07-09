# Dockerized KDBX

This app will let you run a safe dockerized environment to host an existing or new KDBX database on your own system.

**Quickstart**

```bash
sudo rm dkdbx-latest.sh &> /dev/null; wget https://gist.githubusercontent.com/daveschafer/213a4ca8d4046aaafde77f5becfd0942/raw/de5f18e0c3bca71dc53245418a55bf7afbc63504/dkdbx-latest.sh && sudo bash dkdbx-latest.sh
```

**Alternative start**

```
git clone https://github.com/daveschafer/dockerized-kdbx.git
cd dockerized-kdbx
#edit app.config and edit
sudo chmod +x create-dockerized-kdbx.sh
sudo ./create-dockerized-kdbx.sh
```

## Preparations

### Environment

Before starting the script, make sure you have these tools installed on your favorite linux flavored OS:

| Software       | Source                                     |
| -------------- | ------------------------------------------ |
| Docker         | <https://docs.docker.com/get-docker/>      |
| Docker-Compose | <https://docs.docker.com/compose/install/> |

This solution was tested with:

| Component      | Version      |
| -------------- | ------------ |
| OS             | Ubuntu 20.04 |
| Docker         | 19.03        |
| Docker-Compose | 1.25         |

### app.config

First of all you want to edit the `app.config` to fit your needs.  
At least the following parameters must be adjusted:

```
domains --> the domainname for your Let's Encrypt certificate
email --> the mail address which will be registered at Let's Encrypt
F2B_TZ --> your servers timezone (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
kdbx_file_path --> path to your existing KDBX files if any. (or copy your .kdbx to the default dir)
```

### Public DNS and Portforwarding

In order for Let's Encrypts ACME process to issue a certificate, the following must be configured:

- DNS which can be one of these
  - A public DNS A Record, pointing to your public IP-Address
  - A Dynamic DNS binded on your router
- A Portforwarding of Port 80 and 443 to your Webservers internal IP

## Usage of Containers

The following containers were used to create this solution

| Function             | Image      | Source                                           |
| -------------------- | ---------- | ------------------------------------------------ |
| Webserver            | NGINX      | <https://hub.docker.com/_/nginx>                 |
| Intrusion Prevention | Fail2Ban   | <https://hub.docker.com/r/crazymax/fail2ban>     |
| ACME Client          | Certbot    | <https://hub.docker.com/r/certbot/certbot>       |
| Container Updates    | Watchtower | <https://hub.docker.com/r/containrrr/watchtower> |
| KeePass CLI          | kpcli      | own implementation under `/kpcli`                |

## Changelog

[CHANGELOG.MD](CHANGELOG.MD)
