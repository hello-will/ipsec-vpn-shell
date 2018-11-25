#!/bin/sh

VPN_SERVER_IP='你的VPN服务IP'
VPN_IPSEC_PSK='你的IPSEC共享密钥'
VPN_USER='你的用户名'
VPN_PASSWORD='你的密码'

do_init ()
{
    if [ ! -f "/etc/ipsec.conf.bak" ]
    then
        cp /etc/ipsec.conf /etc/ipsec.conf.bak
    fi

    if [ ! -f "/etc/ipsec.secrets.bak" ]
    then
        cp /etc/ipsec.secrets /etc/ipsec.secrets.bak
    fi

    if [ ! -f "/etc/xl2tpd/xl2tpd.conf.bak" ]
    then
        cp /etc/xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf.bak
    fi

    if [ ! -f "/etc/ppp/options.l2tpd.client.bak" ]
    then
        if [ ! -f "/etc/ppp/options.l2tpd.client" ]
        then
            touch /etc/ppp/options.l2tpd.client
        fi
        cp /etc/ppp/options.l2tpd.client /etc/ppp/options.l2tpd.client.bak
    fi

    cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

# basic configuration

config setup
  # strictcrlpolicy=yes
  # uniqueids = no

# Add connections here.

# Sample VPN connections

conn %default
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  keyexchange=ikev1
  authby=secret
  ike=aes256-sha1-modp2048,aes128-sha1-modp2048!
  esp=aes256-sha1-modp2048,aes128-sha1-modp2048!

conn myvpn
  keyexchange=ikev1
  left=%defaultroute
  auto=add
  authby=secret
  type=transport
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
EOF

    cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF
    chmod 600 /etc/ipsec.secrets

    cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac myvpn]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

    cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name $VPN_USER
password $VPN_PASSWORD
EOF
    chmod 600 /etc/ppp/options.l2tpd.client

    # Create xl2tpd control file
    mkdir -p /var/run/xl2tpd
    touch /var/run/xl2tpd/l2tp-control

    # Restart services
    service strongswan restart
    service xl2tpd restart
    sleep 1

    # Start the IPsec connection
    ipsec up myvpn

    # Start the L2TP connection
    echo "c myvpn" > /var/run/xl2tpd/l2tp-control

    # Check a new interface ppp0
    for i in $(seq 1 5)
    do
        PPP0_EXIST=`ifconfig |grep ppp0 | awk '{print $1}'`
        if [ "$PPP0_EXIST" = "ppp0:" ]
        then
            echo "VPN Initialized!"
            return
        else
            echo "Wait a new interface ppp0"
            sleep 3
        fi
    done
    echo "VPN Initialize Failed!"
}

do_start ()
{
    MY_ROUTE_IP=`ip route |grep default -m 1| awk '{print $3}'`

    # Exclude your VPN server's IP from the new default route
    route add $VPN_SERVER_IP gw $MY_ROUTE_IP

    # Add a new default route to start routing traffic via the VPN server
    route add default dev ppp0

    # The VPN connection is now complete. Verify that your traffic is being routed properly
    MY_SERVER_IP=`wget -qO- http://ipv4.icanhazip.com`
    if [ "$VPN_SERVER_IP" = "$MY_SERVER_IP" ]
    then
        echo "VPN Started!"
    else
        echo "VPN Start Failed!"
    fi
}

do_stop ()
{
    route del $VPN_SERVER_IP
    route del default dev ppp0
    echo "VPN Stopped!"
}

do_close ()
{
    echo "d myvpn" > /var/run/xl2tpd/l2tp-control
    for i in $(seq 1 5)
    do
        PPP0_EXIST=`ifconfig |grep ppp0 | awk '{print $1}'`
        if [ "$PPP0_EXIST" = "ppp0:" ]
        then
            echo "Wait remove interface ppp0"
            sleep 3
        else
            break
        fi
    done
    ipsec down myvpn
    echo "VPN Closed!"
}

case $1 in
    init)
        do_init
    ;;
    start)
        do_start
    ;;
    stop)
        do_stop
    ;;
    restart)
        do_stop
        do_start
    ;;
    close)
        do_close
    ;;
    *)
        echo "Usage: $0 init|start|restart|stop|close"
    ;;
esac
