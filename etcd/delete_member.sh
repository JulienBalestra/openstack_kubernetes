#!/usr/bin/env bash


set -o pipefail

BASE=fleet
PARENT=etcd_static

ETCD_STATIC=$(openstack --insecure stack resource show ${BASE} ${PARENT} -f json | jq -r .[3].Value)
RG_ANTI=$(openstack --insecure stack output show ${ETCD_STATIC} anti_affinity -f json | jq -r .[2].Value)
TOKEN=$(openstack --insecure stack output show ${ETCD_STATIC} etcd_initial_cluster_token -f json | jq -r .[2].Value)
RG_NB=$(openstack --insecure server group show ${RG_ANTI} -f json | jq -r .[1].Value | wc -w)

if [ "opt-$1" == "opt-all" ] && [ ${RG_NB} -gt 3 ]
then
    while [ ${RG_NB} -gt 3 ]
    do
        echo "Server group == ${RG_NB}"
        openstack --insecure stack delete ${PARENT}-$(($RG_NB-1))-${TOKEN} --yes --wait
        RG_NB=$(openstack --insecure server group show ${RG_ANTI} -f json | jq -r .[1].Value | wc -w)
        echo "Server group == ${RG_NB}"
    done
elif [ ${RG_NB} -gt 3 ]
then
    openstack --insecure stack delete ${PARENT}-$(($RG_NB-1))-${TOKEN} --yes --wait
else
    echo "Nothing to be done: server group == ${RG_NB}"
fi

