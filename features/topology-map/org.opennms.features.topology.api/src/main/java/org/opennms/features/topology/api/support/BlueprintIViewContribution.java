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

package org.opennms.features.topology.api.support;

import org.opennms.features.topology.api.IViewContribution;
import org.opennms.features.topology.api.WidgetContext;
import org.opennms.osgi.EventProxy;
import org.opennms.osgi.EventProxyAware;
import org.opennms.osgi.VaadinApplicationContext;
import org.opennms.osgi.VaadinApplicationContextAware;
import org.osgi.framework.BundleContext;
import org.osgi.service.blueprint.container.BlueprintContainer;

import com.vaadin.server.Resource;
import com.vaadin.ui.Component;

public class BlueprintIViewContribution implements IViewContribution {
    private final BlueprintContainer m_container;
    private final String m_beanId;
    private String m_title;

    public BlueprintIViewContribution(final BlueprintContainer container, final String beanId) {
        m_container = container;
        m_beanId = beanId;
    }

    @Override
    public Component getView(final VaadinApplicationContext vaadinApplicationContext, final WidgetContext widgetContext) {
        // Get the component by asking the blueprint container to instantiate a prototype bean
        final Component component = (Component)m_container.getComponentInstance(m_beanId);
        final BundleContext bundleContext = (BundleContext) m_container.getComponentInstance("blueprintBundleContext");
        final EventProxy eventProxy = vaadinApplicationContext.getEventProxy(bundleContext);
        eventProxy.addPossibleEventConsumer(component);

        injectEventProxy(component, eventProxy);
        injectVaadinApplicationContext(component, vaadinApplicationContext);

        return component;
    }

    private void injectEventProxy(final Component component, final EventProxy eventProxy) {
        if(component instanceof EventProxyAware){
            ((EventProxyAware)component).setEventProxy(eventProxy);
        }
    }

    private void injectVaadinApplicationContext(final Component component, final VaadinApplicationContext vaadinApplicationContext) {
        if (component instanceof VaadinApplicationContextAware) {
            ((VaadinApplicationContextAware)component).setVaadinApplicationContext(vaadinApplicationContext);
        }
    }

    @Override
    public Resource getIcon() {
        return null;
    }

    @Override
    public String getTitle() {
        return m_title;
    }

    public void setTitle(String title) {
        m_title = title;
    }

    @Override
    public String toString() {
        return "BlueprintIViewContribution [container=" + m_container + ", beanId=" + m_beanId + ", title=" + m_title + "]";
    }
}
