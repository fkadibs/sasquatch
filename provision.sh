#!/bin/bash
# Usage: ./provision.sh [http,dns] <c2domain> <c2_tailscale_ip:port>
# Example: ./provision.sh [http,dns] example.org 100.20.4.142:443

if [[ $# -ne 3 ]]; then
    echo "Usage: ./provision.sh [http,dns] <c2domain> <c2_ip:port>" >&2
    echo "Example: ./provision.sh http example.org 100.20.4.142:443" >&2
    exit 2
fi

domain=$2
c2=$3

NORMAL=`echo "\033[m"`
BRED=`printf "\e[1;31m"`
BGREEN=`printf "\e[1;32m"`
BYELLOW=`printf "\e[1;33m"`
COLUMNS=12


show_action() {
  printf "\n${BGREEN}[+]${NORMAL} $1\n"
}

show_warning() {
  printf "\n${BYELLOW}[!]${NORMAL} $1\n"
}

show_error() {
  printf "\n${BRED}[!] $1${NORMAL}\n"
}

error_exit() {
  echo -e "\n$1\n" 1>&2
  exit 1
}

check_errors() {
  if [ $? -ne 0 ]; then
    show_error "An error occurred!"
    error_exit "Exiting..."
  fi
}

if [ "$EUID" -ne 0 ]; then
  show_error "Please run as root"
  exit 1
fi

install_http() {
  apt-get install -y caddy tailscale fail2ban libnss3-tools
  check_errors

  show_action "Configuring Caddy..."

  # move our static content
  mkdir -p /var/www/html/static/js
  cp sites/index.html /var/www/html/index.html
  cp sites/jquery-*.js /var/www/html/static/js

  # copy our config files
  cp config/caddy/ua_deny.config /etc/caddy/ua_deny.config
  cp config/caddy/ip_deny.config /etc/caddy/ip_deny.config

  # backup our original I guess?
  mv /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak
  cp config/caddy/Caddyfile /etc/caddy/Caddyfile
  sed -i "s/c2_domain/${domain}/" /etc/caddy/Caddyfile
  sed -i "s/c2_ip_port/${c2}/" /etc/caddy/Caddyfile
  check_errors

  # load the new caddy config/generate certs
  show_action "Starting Caddy..."
  systemctl reload caddy
  check_errors

  show_action "Configuring fail2ban..."
  # backup original I guess?
  cp -rf /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak
  check_errors

  # add regex for our denies/errors
  cp config/fail2ban/caddy-4xx.conf /etc/fail2ban/filter.d/caddy-4xx.conf
  check_errors

  # add rules for jail
  cat config/fail2ban/jail.local >> /etc/fail2ban/jail.local
  check_errors
}

install_dns() {
  apt-get install -y tailscale screen
  check_errors

  show_action "Configuring CoreDNS..."
  # download from github releases for now
  wget https://github.com/coredns/coredns/releases/download/v1.8.6/coredns_1.8.6_linux_amd64.tgz
  check_errors

  # extract to directory
  tar -xzf coredns_1.8.6_linux_amd64.tgz 
  check_errors

  # avoid detection by forwarding non-C2 requests to real DNS server
  mv config/coredns/Corefile .
  sed -i "s/c2_domain/${domain}/" ./Corefile
  sed -i "s/c2_ip_port/${c2}/" ./Corefile
  check_errors

  # disabling systemd binding to port 53
  systemctl disable systemd-resolved
  systemctl stop systemd-resolved
  check_errors

  mv /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
  cp config/coredns/resolved.conf /etc/systemd/resolved.conf
  check_errors

  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  check_errors

  show_action "Starting CoreDNS..."
  screen -d -m ./coredns
  check_errors
}


show_action "Installing dependencies..."
apt-get update
apt-get upgrade -y
check_errors

apt-get install -y inetutils-ping net-tools dnsutils curl debian-keyring debian-archive-keyring 
check_errors

if [ "$1" == "http" ]; then
    # caddy
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    check_errors
fi

# tailscale
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list
check_errors

show_action "Updating apt-get packages..."
apt-get update
check_errors


show_action "Blocking Shodan..."
iptables -A INPUT -s 104.131.0.69,104.236.198.48,155.94.222.12,155.94.254.133,155.94.254.143,162.159.244.38,185.181.102.18,188.138.9.50,198.20.69.74,198.20.69.98,198.20.70.114,198.20.87.98,198.20.99.130,208.180.20.97,209.126.110.38,216.117.2.180,66.240.192.138,66.240.219.146,66.240.236.119,71.6.135.131,71.6.146.185,71.6.158.166,71.6.165.200,71.6.167.142,82.221.105.6,82.221.105.7,85.25.103.50,85.25.43.94,93.120.27.62,98.143.148.107,98.143.148.135 -j DROP
iptables-save > /etc/iptables.conf
check_errors


show_action "Installing tools..."
if [ "$1" == "http" ]; then
  install_http
else
  install_dns
fi


show_action "Configuring Tailscale..."
# enable/start the tailscale daemon
systemctl enable tailscaled
systemctl start tailscaled
check_errors

# connect tailscale to network
show_action "Starting Tailscale..."
tailscale up
check_errors

show_action "Cleaning up..."
apt-get autoremove -y
check_errors

show_action "Complete!"
