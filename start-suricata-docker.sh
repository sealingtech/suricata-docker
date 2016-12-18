#!/bin/bash
if [[ $# -eq 0 ]] ; then
    echo 'ERROR: No interface found'
    echo 'Usage: start-bro-docker <interface>'
    exit 1
fi
CONTAINERID=$(docker run -it -d multi-tenant-ids)
pid=$(docker inspect --format='{{ .State.Pid }}' $CONTAINERID)
ln -s /proc/$pid/ns/net /var/run/netns/$CONTAINERID
ip link set $1 netns $CONTAINERID
sleep 2
ip netns exec $CONTAINERID ip link set $1 name eth1
sleep 2
ip netns exec $CONTAINERID ip link set eth1 up
docker exec $CONTAINERID sed -i 's/#runmode: autofp/runmode: workers/' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{/'"interface:"'/s/\('interface:'\)\(.*$\)/\1'" eth1"'/}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{/'"cluster-id:"'/s/\('cluster-id:'\)\(.*$\)/\1'" $RANDOM"'/}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{ s/#use-mmap/use-mmap/}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'af-packet'/,/^[   ]*$/{ s/#tpacket-v3/tpacket-v3/}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"set-cpu-affinity:"'/s/\('set-cpu-affinity:'\)\(.*$\)/\1'" yes"'/}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"  cpu-affinity:"'/,/^[  ]*$/{/'"    - management-cpu-set:"'/,/^[  ]*$/{0,/'"cpu:"'/s/\('"cpu:"'\)\(.*$\)/\1'" [ 1,7 ]"'/}}}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"  cpu-affinity:"'/,/^[  ]*$/{/'"    - receive-cpu-set:"'/,/^[  ]*$/{0,/'"cpu:"'/s/\('"cpu:"'\)\(.*$\)/\1'" [ 1,7 ]"'/}}}' /etc/suricata/suricata.yaml
docker exec $CONTAINERID sed -i '/^'threading:'/,/^[   ]*$/{/'"  cpu-affinity:"'/,/^[  ]*$/{/'"    - worker-cpu-set:"'/,/^[  ]*$/{0,/'"cpu:"'/s/\('"cpu:"'\)\(.*$\)/\1'" [ \"1-7\",\"9-15\" ]"'/}}}' /etc/suricata/suricata.yaml
docker exec -d --privileged $CONTAINERID suricata --af-packet -vv
