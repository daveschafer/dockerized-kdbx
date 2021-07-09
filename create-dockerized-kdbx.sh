#!/bin/bash

####
## Variables
####

#Colors (note this messes up echo \n parameter)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
reset=$(tput sgr0)
#example color usage
#echo "${red}red text ${green}green text${reset}"

##
# Header
##
clear
echo "                                "
echo "_____  _  _______  ______   __  "
echo "|  __ \| |/ /  __ \|  _ \ \ / / "
echo "| |  | | ' /| |  | | |_) \ V /  "
echo "| |  | |  < | |  | |  _ < > <   "
echo "| |__| | . \| |__| | |_) / . \  "
echo "|_____/|_|\_\_____/|____/_/ \_\ "
echo "                                "
echo "${red}----------------------------------------------------------------------------------"
echo "${yellow}Disclaimer:${reset}"
echo "| Make sure your webservers Port 80 and 443 are accessible from the internet"
echo "| Make sure your 'app.config' fits your needs"
echo "| Make sure you have 'docker' and 'docker-compose' installed on your system"
echo "| If you want to integrate an existing KDBX Database, make sure it is present in 'kdbx_file_path'"
echo "${red}----------------------------------------------------------------------------------${reset}"
echo

####
## Check prerequisits
####

if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

####
## Read and Print Config File Options
###

echo "${cyan}#################################"
echo "###${green}   Loading Configuration   ${cyan}###"
echo "#################################${reset}"
echo

echo "The configuration from './app.config' will be applied."
read -p "Do you want to print the configuration? (y/n)" dec_printconfig
if [ "$dec_printconfig" == "y" ] || [ "$dec_printconfig" == "Y" ]; then
  echo "${cyan}=====================================================================${reset}"
  cat ./app.config
  echo "${cyan}=====================================================================${reset}"
  echo
fi
read -p "Make sure your configuration is complete before continuing! (enter to continue)"

####
## Cleanup Previous Environments
###

echo
echo "...cleaning up previous environment"
if test -f "$(pwd)/env/fail2ban/fail2ban.env.backup"; then
  echo "${yellow}restoring existing fail2ban.env.backup --> fail2ban.env"
  cp ./env/fail2ban/fail2ban.env.backup ./env/fail2ban/fail2ban.env
  rm ./env/fail2ban/fail2ban.env.backup
else
  echo "${yellow}creating new fail2ban.env from template"
  cp ./env/fail2ban/fail2ban.env.template ./env/fail2ban/fail2ban.env
fi
if test -f "$(pwd)/data/fail2ban-data/jail.conf.backup"; then
  echo "${yellow}restoring existing jail.conf.backup --> jail.conf"
  cp ./data/fail2ban-data/jail.conf.backup ./data/fail2ban-data/jail.conf
  rm ./data/fail2ban-data/jail.conf.backup
fi
if test -f "$(pwd)/env/nginx/nginx.conf.backup"; then
  echo "${yellow}restoring existing nginx.conf.backup --> nginx.conf${reset}"
  cp ./env/nginx/nginx.conf.backup ./env/nginx/nginx.conf
  rm ./env/nginx/nginx.conf.backup
fi

#Loading config variables
. ./app.config

####
## Check if a new empty KDBX should be created, check if at least one .kdbx file is in "kdbx_file_path" folder
####

echo
echo "${cyan}##################################"
echo "###${green}      KDBX Preparation      ${cyan}###"
echo "##################################${reset}"
echo

#count kdbx files
count_kdbxfiles=0
if test -d "$(pwd)${kdbx_file_path:1}"; then
  count_kdbxfiles=$(ls "$(pwd)${kdbx_file_path:1}" | wc -l)
  echo "${yellow}files in $kdbx_file_path: $count_kdbxfiles ${reset}"
fi
if [ "$kdbx_create_new" == true ] && [ $count_kdbxfiles -le 0 ]; then
  echo "Option to create new empty KDBX selected or no KDBX in folder '$kdbx_file_path'"
  echo "${red}Attention${reset}: An interactive terminal to create a new 'secrets.kdbx' KDBX file will be started."
  read -p "Continue (press any key)"

  echo
  echo "...creating kpcli container..."
  docker build -f ./kpcli/Dockerfile -t docker-kpcli2 . >/dev/null 2>&1
  echo "...done!"
  echo

  echo "${yellow}*****************************************************${reset}"
  echo "Save a new empty KDBX with 'saveas secrets.kdbx'"
  echo ">> enter your new master password (remember it)"
  echo "Close the process with 'quit'"
  echo "${yellow}*****************************************************${reset}"
  echo

  docker run -it --rm -v $(pwd)${kdbx_file_path:1}:/data docker-kpcli2:latest #leading "." removed with :1

  echo
  echo "...cleaning up kpcli container..."
  docker image rm docker-kpcli2:latest >/dev/null 2>&1
  echo "...done!"
  echo

  if test -d "$(pwd)${kdbx_file_path:1}"; then
    count_kdbxfiles=$(ls "$(pwd)${kdbx_file_path:1}" | wc -l)
  fi

  echo "New filecount in $kdbx_file_path: $count_kdbxfiles"

