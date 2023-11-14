#!/usr/bin/bash

gen_ipv6_64() {
    rm ipv6.txt
    count_ipv6=1
    while [ "$count_ipv6" -le $MAXCOUNT ]
    do
        array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
        ip64() {
            echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        }
        echo $IP6:$(ip64):$(ip64):$(ip64):$(ip64) >> ipv6.txt
        let "count_ipv6 += 1"
    done
}

install_3proxy() {
    echo "Installing 3proxy..."
    sudo yum install gcc make nano git -y
    git clone https://github.com/z3apa3a/3proxy
    cd 3proxy
    ln -s Makefile.Linux Makefile
    make
    sudo make install
    systemctl daemon-reload
    echo "* hard nofile 999999" >>  /etc/security/limits.conf
    echo "* soft nofile 999999" >>  /etc/security/limits.conf
    systemctl stop firewalld
    systemctl disable firewalld
    ulimit -n 65535
    chkconfig 3proxy on
    cd ~
}

gen_3proxy_cfg() {
    echo daemon
    echo maxconn 3000
    echo nserver 1.1.1.1
    echo nserver [2606:4700:4700::1111]
    echo nserver [2606:4700:4700::1001]
    echo nserver [2001:4860:4860::8888]
    echo nscache 65536
    echo timeouts 1 5 30 60 180 1800 15 60
    echo setgid 65535
    echo setuid 65535
    echo stacksize 6291456
    echo flush
    echo auth none

    port=$START_PORT
    while read ip; do
        echo "proxy -6 -n -a -p$port -i$IP4 -e$ip"
        ((port+=1))
    done < ipv6.txt
}

gen_ifconfig() {
    while read line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < ipv6.txt
}

export_txt(){
    port=$START_PORT
    for ((i=1; i<=$MAXCOUNT; i++)); do
        echo "$IP4:$port"
        ((port+=1))
    done
}

rotate_proxy() {
    service 3proxy restart
    echo "Rotated proxies at $(date)"
}

auto_rotate() {
    (crontab -l ; echo "*/10 * * * * ~/rotate_3proxy.sh") | crontab -
    echo "Added cron job to rotate proxies every 10 minutes."
}

echo "Installing apps..."
yum -y install gcc net-tools bsdtar zip psmisc >/dev/null

install_3proxy

IP4=$(curl ifconfig.me)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
IFCFG=$(ip route get 2001:4860:4860::8888 | awk -- '{printf $5}')
START_PORT=14000
MAXCOUNT={MAXCOUNT}

gen_ipv6_64
gen_3proxy_cfg > /etc/3proxy/3proxy.cfg

cat >> /etc/rc.local <<EOF
bash ~/boot_ifconfig.sh
service 3proxy start
EOF

auto_rotate

echo "Script execution completed successfully!"
