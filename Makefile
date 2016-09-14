KUBERNETES=kubernetes
FLEET=fleet

GLANCE_IMG=fleet

IMG=image
INSTANCE=instance
INSTANCE_OUTPUT=instance_id
HAPPY_END=generate_finished_well

FLAGS=--insecure
$(eval NOW := $(shell date +%s))

$(eval GOPATH := $(shell pwd))
PHONE_PORT=80
PHONE=phone
SUDO=sudo


GO_SRCS = phone/phone.go

default: all

.PHONY: all $(IMG) $(INSTANCE) check check_versions fclean clean $(PHONE) $(FLEET) $(KUBERNETES) is_instance_finished_well is_instance_off

$(PHONE): $(GO_SRCS)
	GOPATH=$(GOPATH) $(CC) build -o $(PHONE) phone/phone.go

clean:
	@openstack $(FLAGS) stack delete --yes --wait $(KUBERNETES) || true
	@openstack $(FLAGS) stack delete --yes --wait $(FLEET) || true

fclean: clean
	@openstack $(FLAGS) stack delete --yes --wait $(INSTANCE) || true
	@openstack $(FLAGS) image delete $(GLANCE_IMG) || true
	@nova $(FLAGS) image-delete fleet $(GLANCE_IMG) || true
	@rm $(PHONE) || true

iclean:
	@openstack $(FLAGS) stack delete --yes --wait $(INSTANCE) || true
	@openstack $(FLAGS) image delete $(GLANCE_IMG) || true
	@nova $(FLAGS) image-delete fleet $(GLANCE_IMG) || true
	@test -f $(IMG) && rm -v $(IMG) || true
	@rm $(PHONE) || true

check:
	@test '$(KEY_NAME)'
	@test '$(PUB_KEY)'
	@test '$(DNS_NS)'
	@test '$(BUCKET)'
	@test '$(PROXY)'
	@test '$(NTP)'
	@test '$(NTPFALL)'
	@test '$(KUBERNETES)'
	@test '$(FLEET)'
	@test '$(IMG)'
	@test '$(INSTANCE)'
	@test '$(FLAVOR_INSTANCE)'
	@test '$(NOW)'
	@test '$(PHONE_HOME)'
	@echo {} | jq . > /dev/null

check_versions: check
	test '$(ETCD_VERSION)'
	test '$(FLEET_VERSION)'
	test '$(CONFD_VERSION)'
	test '$(RKT_VERSION)'
	test '$(FLANNEL_VERSION)'
	test '$(DOCKER_VERSION)'
	test '$(KUBERNETES_VERSION)'
	test '$(CNI_VERSION)'
	test '$(TORUS_VERSION)'
	test '$(NETENV_VERSION)'

	curl -Ifk $(BUCKET)/etcd/$(ETCD_VERSION)
	curl -Ifk $(BUCKET)/fleet/$(FLEET_VERSION)
	curl -Ifk $(BUCKET)/confd/$(CONFD_VERSION)
	curl -Ifk $(BUCKET)/rkt/$(RKT_VERSION)
	curl -Ifk $(BUCKET)/flannel/$(FLANNEL_VERSION)
	curl -Ifk $(BUCKET)/docker/$(DOCKER_VERSION)
	curl -Ifk $(BUCKET)/kubernetes/$(KUBERNETES_VERSION)
	curl -Ifk $(BUCKET)/cni/$(CNI_VERSION)
	curl -Ifk $(BUCKET)/netenv/$(NETENV_VERSION)
	curl -Ifk $(BUCKET)/torus/$(TORUS_VERSION)
	curl -Ifk $(BUCKET)/calico/$(CALICO_VERSION)

	curl -Ifk $(BUCKET)/aci/calico-node.aci
	curl -Ifk $(BUCKET)/aci/elasticsearch.aci
	curl -Ifk $(BUCKET)/aci/etcd.aci
	curl -Ifk $(BUCKET)/aci/hyperkube.aci
	curl -Ifk $(BUCKET)/aci/jds_kafka.aci
	curl -Ifk $(BUCKET)/aci/kafka.aci
	curl -Ifk $(BUCKET)/aci/kibana.aci
	curl -Ifk $(BUCKET)/aci/logstash.aci
	curl -Ifk $(BUCKET)/aci/skydns.aci
	curl -Ifk $(BUCKET)/aci/stage1-coreos.aci
	curl -Ifk $(BUCKET)/aci/traefik.aci
	curl -Ifk $(BUCKET)/aci/zookeeper.aci


