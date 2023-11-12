#!/usr/local/bin/bash

gen_iptables() {
    systemctl mask firewalld
    systemctl enable iptables
    systemctl stop firewalld
    yum install iptables-services -y
    systemctl enable iptables
    systemctl start iptables
    systemctl enable ip6tables
    systemctl start ip6tables
    echo "Thiết lập tường lửa...."
}

iptables -I INPUT -p tcp -s {IP} -j ACCEPT
echo "Thiết lập quyền truy cập cho {IP}"
echo "ip.sh done"

gen_ipv6_64() {
    rm $WORKDIR/ipv6.txt
    count_ipv6=1
    while [ $count_ipv6 -le 10 ]; do
        # Your logic to generate IPv6 addresses goes here
        echo "generated_ipv6_address_$count_ipv6" >> $WORKDIR/ipv6.txt
        ((count_ipv6+=1))
    done
}

gen_iptables
gen_ipv6_64
