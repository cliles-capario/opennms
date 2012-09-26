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

package org.opennms.netmgt.capsd.plugins;

import java.util.Map;

import org.opennms.core.utils.ParameterMap;
import org.opennms.core.utils.SocketWrapper;
import org.opennms.core.utils.SslSocketWrapper;

import com.novell.ldap.LDAPConnection;

/**
 * <P>
 * This class is designed to be used by the capabilities daemon to test for the
 * existance of an HTTPS server on remote interfaces. The class implements the
 * Plugin interface that allows it to be used along with other plugins by the
 * daemon.
 *
 * This plugin generates a HTTP GET request and checks the return code returned
 * by the remote host to determine if it supports the protocol.
 *
 * The remote host's response will be deemed valid if the return code falls in
 * the 100 to 599 range (inclusive).
 *
 * This is based on the following information from RFC 1945 (HTTP 1.0) HTTP 1.0
 * GET return codes: 1xx: Informational - Not used, future use 2xx: Success 3xx:
 * Redirection 4xx: Client error 5xx: Server error
 * </P>
 *
 * This plugin generates a HTTP GET request and checks the return code returned
 * by the remote host to determine if it supports the protocol.
 *
 * The remote host's response will be deemed valid if the return code falls in
 * the 100 to 599 range (inclusive).
 *
 * This is based on the following information from RFC 1945 (HTTP 1.0) HTTP 1.0
 * GET return codes: 1xx: Informational - Not used, future use 2xx: Success 3xx:
 * Redirection 4xx: Client error 5xx: Server error
 * </P>
 *
 * @author <A HREF="mailto:jason@opennms.org">Jason </A>
 * @author <A HREF="http://www.opennms.org">OpenNMS </A>
 */
public class LdapsPlugin extends LdapPlugin {

    private static final String PROTOCOL_NAME = "LDAPS";

    /**
     * <P>
     * The default ports on which the host is checked to see if it supports
     * HTTP.
     * </P>
     */
    private static final int[] DEFAULT_PORTS = { LDAPConnection.DEFAULT_SSL_PORT };

    /**
     * Returns the name of the protocol that this plugin checks on the target
     * system for support.
     *
     * @return The protocol name for this plugin.
     */
    @Override
    public String getProtocolName() {
        return PROTOCOL_NAME;
    }

    @Override
    protected int[] determinePorts(final Map<String, Object> parameters) {
        return ParameterMap.getKeyedIntegerArray(parameters, "port", DEFAULT_PORTS);
    }

    /** {@inheritDoc} */
    @Override
    protected SocketWrapper getSocketWrapper() {
        return new SslSocketWrapper();
    }
}
