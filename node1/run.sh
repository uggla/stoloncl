#!/usr/bin/env bash

set -euo pipefail
set -x
IFS=$'\n\t'

if [[ -f remove ]]; then
	rm -rf data pgdata remove
fi

node1=$(nslookup node-1.uggla.fr | sed -rn '/Name/,/Address/'p | grep "Address" | awk '{print $NF}')
node2=$(nslookup node-2.uggla.fr | sed -rn '/Name/,/Address/'p | grep "Address" | awk '{print $NF}')
node3=$(nslookup node-3.uggla.fr | sed -rn '/Name/,/Address/'p | grep "Address" | awk '{print $NF}')

iam=$(ip a s eth0 | grep inet | head -1 | awk '{print $2}' | sed -r 's#/[0-9]+##')

# Start etcd
docker-compose -f docker-compose-etcd.yml up -d

# Check etcd
while [[ "$(docker exec $(docker ps | grep etcd | awk '{print $NF}') /bin/sh -c "ETCDCTL_API=3 /usr/local/bin/etcdctl member list" | grep -c "node")" != "3" ]]
do
	sleep 5s
done

mkdir -p pgdata
chown -R 1000:1000 pgdata
# Init db if required and node 1
if [[ ! -f init.done ]] && [[ "${iam}" == "${node1}" ]]; then
	docker run -ti sorintlab/stolon:master-pg10 stolonctl --cluster-name stolon-cluster --store-backend=etcdv3 --store-endpoints http://node-1.uggla.fr:2379,http://node-2.uggla.fr:2379,http://node-3.uggla.fr:2379 init --yes && touch init.done
fi

docker-compose -f docker-compose-stolon.yml up -d
