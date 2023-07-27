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

# expect that the common.sh is in the same dir as the calling script
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
. ${SCRIPTPATH}/common.sh --source-only

if [ -z "$NAMESPACE" ]; then
    echo "Please set NAMESPACE"; exit 1
fi

if [ -z "$KIND" ]; then
    echo "Please set SERVICE"; exit 1
fi

if [ -z "$DEPLOY_DIR" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ -z "$EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST" ]; then
    echo "Please set EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST"; exit 1
fi

if [ -z "$EDPM_OVN_METADATA_AGENT_TRANSPORT_URL" ]; then
    echo "Please set EDPM_OVN_METADATA_AGENT_TRANSPORT_URL"; exit 1
fi

if [ -z "$EDPM_OVN_METADATA_AGENT_SB_CONNECTION" ]; then
    echo "Please set EDPM_OVN_METADATA_AGENT_SB_CONNECTION"; exit 1
fi

if [ -z "$EDPM_OVN_DBS" ]; then
    echo "Please set EDPM_OVN_DBS"; exit 1
fi

if [ -z "$EDPM_NADS" ]; then
    echo "Please set EDPM_NADS"; exit 1
fi

if [ -z "$EDPM_BMH_NAMESPACE" ]; then
    echo "Please set EDPM_BMH_NAMESPACE"; exit 1
fi

if [ -z "${INTERFACE_MTU}" ]; then
    echo "Please set INTERFACE_MTU"; exit 1
fi

if [ -z "${EDPM_DEFAULT_GW}" ]; then
    echo "Please set EDPM_DEFAULT_GW"; exit 1
fi

NAME=${KIND,,}

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

pushd ${DEPLOY_DIR}

REGISTRY_NAME=${REGISTRY_NAME:-"quay.io"}
REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE:-"podified-antelope-centos9"}
CONTAINER_TAG=${CONTAINER_TAG:-"current-podified"}

cat <<EOF >kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
namespace: ${NAMESPACE}
patches:
- target:
    kind: ${KIND}
  patch: |-
    - op: replace
      path: /spec/deployStrategy/deploy
      value: true
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/bmhNamespace
      value: ${EDPM_BMH_NAMESPACE}
    - op: add
      path: /spec/roles/edpm-compute/nodeTemplate/networks
      value:
        - name: CtlPlane
          subnetName: subnet1
          defaultRoute: true
        - name: InternalApi
          subnetName: subnet1
        - name: Storage
          subnetName: subnet1
        - name: Tenant
          subnetName: subnet1
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_network_config_template
      value: ${EDPM_NETWORK_CONFIG_TEMPLATE}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_DEFAULT_transport_url
      value: ${EDPM_OVN_METADATA_AGENT_TRANSPORT_URL}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_metadata_agent_ovn_ovn_sb_connection
      value: ${EDPM_OVN_METADATA_AGENT_SB_CONNECTION}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_metadata_agent_DEFAULT_nova_metadata_host
      value: ${EDPM_OVN_METADATA_AGENT_NOVA_METADATA_HOST}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_metadata_agent_DEFAULT_metadata_proxy_shared_secret
      value: ${EDPM_OVN_METADATA_AGENT_PROXY_SHARED_SECRET}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_DEFAULT_bind_host
      value: ${EDPM_OVN_METADATA_AGENT_BIND_HOST}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_chrony_ntp_servers
      value: [${EDPM_CHRONY_NTP_SERVER}]
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_dbs
      value: [${EDPM_OVN_DBS}]
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_controller_agent_image
      value: "${REGISTRY_NAME}/${REGISTRY_NAMESPACE}/openstack-ovn-controller:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_iscsid_image
      value: "${REGISTRY_NAME}/${REGISTRY_NAMESPACE}/openstack-iscsid:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_logrotate_crond_image
      value: "${REGISTRY_NAME}/${REGISTRY_NAMESPACE}/openstack-cron:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_nova_compute_container_image
      value: "${REGISTRY_NAME}/${REGISTRY_NAMESPACE}/openstack-nova-compute:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_nova_libvirt_container_image
      value: "${REGISTRY_NAME}/${REGISTRY_NAMESPACE}/openstack-nova-libvirt:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_ovn_metadata_agent_image
      value: "${REGISTRY_NAME}/${REGISTRY_NAMESPACE}/openstack-neutron-metadata-agent-ovn:${CONTAINER_TAG}"
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleVars/edpm_sshd_allowed_ranges
      value: ${EDPM_SSHD_ALLOWED_RANGES}
    - op: replace
      path: /spec/roles/edpm-compute/networkAttachments
      value: ${EDPM_NADS}
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleSSHPrivateKeySecret
      value: ${EDPM_ANSIBLE_SECRET}
EOF
if [ "$EDPM_PROVISIONING_INTERFACE" != "" ]; then
cat <<EOF >>kustomization.yaml
    - op: add
      path: /spec/roles/edpm-compute/baremetalSetTemplate/provisioningInterface
      value: ${EDPM_PROVISIONING_INTERFACE}
EOF
fi
if [ "$EDPM_TOTAL_NODES" -eq 1 ]; then
cat <<EOF >>kustomization.yaml
    - op: remove
      path: /spec/nodes/edpm-compute-1
EOF
elif [ "$EDPM_TOTAL_NODES" -gt 2 ]; then
    for INDEX in $(seq 1 $((${EDPM_TOTAL_NODES} -1))) ; do
cat <<EOF >>kustomization.yaml
    - op: copy
      from: /spec/nodes/edpm-compute-0
      path: /spec/nodes/edpm-compute-${INDEX}
    - op: replace
      path: /spec/nodes/edpm-compute-${INDEX}/hostName
      value: edpm-compute-${INDEX}
EOF
    done
fi
if [ ! -z "$EDPM_ANSIBLE_USER" ]; then
cat <<EOF >>kustomization.yaml
    - op: replace
      path: /spec/roles/edpm-compute/nodeTemplate/ansibleUser
      value: ${EDPM_ANSIBLE_USER}
EOF
fi

kustomization_add_resources

popd
