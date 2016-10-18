#!/bin/sh

set -e

# name of the virtual interface
IFACE=resharewl

# ip address of the internal network
# do not forget to set up your dhcp server accordingly
internalip=192.168.56.1

rfkill unblock wlan
sleep 1
rfkill unblock wlan
sleep 1
killall udhcpd || true
killall hostapd || true

iw dev $IFACE del || true
iw dev wlan0 interface add $IFACE type station

ap=`iw dev wlan0 link|grep 'Connected to' |cut -d ' ' -f 3`
echo '***' AP  $ap
[ -z $ap ] && exit 1

channel=`iw dev wlan0 scan|grep -A 36 -i $ap|grep 'primary channel'|cut -d : -f 2`
echo '***' AP $ap channel $channel
[ -z $channel ] && exit 1

cat /root/hostapd-reshare.template.conf | sed -e "s/@@@CHANNEL@@@/$channel/g" > /tmp/hostapd-reshare.conf

iw wlan0 set power_save on

macchanger -e $IFACE
# if you do not have macchanger instsalled, 
# you can set the (virtual iface) MAC address manualy here
#ip link set dev $IFACE  address 00:11:22:33:44:55

INETIP=`ifdata  -pa wlan0`
ifconfig $IFACE down
sleep 1
hostapd /tmp/hostapd-reshare.conf &
sleep 2
ifconfig $IFACE up
ifconfig $IFACE $internalip
sleep 2
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

sleep 2
udhcpd -S /etc/udhcpd-resharewl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
