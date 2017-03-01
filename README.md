# netcontainer
Script to simplify network namespaces management

# Work by hand 

Root privilages needed for all configuration commands

## Set up bridge

    ip link add net_bringe0 type bridge
    ip addr add 10.10.1.1/24 dev net_bringe0
    ip link set net_bringe0 up

## Create namespace with interface
    
    ip netns add 1
    ip link add name if0 type veth peer name if1
    ip link set if1 netns 1
    ip link set if0 master net_bringe0
    ip link set if0 up
    
## Configure network in container


    ip netns exec 1 ip addr add 127.0.0.1/8 dev lo
    ip netns exec 1 ip link set lo up
    ip netns exec 1 ip addr add 10.10.1.2/24 dev if1
    ip netns exec 1 ip link set if1 up
    
## Check it!

    # ip addr
    <...>
    12: net_bringe0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether c6:0d:e3:b9:ef:f0 brd ff:ff:ff:ff:ff:ff
        inet 10.10.1.1/24 scope global net_bringe0
           valid_lft forever preferred_lft forever
        inet6 fe80::a03d:3bff:fe9b:8c3a/64 scope link 
           valid_lft forever preferred_lft forever
    19: if0@if18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master net_bringe0 state UP group default qlen 1000
        link/ether c6:0d:e3:b9:ef:f0 brd ff:ff:ff:ff:ff:ff link-netnsid 0
        inet6 fe80::c40d:e3ff:feb9:eff0/64 scope link 
           valid_lft forever preferred_lft forever

    # ip netns exec 1 ip addr 
    1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    18: if1@if19: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether c6:dc:74:25:80:c0 brd ff:ff:ff:ff:ff:ff link-netnsid 0
        inet 10.10.1.2/24 scope global if1
           valid_lft forever preferred_lft forever
        inet6 fe80::c4dc:74ff:fe25:80c0/64 scope link 
           valid_lft forever preferred_lft forever


    # ping 10.10.1.2
    PING 10.10.1.2 (10.10.1.2) 56(84) bytes of data.
    64 bytes from 10.10.1.2: icmp_seq=1 ttl=64 time=0.059 ms
    64 bytes from 10.10.1.2: icmp_seq=2 ttl=64 time=0.048 ms
    ^C
    --- 10.10.1.2 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1036ms
    rtt min/avg/max/mdev = 0.048/0.053/0.059/0.009 ms
 
    # ip netns exec 1 ping 10.10.1.1
    PING 10.10.1.1 (10.10.1.1) 56(84) bytes of data.
    64 bytes from 10.10.1.1: icmp_seq=1 ttl=64 time=0.043 ms
    64 bytes from 10.10.1.1: icmp_seq=2 ttl=64 time=0.055 ms
    64 bytes from 10.10.1.1: icmp_seq=3 ttl=64 time=0.050 ms
    ^C
    --- 10.10.1.1 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2063ms
    rtt min/avg/max/mdev = 0.043/0.049/0.055/0.007 ms

