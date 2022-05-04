# Sasquatch

A fork of "ycsm", this project leverages Caddy and CoreDNS to redirect HTTP and DNS traffic during network penetration tests or red team operations. It performs some basic hardening with fail2ban, iptables, and pre-defined Caddy rules. Consider this a template to build upon, using Caddy's flexibility (tls, mtls, magic headers, rewrite, etc.). This also installs Tailscale to connect to backend infrastructure, but that can be easily changed to meet your needs.

**Note:** Currently under development, may contain bugs or future updates may include breaking changes. Developed and tested on Ubuntu 20.04 and Cobalt Strike 4.0+. 

# Features

* Evade vendor sandboxes
* Block Shodan access
* Block scanners and bots
* Block Tor exit nodes
* Auto SSL creation and renewal using Caddy
* X-Forwarded header inclusion
* Server hardening using iptables and fail2ban
* jQuery profiling inspired by APT29
* DNS forwarding to avoid detection
* Flexible, encrypted networking with Tailscale

# Getting Started

Clone the repository and make the script executable.

The only variables you need to provide are the type of provisioning (`http` or `dns`), the C2 domain, and C2 listener ip/port. 

```
Usage: ./provision.sh [http,dns] <domain> <ip:port>
Example: ./provision.sh http example.org 100.20.4.142:443
```

At the end of the provisioning, you will be prompted with a URL to manually authorize the server to join your Tailscale network. Once authorized, traffic will begin to reach your C2 listener.

# Customization

Sasquatch is designed to be easy to customize and expand. For instance, you may want to only forward HTTP traffic to your C2 listener if there is a pre-defined header. This is easy to implement with a `rewrite` declaration and a small change to your Cobalt Strike malleable C2 profile.

You can take things a step further and include mTLS authentication, expand the IP and User-Agent rewrite/deny lists and replace the static HTML content to serve as a decoy or recieve domain categorization.

# Logging

Sasquatch generates logs following locations:

Caddy:
* `/var/log/caddy/access.log`
* `/var/log/caddy/deny.log`

CoreDNS:
* `/var/log/coredns/dns.log`

fail2ban:
* `/var/log/fail2ban/jail.log`

# Resources

 - https://github.com/infosecn1nja/ycsm
 - https://byt3bl33d3r.substack.com/p/taking-the-pain-out-of-c2-infrastructure
 - https://labs.f-secure.com/blog/detecting-exposed-cobalt-strike-dns-redirectors/
 - https://caddyserver.com/docs/
 - https://coredns.io/manual/toc/
 - https://tailscale.com/kb/
