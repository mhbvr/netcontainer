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

function list_containers {
	CNTS=$(ip netns list | awk '{ print $1 }')
	for CNT in $CNTS
	do
		IP=$(ip netns exec $CNT ip addr show ${CNT}_cnt 2>/dev/null | awk '/inet / { print $2 }')
		if [[ "x$IP" != "x" ]]
		then
			echo $CNT $IP
		fi
	done
}

function is_container {
	CNT_NAME=$1
	for CNT in $(ip netns list | awk '{ print $1 }')
	do
		if [[ $CNT == $CNT_NAME ]]
		then
			return 0
		fi
	done
	return 1
}

function delete_container {
	CNT_NAME=$1
	ip netns delete $CNT_NAME
	
}

function run_command {
    CNT_NAME=$1
    shift
    ip netns exec $CNT_NAME "$@"
}


function print_usage {
    echo "netcontaner.sh <command> [args]"
    echo "Possible commands are:"
    echo "    create_bridge IPADDR"
    echo "    delete_bridge"
    echo "    create_container NAME IPADDR"
    echo "    delete_container NAME"
    echo "    list"
    echo "    show"
    echo "    run CONTAINER_NAME COMMAND"
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
		NUM_C=$(list_containers | wc -l)
		if [[ $NUM_C -ne 0 ]]
		then
			echo "Delete these containers first:"
			list_containers
			exit 1
		fi
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
	list)
		list_containers
	;;
	show)
		echo "Bridge:"
		if ip addr show $BRIDGE 1>/dev/null 2>&1
		then
			echo "$BRIDGE $(ip addr show $BRIDGE 2>/dev/null | awk '/inet / { print $2 }')"
		else
			echo "Not configured"
		fi
		echo "Containers:"
		list_containers
	;;
    delete_container)
        if [[ $# -ne 1 ]]
            then
            echo "You need to provide container name only"
            exit 1
        fi

		if ! is_container $1
		then
			echo "Container $1 not exist"
			exit 1
		fi

		N_PIDS=$(ip netns pids $1| wc -l)
		if [[ $N_PIDS -ne 0 ]]
		then
			echo "Terminate this processes first:"
			ip netns pids $1
			exit 1
		fi
		delete_container $1
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
        echo "Unknown command: $COMMAND"
        print_usage
        exit 1
    ;;
esac
