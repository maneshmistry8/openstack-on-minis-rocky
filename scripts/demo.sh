#!/usr/bin/env bash
set -euo pipefail

# Try to source admin-openrc from local etc/ dir (copied in deploy.yml) or system path
if [ -f "./etc/kolla/admin-openrc.sh" ]; then
  source ./etc/kolla/admin-openrc.sh
elif [ -f "/etc/kolla/admin-openrc.sh" ]; then
  source /etc/kolla/admin-openrc.sh
else
  echo "admin-openrc.sh not found. Run deploy first." >&2
  exit 1
fi

echo "[*] OpenStack services:"
openstack service list

# Ensure cirros image
if ! openstack image list -f value -c Name | grep -q '^cirros$'; then
  echo "[*] Uploading Cirros image..."
  curl -L -o /tmp/cirros.img https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
  openstack image create --file /tmp/cirros.img --disk-format qcow2 --container-format bare cirros
fi

# Flavor
openstack flavor show m1.tiny >/dev/null 2>&1 || openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny

# Public/provider net on physnet1 mapped to prov0 by default Kolla config
if ! openstack network show public >/dev/null 2>&1; then
  echo "[*] Creating provider (public) network on flat physnet1..."
  openstack network create public --external --share --provider-physical-network physnet1 --provider-network-type flat
fi

# Public subnet (adjust to your provider subnet)
if ! openstack subnet show public-subnet >/dev/null 2>&1; then
  echo "[*] Creating public subnet 192.168.60.0/24..."
  openstack subnet create --network public --subnet-range 192.168.60.0/24     --gateway 192.168.60.1 --dns-nameserver 1.1.1.1     --allocation-pool start=192.168.60.100,end=192.168.60.200 public-subnet
fi

# Tenant network + router
openstack network show demo-net >/dev/null 2>&1 || openstack network create demo-net
openstack subnet show demo-subnet >/dev/null 2>&1 ||   openstack subnet create --network demo-net --subnet-range 10.0.0.0/24 demo-subnet
openstack router show demo-router >/dev/null 2>&1 || openstack router create demo-router
openstack router set demo-router --external-gateway public
openstack router add subnet demo-router demo-subnet || true

# Keypair and VM
openstack keypair show demo-key >/dev/null 2>&1 || openstack keypair create demo-key > demo-key.pem && chmod 600 demo-key.pem
openstack server show demo-vm >/dev/null 2>&1 ||   openstack server create --image cirros --flavor m1.tiny --network demo-net --key-name demo-key demo-vm

echo "[*] Waiting for demo-vm to be ACTIVE..."
openstack server wait --state ACTIVE demo-vm

FIP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip demo-vm "$FIP"

echo
echo "[✓] Demo ready"
echo "    Floating IP: $FIP"
echo "    Try: ssh -o StrictHostKeyChecking=no cirros@${FIP}  (password: 'cubswin:)' for Cirros)"
