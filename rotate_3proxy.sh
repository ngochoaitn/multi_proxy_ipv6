#!/bin/bash

# Function to generate a random string
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Array for generating IPv6 address
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Function to generate an IPv6 address with random values
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to install 3proxy
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

# Function to generate 3proxy configuration
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

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Function to generate proxy file for user
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Function to upload proxy configuration
upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)

    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
    echo "Password: ${PASS}"
}

# Function to generate data for proxies
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Function to generate ifconfig commands
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

# Function to rotate proxies and restart 3proxy service
rotate_proxy() {
    echo "Rotating proxies..."
    service 3proxy restart
}

# Set up automatic rotation in crontab
(crontab -l ; echo "*/10 * * * * ${WORKDIR}/rotate_proxy") | crontab -

echo "Installing required packages..."
yum -y install gcc net-tools bsdtar zip >/dev/null

# Set working folder
WORKDIR="/home/proxy-installer"
mkdir $WORKDIR && cd $_

# Get external IPv4 and IPv6 addresses
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External subnet for IPv6 = ${IP6}"

# Get the number of proxies to create
echo "How many proxies do you want to create? Example: 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

# Generate data for proxies
gen_data >$WORKDIR/data.txt

# Generate iptables rules
gen_iptables >$WORKDIR/boot_iptables.sh

# Generate ifconfig commands
gen_ifconfig >$WORKDIR/boot_ifconfig.sh

chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

# Generate 3proxy configuration
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Add commands to rc.local for startup
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

# Run rc.local
bash /etc/rc.local

# Generate proxy file for user
gen_proxy_file_for_user

# Upload proxy configuration
upload_proxy
