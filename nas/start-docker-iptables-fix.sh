#!/bin/sh
# Append this block to the END of your Docker startup script (e.g. start-docker.sh),
# AFTER the line that starts dockerd — not before.
#
# Why: dockerd resets the iptables FORWARD chain's default policy to DROP every
# time it starts, and only opens up exactly what Docker itself needs. If you also
# run a VPN server (e.g. Synology VPN Server) on the same box with "allow clients
# to access the LAN" enabled, that VPN traffic gets silently dropped by Docker's
# policy unless you explicitly re-allow it here. Adjust the subnet to match your
# VPN's client subnet.

sleep 5
iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -I FORWARD -d 10.8.0.0/24 -j ACCEPT