else
  echo "--------------------------------------------------------------------------------------------"
  echo "${yellow}Attention:${reset} KDBX folder '$kdbx_file_path' not empty --> copying these files:"
  ls $kdbx_file_path
  echo "--------------------------------------------------------------------------------------------"
  echo
fi

####
## Substep: Inject fail2ban options to fail2ban.env file
####

#Backup origin file to revert it after setup
cp ./env/fail2ban/fail2ban.env ./env/fail2ban/fail2ban.env.backup
cp ./data/fail2ban-data/jail.conf ./data/fail2ban-data/jail.conf.backup

sed -i "/TZ=/c\TZ=$F2B_TZ" ./env/fail2ban/fail2ban.env
sed -i "/F2B_MAX_RETRY=/c\F2B_MAX_RETRY=$F2B_MAX_RETRY" ./env/fail2ban/fail2ban.env
sed -i "/F2B_SSMTP_HOST=/c\F2B_SSMTP_HOST=$F2B_SSMTP_HOST" ./env/fail2ban/fail2ban.env
sed -i "/F2B_SSMTP_PORT=/c\F2B_SSMTP_PORT=$F2B_SSMTP_PORT" ./env/fail2ban/fail2ban.env
sed -i "/F2B_SSMTP_USER=/c\F2B_SSMTP_USER=$F2B_SSMTP_USER" ./env/fail2ban/fail2ban.env
sed -i "/F2B_SSMTP_PASSWORD=/c\F2B_SSMTP_PASSWORD=$F2B_SSMTP_PASSWORD" ./env/fail2ban/fail2ban.env
sed -i "/F2B_SSMTP_TLS=/c\F2B_SSMTP_TLS=$F2B_SSMTP_TLS" ./env/fail2ban/fail2ban.env

# Replace Bantime Options (only first match to replace the general settings, not the jail specific settings)
sed -i "0,/bantime = /c\bantime = $F2B_bantime" ./data/fail2ban-data/jail.conf
sed -i "0,/ignoreip = /c\ignoreip = $F2B_ignoreip" ./data/fail2ban-data/jail.conf
sed -i "0,/findtime = /c\findtime = $F2B_findtime" ./data/fail2ban-data/jail.conf
sed -i "0,/maxretry = /c\maxretry = $F2B_maxretry" ./data/fail2ban-data/jail.conf
sed -i "0,/action = /c\action = $F2B_ban_action" ./data/fail2ban-data/jail.conf

unset F2B_TZ F2B_MAX_RETRY F2B_SSMTP_HOST F2B_SSMTP_PORT F2B_SSMTP_USER F2B_SSMTP_PASSWORD F2B_SSMTP_TLS F2B_bantime F2B_ignoreip F2B_findtime F2B_maxretry F2B_ban_action

####
## Substep: Inject Domain Name to nginx.conf file
####

#Backup original
cp ./env/nginx/nginx.conf ./env/nginx/nginx.conf.backup

sed -i "s/sub.domain.tld/${domains}/g" ./env/nginx/nginx.conf

####
## htpasswd generator
####

echo "${cyan}###################################"
echo "###${green}      NGINX Preparation      ${cyan}###"
echo "###################################${reset}"
echo

htpass_user="user"
read -p "Enter your Webserver user:" htpass_user

htpass_pass1="init1"
htpass_pass2="init2"
while [ "$htpass_pass1" != "$htpass_pass2" ]; do
  read -p "Enter your Webserver password:" htpass_pass1
  read -p "Enter your Webserver password (again):" htpass_pass2
  if [ "$htpass_pass1" != "$htpass_pass2" ]; then
    echo "Passwords not matching!"
  fi
done

##// todo, this has to be done inside the docker container, we can do this (optional)
echo "Creating htpasswd file..."
echo
#create empty dummy htpasswd
mkdir ./env/htpasswd
touch ./env/htpasswd/htpasswd
#nginx only supports apr1... better solution has to be found
docker run --rm marcnuri/htpasswd -nbm $htpass_user $htpass_pass1 >./env/htpasswd/htpasswd
docker image rm marcnuri/htpasswd >/dev/null

echo
echo "htpasswd file created successfully..."
echo "${yellow}Note${reset}: if you lose the webserver password, you have to recreate the htpasswd file"

unset htpass_user htpass_pass1 htpass_pass2

echo
echo "${cyan}#################################"
echo "###${green} Let's Encrypt Preparation ${cyan}###"
echo "#################################${reset}"
echo

#######
## Check if LE (LetsEncrypt) is already present
#######

