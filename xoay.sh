#!/bin/sh

# Function to generate a random string
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Array for hexadecimal values
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Function to generate an IPv6 address
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
    yes | cp -f src/3proxy /usr/local/etc/3proxy/bin/
    systemctl stop 3proxy
    systemctl start 3proxy
    cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
}

# Function to configure IP whitelist for 3proxy
auth_ip_config() {
    echo "auth iponly"
    while read -r allowed_ip; do
        echo "allow $allowed_ip"
    done < allowed_ips.txt
}

# Function to generate 3proxy configuration
gen_3proxy() {
    auth_ip_config
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
$(awk -F "/" '{print "auth strong\nallow " $1 "\nproxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\nflush\n"}' ${WORKDATA})
EOF
}

# Function to upload proxy details
upload_proxy() {
    local PASS=$(random)
    echo "$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})" > proxy.txt
    URL=$(curl -s --upload-file proxy.txt https://transfer.sh/proxy.txt)
    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download proxy list from: ${URL}"
    echo "Password: ${PASS}"
}

# Function to generate data for proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    cat <<EOF
iptables -A INPUT -p tcp --dport 3128 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 1080 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -m state --state NEW -j ACCEPT
$(awk -F "/" '{print "iptables -A INPUT -p tcp --dport " $4 " -s " $3 " -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

# Function to generate ifconfig commands
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

# Function to rotate proxies
rotate_proxy() {
    echo "Rotating proxies..."
    service 3proxy restart
}

# Cron job for automatic proxy rotation every 10 minutes
(crontab -l ; echo "*/10 * * * * ${WORKDIR}/rotate_3proxy.sh") | crontab -

# Installing required packages
echo "Installing necessary packages..."
yum -y install gcc net-tools bsdtar zip >/dev/null

# Installing and configuring 3proxy
install_3proxy

# Setting up working folder
echo "Setting up working folder..."
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

# Obtaining IP addresses
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

# Asking user for the number of proxies to create
echo "How many proxies do you want to create? Example: 2000"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

# Generating data, iptables rules, ifconfig commands, 3proxy configuration
gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Configuring Squid
# (You can add your Squid configuration here)

# Adding commands to rc.local for startup
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

# Starting services
bash /etc/rc.local

# Generating proxy files for users
gen_proxy_file_for_user()

# Configuring IP whitelist for 3proxy
auth_ip_config

# Uploading proxy details
upload_proxy

ngen_iptables() {
    local source_ip="171.247.21.198"
    local destination_port="113.176.102.183"

    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp -s " $3 " --dport " $4 " -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

# Now, call the ngen_iptables function
ngen_iptables
