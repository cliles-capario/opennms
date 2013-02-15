/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2012 The OpenNMS Group, Inc.
 * OpenNMS(R) is Copyright (C) 1999-2012 The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is a registered trademark of The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * OpenNMS(R) is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with OpenNMS(R).  If not, see:
 *      http://www.gnu.org/licenses/
 *
 * For more information contact:
 *     OpenNMS(R) Licensing <license@opennms.org>
 *     http://www.opennms.org/
 *     http://www.opennms.com/
 *******************************************************************************/

package org.opennms.features.topology.plugins.topo.vmware.internal;

import org.opennms.features.topology.api.topo.*;
import org.opennms.features.topology.plugins.topo.simple.SimpleGraphProvider;
import org.opennms.netmgt.dao.IpInterfaceDao;
import org.opennms.netmgt.dao.NodeDao;
import org.opennms.netmgt.model.OnmsIpInterface;
import org.opennms.netmgt.model.OnmsNode;

import javax.xml.bind.JAXBException;
import java.io.UnsupportedEncodingException;
import java.net.MalformedURLException;
import java.net.URLDecoder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public class VmwareTopologyProvider extends SimpleGraphProvider implements GraphProvider {

    public static final String TOPOLOGY_NAMESPACE_VMWARE = "vmware";

    private final String SPLIT_REGEXP = " *, *";

    private NodeDao m_nodeDao;
    private IpInterfaceDao m_ipInterfaceDao;

    private boolean m_generated = false;

    public VmwareTopologyProvider() {
        super(TOPOLOGY_NAMESPACE_VMWARE);
    }

    public NodeDao getNodeDao() {
        return m_nodeDao;
    }

    public void setNodeDao(NodeDao nodeDao) {
        m_nodeDao = nodeDao;
    }

    public IpInterfaceDao getIpInterfaceDao() {
        return m_ipInterfaceDao;
    }

    public void setIpInterfaceDao(IpInterfaceDao ipInterfaceDao) {
        m_ipInterfaceDao = ipInterfaceDao;
    }

    public boolean isGenerated() {
        return m_generated;
    }

    public void initialize() {
        generate();
    }

    public void debug(Vertex vmwareVertex) {
        System.err.println("-+- id: " + vmwareVertex.getId());
        System.err.println(" |- hashCode: " + vmwareVertex.hashCode());
        System.err.println(" |- label: " + vmwareVertex.getLabel());
        System.err.println(" |- ip: " + vmwareVertex.getIpAddress());
        System.err.println(" |- iconKey: " + vmwareVertex.getIconKey());
        System.err.println(" |- nodeId: " + vmwareVertex.getNodeID());

        for (EdgeRef edge : getEdgeIdsForVertex(vmwareVertex)) {
            Edge vmwareEdge = getEdge(edge);
            VertexRef edgeTo = vmwareEdge.getTarget().getVertex();
            if (vmwareVertex.equals(edgeTo)) {
                edgeTo = vmwareEdge.getSource().getVertex();
            }
            System.err.println(" |- edgeTo: " + edgeTo);
        }
        System.err.println(" '- parent: " + (vmwareVertex.getParent() == null ? null : vmwareVertex.getParent().getId()));
    }

    public void debugAll() {
        for (Vertex id : getVertices()) {
            debug(id);
        }
    }

    private AbstractVertex addDatacenterGroup(String vertexId, String groupName) {
        if (containsVertexId(vertexId)) {
            return (AbstractVertex) getVertex(TOPOLOGY_NAMESPACE_VMWARE, vertexId);
        }
        return addGroup(vertexId, "DATACENTER_ICON", groupName);
    }

    private AbstractVertex addNetworkVertex(String vertexId, String vertexName) {
        if (containsVertexId(vertexId)) {
            return (AbstractVertex) getVertex(TOPOLOGY_NAMESPACE_VMWARE, vertexId);
        }
        AbstractVertex vertex = addVertex(vertexId, 50, 50);
        vertex.setIconKey("NETWORK_ICON");
        vertex.setLabel(vertexName);
        return vertex;
    }

    private AbstractVertex addDatastoreVertex(String vertexId, String vertexName) {
        if (containsVertexId(vertexId)) {
            return (AbstractVertex) getVertex(TOPOLOGY_NAMESPACE_VMWARE, vertexId);
        }
        AbstractVertex vertex = addVertex(vertexId, 50, 50);
        vertex.setIconKey("DATASTORE_ICON");
        vertex.setLabel(vertexName);
        return vertex;
    }

    private AbstractVertex addVirtualMachineVertex(String vertexId, String vertexName, String primaryInterface, int id, String powerState) {
        if (containsVertexId(vertexId)) {
            return (AbstractVertex) getVertex(TOPOLOGY_NAMESPACE_VMWARE, vertexId);
        }

        String icon = "VIRTUALMACHINE_ICON_UNKNOWN";

        if ("poweredOn".equals(powerState)) {
            icon = "VIRTUALMACHINE_ICON_ON";
        } else if ("poweredOff".equals(powerState)) {
            icon = "VIRTUALMACHINE_ICON_OFF";
        } else if ("suspended".equals(powerState)) {
            icon = "VIRTUALMACHINE_ICON_SUSPENDED";
        }

        AbstractVertex vertex = addVertex(vertexId, 50, 50);
        vertex.setIconKey(icon);
        vertex.setLabel(vertexName);
        vertex.setIpAddress(primaryInterface);
        vertex.setNodeID(id);
        return vertex;
    }

    private AbstractVertex addHostSystemVertex(String vertexId, String vertexName, String primaryInterface, int id, String powerState) {
        if (containsVertexId(vertexId)) {
            return (AbstractVertex) getVertex(TOPOLOGY_NAMESPACE_VMWARE, vertexId);
        }

        String icon = "HOSTSYSTEM_ICON_UNKNOWN";

        if ("poweredOn".equals(powerState)) {
            icon = "HOSTSYSTEM_ICON_ON";
        } else if ("poweredOff".equals(powerState)) {
            icon = "HOSTSYSTEM_ICON_OFF";
        } else if ("standBy".equals(powerState)) {
            icon = "HOSTSYSTEM_ICON_STANDBY";
        }

        AbstractVertex vertex = addVertex(vertexId, 50, 50);
        vertex.setIconKey(icon);
        vertex.setLabel(vertexName);
        vertex.setIpAddress(primaryInterface);
        vertex.setNodeID(id);
        return vertex;
    }


    private void addHostSystem(OnmsNode hostSystem) {
        // getting data for nodes

        String vmwareManagementServer = hostSystem.getAssetRecord().getVmwareManagementServer().trim();
        String vmwareManagedObjectId = hostSystem.getAssetRecord().getVmwareManagedObjectId().trim();
        String vmwareTopologyInfo = hostSystem.getAssetRecord().getVmwareTopologyInfo().trim();
        String vmwareState = hostSystem.getAssetRecord().getVmwareState().trim();

        String datacenterMoId = null;
        String datacenterName = "Datacenter (" + vmwareManagementServer + ")";

        ArrayList<String> networks = new ArrayList<String>();
        ArrayList<String> datastores = new ArrayList<String>();

        HashMap<String, String> moIdToName = new HashMap<String, String>();

        String entities[] = vmwareTopologyInfo.split(SPLIT_REGEXP);

        for (String entityAndName : entities) {
            String splitBySlash[] = entityAndName.split("/");
            String entityId = splitBySlash[0];

            String entityName = "unknown";

            if (splitBySlash.length > 1) {
                try {
                    entityName = new String(URLDecoder.decode(splitBySlash[1], "UTF-8"));
                } catch (UnsupportedEncodingException e) {
                    e.printStackTrace();
                }
            }

            String entityType = entityId.split("-")[0];

            if ("network".equals(entityType)) {
                networks.add(entityId);
            }

            if ("datastore".equals(entityType)) {
                datastores.add(entityId);
            }

            if ("datacenter".equals(entityType)) {
                datacenterMoId = entityId;
            }

            moIdToName.put(entityId, entityName);
        }

        if (datacenterMoId != null) {
            datacenterName = moIdToName.get(datacenterMoId) + " (" + vmwareManagementServer + ")";
        }

        AbstractVertex datacenterVertex = addDatacenterGroup(vmwareManagementServer, datacenterName);

        String primaryInterface = "unknown";

        // get the primary interface ip address
        OnmsIpInterface ipInterface = m_ipInterfaceDao.findPrimaryInterfaceByNodeId(hostSystem.getId());

        if (ipInterface != null) {
            primaryInterface = ipInterface.getIpHostName();
        }

        AbstractVertex hostSystemVertex = addHostSystemVertex(vmwareManagementServer + "/" + vmwareManagedObjectId, hostSystem.getLabel(), primaryInterface, hostSystem.getId(), vmwareState);

        // set the parent vertex
        hostSystemVertex.setParent(datacenterVertex);

        for (String network : networks) {
            AbstractVertex networkVertex = addNetworkVertex(vmwareManagementServer + "/" + network, moIdToName.get(network));
            networkVertex.setParent(datacenterVertex);
            connectVertices(vmwareManagementServer + "/" + vmwareManagedObjectId + "->" + network, hostSystemVertex, networkVertex);
        }
        for (String datastore : datastores) {
            AbstractVertex datastoreVertex = addDatastoreVertex(vmwareManagementServer + "/" + datastore, moIdToName.get(datastore));
            datastoreVertex.setParent(datacenterVertex);
            connectVertices(vmwareManagementServer + "/" + vmwareManagedObjectId + "->" + datastore, hostSystemVertex, datastoreVertex);
        }
    }

    private void addVirtualMachine(OnmsNode virtualMachine) {
        // getting data for nodes

        String vmwareManagementServer = virtualMachine.getAssetRecord().getVmwareManagementServer().trim();
        String vmwareManagedObjectId = virtualMachine.getAssetRecord().getVmwareManagedObjectId().trim();
        String vmwareTopologyInfo = virtualMachine.getAssetRecord().getVmwareTopologyInfo().trim();
        String vmwareState = virtualMachine.getAssetRecord().getVmwareState().trim();

        String datacenterMoId = null;
        String datacenterName = "Datacenter (" + vmwareManagementServer + ")";

        String vmwareHostSystemId = null;

        ArrayList<String> networks = new ArrayList<String>();
        ArrayList<String> datastores = new ArrayList<String>();

        HashMap<String, String> moIdToName = new HashMap<String, String>();

        String entities[] = vmwareTopologyInfo.split(SPLIT_REGEXP);

        for (String entityAndName : entities) {
            String splitBySlash[] = entityAndName.split("/");
            String entityId = splitBySlash[0];

            String entityName = "unknown";

            if (splitBySlash.length > 1) {
                try {
                    entityName = new String(URLDecoder.decode(splitBySlash[1], "UTF-8"));
                } catch (UnsupportedEncodingException e) {
                    e.printStackTrace();
                }
            }

            String entityType = entityId.split("-")[0];

            if ("network".equals(entityType)) {
                networks.add(entityId);
            }

            if ("datastore".equals(entityType)) {
                datastores.add(entityId);
            }

            if ("datacenter".equals(entityType)) {
                datacenterMoId = entityId;
            }

            if ("host".equals(entityType)) {
                vmwareHostSystemId = entityId;
            }

            moIdToName.put(entityId, entityName);
        }

        if (datacenterMoId != null) {
            datacenterName = moIdToName.get(datacenterMoId) + " (" + vmwareManagementServer + ")";
        }

        if (vmwareHostSystemId == null) {
            System.err.println("Cannot find host system id for virtual machine " + vmwareManagementServer + "/" + vmwareManagedObjectId);
        }

        AbstractVertex datacenterVertex = addDatacenterGroup(vmwareManagementServer, datacenterName);

        String primaryInterface = "unknown";

        // get the primary interface ip address

        OnmsIpInterface ipInterface = m_ipInterfaceDao.findPrimaryInterfaceByNodeId(virtualMachine.getId());

        if (ipInterface != null) {
            primaryInterface = ipInterface.getIpHostName();
        }

        // add a vertex for the virtual machine
        AbstractVertex virtualMachineVertex = addVirtualMachineVertex(vmwareManagementServer + "/" + vmwareManagedObjectId, virtualMachine.getLabel(), primaryInterface, virtualMachine.getId(), vmwareState);

        if (containsVertexId(vmwareManagementServer + "/" + vmwareHostSystemId)) {
            // and set the parent vertex
            virtualMachineVertex.setParent(datacenterVertex);
        } else {
            addHostSystemVertex(vmwareManagementServer + "/" + vmwareHostSystemId, moIdToName.get(vmwareHostSystemId) + " (not in database)", "", -1, "unknown");
        }

        // connect the virtual machine to the host system
        connectVertices(vmwareManagementServer + "/" + vmwareManagedObjectId + "->" + vmwareManagementServer + "/" + vmwareHostSystemId, virtualMachineVertex, getVertex(getVertexNamespace(), vmwareManagementServer + "/" + vmwareHostSystemId));
    }

    public void generate() {
        m_generated = true;

        // reset container
        resetContainer();

        // get all host systems
        List<OnmsNode> hostSystems = m_nodeDao.findAllByVarCharAssetColumn("vmwareManagedEntityType", "HostSystem");

        if (hostSystems.size() == 0) {
            System.err.println("No host systems with defined VMware assets fields found!");
        } else {
            for (OnmsNode hostSystem : hostSystems) {
                addHostSystem(hostSystem);
            }
        }

        // get all virtual machines
        List<OnmsNode> virtualMachines = m_nodeDao.findAllByVarCharAssetColumn("vmwareManagedEntityType", "VirtualMachine");

        if (virtualMachines.size() == 0) {
            System.err.println("No virtual machines with defined VMware assets fields found!");
        } else {
            for (OnmsNode virtualMachine : virtualMachines) {
                addVirtualMachine(virtualMachine);
            }
        }

        debugAll();
    }

    @Override
    public void load(String filename) throws MalformedURLException, JAXBException {
        if (filename == null) {
            generate();
        } else {
            super.load(filename);
        }
    }
}
