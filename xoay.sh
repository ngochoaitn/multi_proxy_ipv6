#!/bin/bash

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://raw.githubusercontent.com/ngochoaitn/multi_proxy_ipv6/main/3proxy-3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

auth_ip_config

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p3128 -i" $3 " -e"$5"\n" \
"proxy -6 -n -a -p1080 -i" $3 " -e"$5"\n" \
"proxy -6 -n -a -p8080 -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

auth_ip_config() {
    echo "auth iponly"
    while read -r allowed_ip; do
        echo "allow $allowed_ip"
    done < allowed_ips.txt
}

upload_proxy() {
    local PASS=$(random)
    echo "$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})" > proxy.txt
    URL=$(curl -s --upload-file proxy.txt https://transfer.sh/proxy.txt)

    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download proxy list from: ${URL}"
    echo "Password: ${PASS}"
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
iptables -A INPUT -p tcp --dport 3128 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 1080 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -m state --state NEW -j ACCEPT
EOF
    awk -F "/" '{print "iptables -A INPUT -p tcp --dport " $4 " -s " $3 " -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/16"}' ${WORKDATA})
EOF
}

rotate_proxy() {
    echo "Rotating proxies..."
    service 3proxy restart
}

auto_rotate() {
    (crontab -l ; echo "*/10 * * * * ${WORKDIR}/rotate_3proxy.sh") | crontab -
    echo "Added cron job to run the script every 10 minutes."
}

auto_restart() {
    (crontab -l ; echo "0 0 * * * ${WORKDIR}/restart_if_empty.sh") | crontab -
    echo "Added cron job to restart if data is empty."
}

echo "Installing apps..."
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "Working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External sub for IP6 = ${IP6}"

echo "How many proxies do you want to create? Example: 2000"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

bash /etc/rc.local

auth_ip_config

upload_proxy

auto_rotate

auto_restart

echo "Script execution completed successfully!"
