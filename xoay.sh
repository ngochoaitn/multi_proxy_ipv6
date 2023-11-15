#!/bin/bash

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

gen64() {
    ip64() {
        tr </dev/urandom -dc A-Fa-f0-9 | head -c4
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing 3proxy"
    URL="https://raw.githubusercontent.com/ngochoaitn/multi_proxy_ipv6/main/3proxy-3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xzf- -C /usr/local/etc/3proxy --strip-components=1
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
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
$(awk -F "/" '{print "users " $1 ":CL:" $2}' ${WORKDATA})
$(awk -F "/" '{print "auth strong\nallow " $1 "\nproxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\nflush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)
    echo "Proxy is ready! Download from: ${URL}, Password: ${PASS}"
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | xargs -I {} echo "usr$(random)/pass$(random)/$IP4/{}/$(gen64 $IP6)"
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA}
}

rotate_proxy_script() {
    echo "#!/bin/bash" > rotate_3proxy.sh
    echo "service 3proxy restart" >> rotate_3proxy.sh
    chmod +x rotate_3proxy.sh
}

# Automate proxy rotation every 10 minutes
(crontab -l ; echo "*/10 * * * * ${WORKDIR}/rotate_3proxy.sh") | crontab -

echo "Installing required packages"
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR || exit

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External subnet for IP6 = ${IP6}"

echo "Bạn muốn tạo bao nhiêu proxy? Ví dụ 5000"
read COUNT

FIRST_PORT=10000
LAST_PORT=$((FIRST_PORT + COUNT))

gen_data > data.txt
gen_iptables > boot_iptables.sh
gen_ifconfig > boot_ifconfig.sh
rotate_proxy_script

chmod +x boot_*.sh /etc/rc.local

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

bash /etc/rc.local

gen_proxy_file_for_user
upload_proxy
