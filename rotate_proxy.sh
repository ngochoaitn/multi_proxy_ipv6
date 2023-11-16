#!/bin/bash

WORKDIR="/home/cloudfly"  # Update with your actual working directory
IP4=$(curl -4 -s icanhazip.com)

for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
    IPV6=$(head -n $i $WORKDIR/ipv6.txt | tail -n 1)
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
done