lealreadypresent=false
if [ -d "$le_data_path/conf/live" ]; then
  lealreadypresent=true
  echo "! There is already an LE Certificate for $domains present"
  read -p "${red}RECREATE${reset} Let's Encrypt Certificate?  (otherwise existing certificate will be used) (y = recreate/N = keep existing) " DeciscionLeRecreate
  if [ "$DeciscionLeRecreate" = "Y" ] || [ "$DeciscionLeRecreate" = "y" ]; then
    DeciscionLeRecreate="y"
    echo "${cyan}[Debug]${reset} LE Certificate will be recreated"
    echo "${yellow}[Disclaimer]${reset} Keep the Rate Limits in mind: https://letsencrypt.org/docs/rate-limits/"
  else
    echo "${cyan}[Debug]${reset} Continuing with existing certificate for ($domains)"
    DeciscionLeRecreate="n"
  fi
  echo
fi

# if LE Cert not existing or LE cert exists but option to recreate LE cert anyway then recreate LE cert
if [ "$lealreadypresent" = false ] || ([ $lealreadypresent = true ] && [ "$DeciscionLeRecreate" = "y" ]); then
  if [ $staging != "0" ]; then
    echo "${yellow}Note:${reset} LE staging mode activated, certificate renewal will be simulated"
  fi
  read -p "[Breakpoint] Let's Encrypt Certificate will be (re)created (enter to continue)"

  if [ ! -e "$le_data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$le_data_path/conf/ssl-dhparams.pem" ]; then
    echo "### Downloading recommended TLS parameters ..."
    mkdir -p "$le_data_path/conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf >"$le_data_path/conf/options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem >"$le_data_path/conf/ssl-dhparams.pem"
    echo
  fi

  echo "### Creating dummy certificate for $domains ..."
  path="/etc/letsencrypt/live/$domains"
  mkdir -p "$le_data_path/conf/live/$domains"
  docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot

  echo
  echo "### Starting nginx ..."
  docker-compose up --force-recreate -d nginx

  echo
  echo "### Deleting dummy certificate for $domains ..."
  docker-compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/$domains && \
    rm -Rf /etc/letsencrypt/archive/$domains && \
    rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot

  echo
  echo "### Requesting Let's Encrypt certificate for $domains ..."
  echo "(this could take some time the first time)"
  echo
  #Join $domains to -d args
  domain_args=""
  for domain in "${domains[@]}"; do
    domain_args="$domain_args -d $domain"
  done

  # Select appropriate email arg
  case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
  esac

  # Enable staging mode if configured
  if [ $staging != "0" ]; then
    echo "Staging mode enabled."
    staging_arg="--staging"
  fi

  #Request certificate
  docker-compose run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      $domain_args \
      --rsa-key-size $rsa_key_size \
      --agree-tos \
      --force-renewal" certbot
  echo
else
  echo "Keeping existing LE certificate, only NGINX container will be reloaded this time."
  echo
fi

echo
echo "${cyan}###############################################"
echo "###${green} Dockerized KDBX Environment Deployment  ${cyan}###"
echo "###############################################${reset}"
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload

# At the end, start the rest of the containers (certbot, watchtower, APP..)
echo
echo "### Certificate preparations complete"
echo
echo "### Starting rest of Docker containers..."
echo
docker-compose up -d
echo
echo "### All containers started!"
echo

echo -n "Want some tips for using Fail2Ban (y/n)? "
old_stty_cfg=$(stty -g)
stty raw -echo
answer=$(head -c 1)
stty $old_stty_cfg # Careful playing with stty
if echo "$answer" | grep -iq "^y"; then
  echo
  echo "${red}### Spinning up fail2ban for some 'protection' ###${reset}"
  #docker-compose -f fail2ban-docker-compose.yaml up -d
  echo
  echo "### Deployment Finished ###"
  echo
  echo "************************************************************************************"
  echo "* ${yellow}Dockerized Fail2Ban Usage Examples:${reset}                                              *"
  echo "*----------------------------------------------------------------------------------*"
  echo "*                                                                                  *"
  echo "* >show general status:                                                            *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client status                           *"
  echo "*                                                                                  *"
  echo "* >show specific jail (and banned IPs):                                            *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client status <JAIL>                    *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client status nginx-http-auth           *"
  echo "*                                                                                  *"
  echo "* >Ban IP:                                                                         *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client set <JAIL> banip <IP>            *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client set nginx-http-auth banip <IP>   *"
  echo "*                                                                                  *"
  echo "* >Unban IP:                                                                       *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client set <JAIL> unbanip <IP>          *"
  echo "* sudo docker exec -t DK-fail2ban fail2ban-client set nginx-http-auth unbanip <IP> *"
  echo "*                                                                                  *"
  echo "************************************************************************************"

else
  echo
  echo "${green}### Deployment finished without Fail2Ban tips ###${reset}"
fi

# Final Words
echo
echo "${yellow}Your KDBX database will be accessible from: 'https://$domains/name-of-your-database.kdbx'${reset}"
echo
