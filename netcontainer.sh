#!/bin/bash

#set -x

# Default parameters

# Prefix of container network
NET_PREFIX=24
# Name of bridge. Script expect that only one bridge will be used 
BRIDGE='cnt_bridge'


function is_iface_exist {
    ip link show $1 > /dev/null 2>&1
    return $?
}


function create_bridge {
	BR_NAME=$1
	BR_IP=$2
    BR_PREFIX=$3

    if is_iface_exist $BR_NAME
        then
        echo "Interface $BR_NAME exist"
        return
    fi

	ip link add $BR_NAME type bridge
	ip addr add $BR_IP/$BR_PREFIX dev $BR_NAME
	ip link set $BR_NAME up
}


function delete_bridge {
	BR_NAME=$1

    if is_iface_exist $BR_NAME
    then
        ip link del $BR_NAME 
    fi
}

function create_container {
	CNT_NAME=$1
	CNT_IP=$2
    CNT_PREFIX=$3
	BR_NAME=$4
	HOST_IFACE="${CNT_NAME}_host"
	CNT_IFACE="${CNT_NAME}_cnt"
   
    # Create veth iface pair and connect host part to bridge
   	ip netns add $CNT_NAME
 	ip link add name $HOST_IFACE type veth peer name $CNT_IFACE
 	ip link set $CNT_IFACE netns $CNT_NAME
    ip link set $HOST_IFACE master $BR_NAME
	ip link set $HOST_IFACE up

	# Condifure network in the container
    ip netns exec $CNT_NAME ip addr add 127.0.0.1/8 dev lo
    ip netns exec $CNT_NAME ip link set lo up
    ip netns exec $CNT_NAME ip addr add $CNT_IP/$CNT_PREFIX dev $CNT_IFACE
    ip netns exec $CNT_NAME ip link set $CNT_IFACE up
}


function run_command {
    CNT_NAME=$1
    shift
    ip netns exec $CNT_NAME $@
}


function print_usage {
    echo "netcontaner.sh <command> [args]"
    echo "Possible commands are:"
    echo "    create_bridge"
    echo "    delete_bridge"
    echo "    create_container"
    echo "    delete_container"
    echo "    run"
    echo "    help"
}

# Main script

# Check for root
ID=$(id -u)
if [[ "$ID" != "0" ]]
then
    echo "Root privilages needed for managing containers!"
    exit 1
fi

COMMAND=$1
shift 

case $COMMAND in 
    create_bridge)
        if [[ $# -ne 1 ]]
            then
            echo "IP address needed for bridge creation"
            exit 1
        fi
        create_bridge $BRIDGE $1 $NET_PREFIX
    ;;
    delete_bridge)
        delete_bridge $BRIDGE
    ;;
    create_container)
        if [[ $# -lt 2 ]]
            then
            echo "Need to provide name and IP of container"
            exit 1
        fi
        create_container $1 $2 $NET_PREFIX $BRIDGE
    ;;
    delete_container) 
    ;;
    run)
        if [[ $# -lt 2 ]]
            then
            echo "Need to provide name of container and command"
            exit 1
        fi
        CNT_NAME=$1
        shift
        run_command $CNT_NAME "$@" 
    ;;
    help)
        print_usage
    ;;
    *)
        echo "Unknown command: " $COMMAND
        print_usage
        exit 1
    ;;
esac
