#!/bin/bash

function create_bridge {
	BR_NAME=$1
	BR_IP=$2

	ip link add $BR_NAME type bridge
	ip addr add $BR_IP dev $BR_NAME
	ip link set $BR_NAME up
}

function create_netcontainer {
	CNT_NAME=$1
	CNT_IP=$2
	BR_NAME=$3
	HOST_IFACE="${CNT_NAME}_host"
	CNT_IFACE="${CNT_NAME}_cnt"
   
    # Create veth iface pair and connect host part to bridge
   	ip netns add $CNT_NAME
 	ip link add name $HOST_IFACE type veth peer name $CNT_IFACE
 	ip link set $CNT_IFACE netns $CNT_NAME
    ip link set $HOST_IFACE set master $BR_NAME
	ip link set $HOST_IFACE up

	# Condifure network in the container
    ip netns exec $CNT_NAME ip addr add 127.0.0.1/8 dev lo
    ip netns exec $CNT_NAM1 ip link set lo up
    ip netns exec $CNT_NAM1 ip addr add $CNT_IP dev $CNT_IFACE
    ip netns exec $CNT_NAM1 ip link set $CNT_IFACE up
}


