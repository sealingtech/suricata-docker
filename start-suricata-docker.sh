#!/bin/bash
#
# Starts a Docker instance of Suricata and tunes some settings for high throughput
# - Requires RHEL/CentOS 7.3+ or kernel 4.4+.
# - Uses AF-Packet with fanout as the multi-core session load balancer
#
# Usage: start-suricata-docker <interface>'

if [[ $# -eq 0 ]] ; then
    echo 'ERROR: No interface found'
    echo 'Usage: start-suricata-docker <interface>'
    echo 'File contains editable variables'
    exit 1
fi

if [ ! -d  /var/run/netns ]; then
  mkdir -p /var/run/netns;
fi

###############################
#Edit these varibles as needed#
###############################

#CONTAINERINT is the interface within the Container
CONTAINERINT=eth1

# Do not edit these veriables
CONTAINER=$(docker run -it -d suricata-docker)
CONTAINERID=${CONTAINER:0:12}
pid=$(docker inspect --format='{{ .State.Pid }}' $CONTAINERID)

echo "Container PID is $pid ."

ln -s /proc/$pid/ns/net /var/run/netns/$CONTAINERID
ip link set $1 netns $CONTAINERID
sleep 2
ip netns exec $CONTAINERID ip link set $1 name $CONTAINERINT
sleep 2
ip netns exec $CONTAINERID ip link set $CONTAINERINT up

echo "Setting Runmode..."
docker exec $CONTAINERID sed -i 's/#runmode: autofp/runmode: workers/' /etc/suricata/suricata.yaml
echo "Setting AF-Packet Interface to $CONTAINERINT ..."
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{/'"interface:"'/s/\('interface:'\)\(.*$\)/\1'" $CONTAINERINT"'/}' /etc/suricata/suricata.yaml
echo "Creating Random ClusterID for AF-Packet..."
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{/'"cluster-id:"'/s/\('cluster-id:'\)\(.*$\)/\1'" $RANDOM"'/}' /etc/suricata/suricata.yaml
echo "Enabling mmap..."
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{ s/#use-mmap/use-mmap/}' /etc/suricata/suricata.yaml
echo "Enabling AF-Packet V3..."
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{ s/#tpacket-v3/tpacket-v3/}' /etc/suricata/suricata.yaml
echo "Enabling CPU Affinity..."
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"set-cpu-affinity:"'/s/\('set-cpu-affinity:'\)\(.*$\)/\1'" yes"'/}' /etc/suricata/suricata.yaml
echo "Setting CPU Affinity for Xeon-D 1541"
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"  cpu-affinity:"'/,/^[  ]*$/{/'"    - management-cpu-set:"'/,/^[  ]*$/{0,/'"cpu:"'/s/\('"cpu:"'\)\(.*$\)/\1'" [ 1,7 ]"'/}}}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"  cpu-affinity:"'/,/^[  ]*$/{/'"    - receive-cpu-set:"'/,/^[  ]*$/{0,/'"cpu:"'/s/\('"cpu:"'\)\(.*$\)/\1'" [ 1,7 ]"'/}}}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"  cpu-affinity:"'/,/^[  ]*$/{/'"    - worker-cpu-set:"'/,/^[  ]*$/{0,/'"cpu:"'/s/\('"cpu:"'\)\(.*$\)/\1'" [ \"1-7\",\"9-15\" ]"'/}}}' /etc/suricata/suricata.yaml
echo "Starting Suricata with command \"suricata --af-packet -vv\"..."
docker exec -d --privileged $CONTAINERID suricata --af-packet -vv
