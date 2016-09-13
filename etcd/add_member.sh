#!/usr/bin/env bash


set -o pipefail
set -e

BASE=fleet
PARENT=etcd_static
CHILD_STACK="etcd_static_instance.yaml"

ETCD_STATIC=$(openstack --insecure stack resource show ${BASE} ${PARENT} -f json | jq -r .[3].Value)
RG_ANTI=$(openstack --insecure stack output show ${ETCD_STATIC} anti_affinity -f json | jq -r .[2].Value)
INDEX=$(openstack --insecure server group show ${RG_ANTI} -f json | jq -r .[1].Value | wc -w)
TOKEN=$(openstack --insecure stack output show ${ETCD_STATIC} etcd_initial_cluster_token -f json | jq -r .[2].Value)
PARAMS="--parameter index=${INDEX}"

for key in $(openstack --insecure stack output list ${ETCD_STATIC} -c output_key -f value)
do
    value=$(openstack --insecure stack output show ${ETCD_STATIC} ${key} -f json | \
        jq -r .[2].Value)
    echo "${key}=\"${value}\""
    PARAMS="${PARAMS} --parameter ${key}=${value}"
done

set -x
openstack --insecure stack create ${PARENT}-${INDEX}-${TOKEN} -t $(dirname $0)/${CHILD_STACK} ${PARAMS} --wait