#!/bin/bash

# /path/to/set.sh

echo "Creating 3proxy configuration file..."
sudo tee /usr/local/etc/3proxy/3proxy.cfg >/dev/null <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush

# Add your allowed private IP addresses here
allow 192.168.1.1
allow 10.0.0.1

$(awk -F "/" '{print "allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' /home/cloudfly/data.txt)
EOF
echo "3proxy configuration file created successfully."

echo "Creating rotation script..."
sudo tee /usr/local/etc/3proxy/rotate_proxy.sh >/dev/null <<EOF
#!/bin/bash
IP4=\$(curl -4 -s icanhazip.com)
for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
    IPV6=\$(head -n \$i /path/to/your/ipv6.txt | tail -n 1)
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h\$IP4 -e\$IPV6 -p\$i
done
EOF
sudo chmod +x /usr/local/etc/3proxy/rotate_proxy.sh
echo "Rotation script created successfully."

echo "Proxy Manager setup complete."
