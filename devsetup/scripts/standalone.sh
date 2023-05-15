#!/bin/bash
#
# Copyright 2023 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
set -ex
export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EDPM_COMPUTE_SUFFIX=${1:-"0"}
EDPM_COMPUTE_NAME=${EDPM_COMPUTE_NAME:-"edpm-compute-${EDPM_COMPUTE_SUFFIX}"}
IP_ADRESS_SUFFIX=${IP_ADRESS_SUFFIX:-"$((100+${EDPM_COMPUTE_SUFFIX}))"}
IP="192.168.122.${IP_ADRESS_SUFFIX}"
SSH_KEY=${SSH_KEY:-"${SCRIPTPATH}/../../out/edpm/ansibleee-ssh-key-id_rsa"}
SSH_OPT="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $SSH_KEY"
CMDS_FILE=${CMDS_FILE:-"/tmp/director_standalone"}
CLEANUP_DIR_CMD=${CLEANUP_DIR_CMD:-"rm -Rf"}

if [[ ! -f $SSH_KEY ]]; then
    echo "$SSH_KEY is missing"
    exit 1
fi

cat <<EOF > $CMDS_FILE
set -euxo pipefail

useradd dpadev || echo "dpadev"

export GATEWAY=192.168.122.1
export VIP=192.168.24.3
export NETMASK=24
export INTERFACE=eth0
export HOME=/home/dpadev
export NTP_SERVER=clock.corp.redhat.com

touch \$HOME/standalone.log

cat << SPS > \$HOME/standalone_parameters.yaml
parameter_defaults:
  CloudName: $IP
  # ControlPlaneStaticRoutes: []
  ControlPlaneStaticRoutes:
    - ip_netmask: 0.0.0.0/0
      next_hop: \$GATEWAY
      default: true
  DeploymentUser: \$USER
  DnsServers:
    - 192.168.122.1
  DockerInsecureRegistryAddress:
    - $IP:8787
  NeutronPublicInterface: \$INTERFACE
  NtpServer: \$NTP_SERVER
  CloudDomain: localdomain
  NeutronDnsDomain: localdomain
  NeutronBridgeMappings: datacentre:br-ex
  NeutronPhysicalBridge: br-ex
  StandaloneEnableRoutedNetworks: false
  StandaloneHomeDir: \$HOME
  InterfaceLocalMtu: 1500
  NovaComputeLibvirtType: qemu
SPS

sudo hostnamectl set-hostname standalone.localdomain
sudo hostnamectl set-hostname standalone.localdomain --transient

sudo dnf update -y
sudo dnf install -y vim git curl util-linux lvm2 tmux wget
sudo dnf remove -y epel-release
url=https://trunk.rdoproject.org/centos9/component/tripleo/current/
rpm_name=\$(curl \$url | grep python3-tripleo-repos | sed -e 's/<[^>]*>//g' | awk 'BEGIN { FS = ".rpm" } ; { print \$1 }')
rpm=\$rpm_name.rpm
sudo dnf install -y \$url\$rpm
sudo -E tripleo-repos -b wallaby current-tripleo-dev ceph --stream
sudo dnf repolist
sudo dnf update -y
sudo dnf install -y podman
sudo dnf install -y python3-tripleoclient

openstack tripleo container image prepare default \
  --output-env-file \$HOME/containers-prepare-parameters.yaml

if podman ps | grep keystone; then
    echo "Looks like OpenStack is already deployed, not re-deploying."
    exit 0
fi

sudo openstack tripleo deploy \
  --templates \
  --local-ip=$IP/24 \
  --control-virtual-ip=\$VIP \
  -e /usr/share/openstack-tripleo-heat-templates/environments/standalone/standalone-tripleo.yaml \
  -r /usr/share/openstack-tripleo-heat-templates/roles/Standalone.yaml \
  -e "\$HOME/containers-prepare-parameters.yaml" \
  -e "\$HOME/standalone_parameters.yaml" \
  -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
  --output-dir \$HOME

export OS_CLOUD=standalone
openstack endpoint list
EOF

scp $SSH_OPT $CMDS_FILE root@$IP:/tmp/standalone.sh
ssh $SSH_OPT root@$IP "bash /tmp/standalone.sh; rm -f /tmp/standalone.sh"
${CLEANUP_DIR_CMD} $CMDS_FILE
