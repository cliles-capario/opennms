/*
 * This file is part of the OpenNMS(R) Application.
 *
 * OpenNMS(R) is Copyright (C) 2006 The OpenNMS Group, Inc.  All rights reserved.
 * OpenNMS(R) is a derivative work, containing both original code, included code and modified
 * code that was published under the GNU General Public License. Copyrights for modified
 * and included code are below.
 *
 * OpenNMS(R) is a registered trademark of The OpenNMS Group, Inc.
 *
 * Modifications:
 *
 * 2007 Apr 09: This file was created. - dj@opennms.org
 *
 * Copyright (C) 2007 The OpenNMS Group, Inc.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 * For more information contact:
 *      OpenNMS Licensing       <license@opennms.org>
 *      http://www.opennms.org/
 *      http://www.opennms.com/
 */
package org.opennms.netmgt.dao.castor;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;

import org.apache.commons.io.IOUtils;
import org.apache.log4j.Category;
import org.opennms.core.utils.ThreadCategory;
import org.opennms.netmgt.dao.support.FileReloadCallback;
import org.opennms.netmgt.dao.support.FileReloadContainer;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.core.io.Resource;
import org.springframework.util.Assert;

/**
 * 
 * @author <a href="mailto:dj@gregor.com">DJ Gregor</a>
 *
 * @param <K> Castor class
 * @param <V> Configuration object that is stored in memory (might be the same
 *            as the Castor class or could be a different class)
 */
public abstract class AbstractCastorConfigDao<K, V> implements InitializingBean {
    private static final CastorExceptionTranslator CASTOR_EXCEPTION_TRANSLATOR = new CastorExceptionTranslator();
    
    private Class<K> m_castorClass;
    private Resource m_configResource;
    private FileReloadContainer<V> m_container;
    private CastorReloadCallback m_callback = new CastorReloadCallback();

    public AbstractCastorConfigDao(Class<K> entityClass) {
        super();
        
        m_castorClass = entityClass;
    }

    public abstract V translateConfig(K castorConfig);

    protected Category log() {
        return ThreadCategory.getInstance();
    }

    protected V loadConfig(Resource resource) {
        Reader reader;
        try {
            reader = new InputStreamReader(resource.getInputStream());
        } catch (IOException e) {
            throw CASTOR_EXCEPTION_TRANSLATOR.translate("opening XML configuration file for resource '" + resource + "'", e);
        }
    
        V config;
        try {
            log().debug("loading configuration");
            K castorConfig = CastorUtils.unmarshalWithTranslatedExceptions(m_castorClass, reader);
            config = translateConfig(castorConfig);
            log().debug("configuration loaded");
        } finally {
            IOUtils.closeQuietly(reader);
        }
        
        return config;
    }

    public void afterPropertiesSet() {
        Assert.state(m_configResource != null, "property configResource must be set and be non-null");
    
        V config = loadConfig(m_configResource);
        m_container = new FileReloadContainer<V>(config, m_configResource, m_callback);
    }

    public Resource getConfigResource() {
        return m_configResource;
    }

    public void setConfigResource(Resource configResource) {
        m_configResource = configResource;
    }
    
    protected FileReloadContainer<V> getContainer() {
        return m_container;
    }
    
    public class CastorReloadCallback implements FileReloadCallback<V> {
        public V reload(V object, Resource resource) {
            return loadConfig(resource);
        }
    }
}