#!/bin/bash
#
# Copyright 2022 Red Hat Inc.
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
set -e

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

if [ -z "${WORKERS}" ]; then
    echo "Please set WORKERS"; exit 1
fi

if [ -z "${INTERFACE}" ]; then
    echo "Please set INTERFACE"; exit 1
fi

if [ -z "${INTERFACE_MTU}" ]; then
    echo "Please set INTERFACE_MTU"; exit 1
fi

echo DEPLOY_DIR ${DEPLOY_DIR}
echo WORKERS ${WORKERS}
echo INTERFACE ${INTERFACE}
echo INTERFACE_MTU ${INTERFACE_MTU}

CTLPLANE_IP_ADDRESS_SUFFIX=10
# Use different suffix for other networks as the sample netconfig
# we use starts with .10
IP_ADDRESS_SUFFIX=5
for WORKER in ${WORKERS}; do
    if [ "${CTLPLANE_NETWORK_DHCP}" == "y" ]; then
        CTLPLANE_NW_CONFIG="dhcp: true
        enabled: true"
    else
        CTLPLANE_NW_CONFIG="address:
        - ip: 192.168.122.${CTLPLANE_IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false"
    fi

    cat > ${DEPLOY_DIR}/${WORKER}_nncp.yaml <<EOF_CAT
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  labels:
    osp/interface: ${INTERFACE}
  name: ${INTERFACE}-${WORKER}
spec:
  desiredState:
    interfaces:
    - description: internalapi vlan interface
      ipv4:
        address:
        - ip: 172.17.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE}.${INTERNAL_API_VLAN_ID}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${INTERNAL_API_VLAN_ID}
    - description: storage vlan interface
      ipv4:
        address:
        - ip: 172.18.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE}.${STORAGE_VLAN_ID}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${STORAGE_VLAN_ID}
    - description: tenant vlan interface
      ipv4:
        address:
        - ip: 172.19.0.${IP_ADDRESS_SUFFIX}
          prefix-length: 24
        enabled: true
        dhcp: false
      ipv6:
        enabled: false
      name: ${INTERFACE}.${TENANT_VLAN_ID}
      state: up
      type: vlan
      vlan:
        base-iface: ${INTERFACE}
        id: ${TENANT_VLAN_ID}
    - description: Configuring ${INTERFACE}
      ipv4:
        ${CTLPLANE_NW_CONFIG}
      ipv6:
        enabled: false
      mtu: ${INTERFACE_MTU}
      name: ${INTERFACE}
      state: up
      type: ethernet
  nodeSelector:
    kubernetes.io/hostname: ${WORKER}
    node-role.kubernetes.io/worker: ""
EOF_CAT

    IP_ADDRESS_SUFFIX=$((${IP_ADDRESS_SUFFIX}+1))
    CTLPLANE_IP_ADDRESS_SUFFIX=$((${CTLPLANE_IP_ADDRESS_SUFFIX}+1))
done