$(INSTANCE): check_versions
	@openstack --insecure stack output show instance instance_id -f json -c output_value || \
	openstack $(FLAGS) stack create $(INSTANCE) \
	-t image/generate_image.yaml \
	-e registry.yaml \
	--parameter apt_proxy="$(PROXY)" \
	--parameter key_name='$(KEY_NAME)' \
	--parameter floatingip_network_name='ext-net' \
	--parameter flavor='m1.small' \
	--parameter image='ubuntu-16.04-server' \
	--parameter dns_nameservers='$(DNS_NS)' \
	--parameter etcd_tar="$(BUCKET)/etcd/$(ETCD_VERSION)" \
	--parameter fleet_tar="$(BUCKET)/fleet/$(FLEET_VERSION)" \
	--parameter confd_bin="$(BUCKET)/confd/$(CONFD_VERSION)" \
	--parameter rkt_tar="$(BUCKET)/rkt/$(RKT_VERSION)" \
	--parameter flannel_tar="$(BUCKET)/flannel/$(FLANNEL_VERSION)" \
	--parameter docker_tar="$(BUCKET)/docker/$(DOCKER_VERSION)" \
	--parameter cni_tar="$(BUCKET)/cni/$(CNI_VERSION)" \
	--parameter kubernetes_tar="$(BUCKET)/kubernetes/$(KUBERNETES_VERSION)" \
	--parameter netenv_bin="$(BUCKET)/netenv/setup-network-environment" \
	--parameter torus_tar="$(BUCKET)/torus/$(TORUS_VERSION)" \
	--parameter calico_tar="$(BUCKET)/calico/$(CALICO_VERSION)" \
	--parameter bucket_root_url="$(BUCKET)" \
	--parameter ssh_authorized_keys="$(PUB_KEY)" \
	--parameter ntp="$(NTP)" \
	--parameter ntpfall="$(NTPFALL)" \
	--parameter phone="$(PHONE_HOME)" \
	--wait

is_instance_off: is_instance_finished_well
	$(shell openstack $(FLAGS) server show \
	    $(shell openstack $(FLAGS) stack output show $(INSTANCE) $(INSTANCE_OUTPUT) -f json -c output_value | \
	        jq -r .[0].Value) \
	    -f json | jq -r '.[1].Value == "Shutdown"')

is_instance_finished_well: check
	openstack $(FLAGS) console log show $(shell openstack $(FLAGS) stack output show $(INSTANCE) $(INSTANCE_OUTPUT) -f json -c output_value | \
        jq -r .[0].Value) | grep -wc $(HAPPY_END)

$(IMG): is_instance_off
	openstack --insecure stack output show instance instance_id -f json -c output_value | \
        jq -r .[0].Value | xargs -I {} nova $(FLAGS) image-create {} $(GLANCE_IMG) --poll


$(KUBERNETES): check
	@openstack $(FLAGS) stack create $(KUBERNETES) \
	-t kubernetes/$(KUBERNETES).yaml \
	-e registry.yaml \
	--parameter key_name=$(KEY_NAME) \
	--parameter flavor_static='m1.medium' \
	--parameter flavor_stateless="m1.large" \
	--parameter flavor_statefull="m1.large" \
	--parameter image='$(GLANCE_IMG)' \
	--parameter dns_nameservers=$(DNS_NS) \
	--parameter floatingip_network_name='ext-net' \
	--wait

$(FLEET): check
	@openstack $(FLAGS) stack create $(FLEET) \
	-t fleet/$(FLEET).yaml \
	-e registry.yaml \
	--parameter key_name=$(KEY_NAME) \
	--parameter flavor_static='m1.medium' \
	--parameter flavor_stateless="m1.large" \
	--parameter flavor_statefull="m1.large" \
	--parameter image='$(GLANCE_IMG)' \
	--parameter dns_nameservers=$(DNS_NS) \
	--parameter floatingip_network_name='ext-net' \
	--wait

$(FLEET)_add_extra_member: check
	@./etcd/add_member.sh $(FLEET)

$(FLEET)_delete_extra_member: check
	@./etcd/delete_member.sh $(FLEET)

$(FLEET)_delete: $(FLEET)_delete_extra_member
	openstack $(FLAGS) stack delete --yes $(FLEET) --wait

$(KUBERNETES)_delete_extra_members: check
	@./etcd/delete_member.sh $(KUBERNETES) all

$(KUBERNETES)_add_extra_member: check
	@./etcd/add_member.sh $(KUBERNETES)

$(KUBERNETES)_delete_extra_members: check
	@./etcd/delete_member.sh $(KUBERNETES) all

$(KUBERNETES)_delete: $(KUBERNETES)_delete_extra_members
	openstack $(FLAGS) stack delete --yes $(KUBERNETES) --wait


