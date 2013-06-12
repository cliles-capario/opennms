<%--
/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2008-2012 The OpenNMS Group, Inc.
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

--%>

<%@page language="java" contentType="text/html" session="true" %>
  
<%@page import="java.util.ArrayList" %>
<%@page import="java.util.List" %>

<%@page import="org.opennms.web.api.Util"%>
<%@page import="org.opennms.core.utils.InetAddressUtils" %>
<%@page import="org.opennms.core.utils.WebSecurityUtils" %>
<%@page import="org.opennms.web.servlet.XssRequestWrapper" %>
<%@page import="org.opennms.web.springframework.security.Authentication" %>

<%@page import="org.opennms.web.controller.alarm.AcknowledgeAlarmController" %>
<%@page import="org.opennms.web.controller.alarm.AlarmSeverityChangeController" %>
<%@page import="org.opennms.web.controller.alarm.AlarmReportController" %>
<%@page import="org.opennms.web.controller.alarm.AlarmPurgeController" %>
<%@page import="org.opennms.netmgt.model.OnmsAlarm"%>

<%@page import="org.opennms.web.filter.Filter" %>
<%@page import="org.opennms.web.alarm.AlarmQueryParms" %>
<%@page import="org.opennms.web.alarm.SortStyle" %>
<%@page import="org.opennms.web.alarm.AcknowledgeType" %>
<%@page import="org.opennms.web.alarm.AlarmUtil" %>
<%@page import="org.opennms.web.alarm.filter.ExactUEIFilter" %>
<%@page import="org.opennms.web.alarm.filter.NegativeExactUEIFilter" %>
<%@page import="org.opennms.web.alarm.filter.SeverityFilter" %>
<%@page import="org.opennms.web.alarm.filter.NegativeSeverityFilter" %>
<%@page import="org.opennms.web.alarm.filter.NodeFilter" %>
<%@page import="org.opennms.web.alarm.filter.NegativeNodeFilter" %>
<%@page import="org.opennms.web.alarm.filter.InterfaceFilter" %>
<%@page import="org.opennms.web.alarm.filter.NegativeInterfaceFilter" %>
<%@page import="org.opennms.web.alarm.filter.ServiceFilter" %>
<%@page import="org.opennms.web.alarm.filter.NegativeServiceFilter" %>
<%@page import="org.opennms.web.alarm.filter.AfterLastEventTimeFilter" %>
<%@page import="org.opennms.web.alarm.filter.BeforeLastEventTimeFilter" %>
<%@page import="org.opennms.web.alarm.filter.AfterFirstEventTimeFilter" %>
<%@page import="org.opennms.web.alarm.filter.BeforeFirstEventTimeFilter" %>
<%@page import="org.opennms.web.alarm.filter.NegativeAcknowledgedByFilter"%>
<%@page import="org.opennms.web.alarm.filter.AcknowledgedByFilter"%>

<%@taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>

<%--
  This page is written to be the display (view) portion of the AlarmQueryServlet
  at the /alarm/list.htm URL.  It will not work by itself, as it requires two request
  attributes be set:
  
  1) alarms: the list of {@link OnmsAlarm} instances to display
  2) parms: an org.opennms.web.alarm.AlarmQueryParms object that holds all the 
     parameters used to make this query
--%>

<%
    urlBase = (String) request.getAttribute("relativeRequestPath");

    XssRequestWrapper req = new XssRequestWrapper(request);

    //required attributes
    OnmsAlarm[] alarms = (OnmsAlarm[])req.getAttribute( "alarms" );
    int alarmCount = req.getAttribute("alarmCount") == null ? -1 : (Integer)req.getAttribute("alarmCount");
    AlarmQueryParms parms = (AlarmQueryParms)req.getAttribute( "parms" );

    if( alarms == null || parms == null ) {
        throw new ServletException( "Missing either the alarms or parms request attribute." );
    }

    // Make 'action' the opposite of the current acknowledgement state
    String action = AcknowledgeType.ACKNOWLEDGED.getShortName();
    if (parms.ackType != null && parms.ackType == AcknowledgeType.ACKNOWLEDGED) {
        action = AcknowledgeType.UNACKNOWLEDGED.getShortName();
    }

    pageContext.setAttribute("addPositiveFilter", "[+]");
    pageContext.setAttribute("addNegativeFilter", "[-]");
    pageContext.setAttribute("addBeforeFilter", "[&gt;]");
    pageContext.setAttribute("addAfterFilter", "[&lt;]");
    
    //Get the purge action status
    String actionStatus = (String) req.getSession().getAttribute("actionStatus");
    
    final String baseHref = org.opennms.web.api.Util.calculateUrlBase(request);
%>



<jsp:include page="/includes/header.jsp" flush="false" >
  <jsp:param name="title" value="Alarm List" />
  <jsp:param name="headTitle" value="List" />
  <jsp:param name="headTitle" value="Alarms" />
  <jsp:param name="breadcrumb" value="<a href='${baseHref}alarm/index.jsp' title='Alarms System Page'>Alarms</a>" />
  <jsp:param name="breadcrumb" value="List" />
</jsp:include>

<script type="text/javascript" src="<c:url value="/js/jquery/jquery.js"/>"></script>
<script type="text/javascript">
	function checkAllCheckboxes() {
	       if( document.alarm_action_form.alarm.length ) {  
			 for( i = 0; i < document.alarm_action_form.alarm.length; i++ ) {
				document.alarm_action_form.alarm[i].checked = true
			 }
	       }
	       else {
			document.alarm_action_form.alarm.checked = true
	       }
	}
	
	function submitForm(anAction)
	{
		var isChecked = false
		var numChecked = 0;
		var isAlarmAvailabilty = false;
		var isPurgeExport = true;
			
		// Decide to which servlet we will submit
		if (anAction == "clear" || anAction == "escalate") {
			document.alarm_action_form.action = "alarm/changeSeverity";
		} else if (anAction == "acknowledge" || anAction == "unacknowledge") {
			document.alarm_action_form.action = "alarm/acknowledge";
		} else if(anAction == "purge" || anAction == "purgeall"){
			document.alarm_action_form.action = "alarm/alarmPurge";
		} else if(anAction == "export" || anAction == "exportall") {
			document.alarm_action_form.action = "alarm/alarmExport";
		}
		
		// Decide what our action should be
		if (anAction == "escalate") {
			document.alarm_action_form.actionCode.value = "<%=AlarmSeverityChangeController.ESCALATE_ACTION%>";
		} else if (anAction == "clear") {
			document.alarm_action_form.actionCode.value = "<%=AlarmSeverityChangeController.CLEAR_ACTION%>";
		} else if (anAction == "acknowledge") {
			document.alarm_action_form.actionCode.value = "<%= AcknowledgeType.ACKNOWLEDGED.getShortName() %>";
		} else if (anAction == "unacknowledge") {
			document.alarm_action_form.actionCode.value = "<%= AcknowledgeType.UNACKNOWLEDGED.getShortName() %>";
		} else if (anAction == "purge") {
			document.alarm_action_form.actionCode.value = "<%=AlarmPurgeController.PURGE_ACTION%>";
		} else if (anAction == "purgeall") {
			document.alarm_action_form.actionCode.value = "<%=AlarmPurgeController.PURGEALL_ACTION%>";
		}else if (anAction == "export") {
			document.alarm_action_form.actionCode.value = "<%=AlarmReportController.EXPORT_ACTION%>";
		} else if (anAction == "exportall") {
			document.alarm_action_form.actionCode.value = "<%=AlarmReportController.EXPORTALL_ACTION%>";
		}
		  
		//Check the alarm availability
		for( i = 0; i < document.alarm_action_form.elements.length; i++ ) {
			if(document.alarm_action_form.elements[i].name == "alarm"){
				isAlarmAvailabilty = true;
			}
		}
		
		//Get the alarm count
		var alarmCount = <%=alarmCount%> ;
		if( (anAction == "purge" || anAction == "export" ) && isAlarmAvailabilty){
			alarmCount = 0;
			if (document.alarm_action_form.alarm.length)
			{	
				for( i = 0; i < document.alarm_action_form.alarm.length; i++ ) 
				{
					if (document.alarm_action_form.alarm[i].checked)
					{
						alarmCount+=1;
					}
				}
			}else{
				if (document.alarm_action_form.alarm.checked)
				{
					alarmCount+=1;
				}
			}
		}
		
		//Get the confirmation status for purge action
		var regularNoun = (parseInt(alarmCount) == 1)?'alarm':'alarms';
		var confirmText = (anAction=="purge" || anAction=="export" )? 'Are you sure you want to '+anAction+' selected '+regularNoun+' ? ('+alarmCount+' total '+regularNoun+')' : 'Are you sure you want to '+anAction+' '+regularNoun+' ? ('+alarmCount+' total '+regularNoun+')';
		if((anAction == "purge" || anAction == "purgeall") && parseInt(alarmCount)>0) {
			if(confirm(confirmText)){
				isPurgeExport = true;
			}else{
				isPurgeExport = false;
			}
		}
		
		//Get the confirmation status for export action
		if((anAction == "export" || anAction == "exportall") && parseInt(alarmCount)>0) {
			isPurgeExport = false;
			showPopup(confirmText);
		}
		
		if(isPurgeExport)
		if(isAlarmAvailabilty){
			if(anAction != "purgeall"){
				if (document.alarm_action_form.alarm.length)
				{
					for( i = 0; i < document.alarm_action_form.alarm.length; i++ ) 
					{
						//make sure something is checked before proceeding
						if (document.alarm_action_form.alarm[i].checked)
						{
							isChecked=true;
							numChecked+=1;
						}
					}
				    
				    if (isChecked && document.alarm_action_form.multiple)
				    {
					if (numChecked == parseInt(document.alarm_action_form.alarm.length)) 
					{ 
						var newPageNum = parseInt(document.alarm_action_form.multiple.value) - 1;
						var findVal = "multiple=" + document.alarm_action_form.multiple.value;
						var replaceWith = "multiple=" + newPageNum;
						var tmpRedirect = document.alarm_action_form.redirectParms.value;
						document.alarm_action_form.redirectParms.value = tmpRedirect.replace(findVal, replaceWith);
						document.alarm_action_form.submit();
					} else {
						document.alarm_action_form.submit();
					}
					if(anAction == "purge")
					getProgressBar();
					}
				    else if (isChecked)
				    {
					document.alarm_action_form.submit();
					if(anAction == "purge")
					getProgressBar();
				    }
				    else
				    {
					alert("Please check the alarms that you would like to " + anAction + ".");
				    }
				}else{
				    if (document.alarm_action_form.alarm.checked)
				    {
					document.alarm_action_form.submit();
					if(anAction == "purge")
					getProgressBar();
				    }
				    else
				    {
					alert("Please check the alarms that you would like to " + anAction + ".");
				    }
				}
			}else{
				document.alarm_action_form.submit();
				getProgressBar();
			}
		}else{
			alert("There is currently no alarms for this category to " + anAction + ".");
		}
	}
    
	// Progress bar for purge and export action
	progressBar(100, $('#progressBar'));
	
	</script>
  
      <!-- menu -->
      <div id="linkbar">
      <ul>
      <li><a href="<%=this.makeLink( parms, new ArrayList<Filter>())%>" title="Remove all search constraints" >View all alarms</a></li>
      <li><a href="alarm/advsearch.jsp" title="More advanced searching and sorting options">Advanced Search</a></li>
      <c:choose>
        <c:when test="${param.display == 'long'}">
      <li><a href="<%=this.makeLink(parms, "short")%>" title="Summary List of Alarms">Short Listing</a></li>
        </c:when>
        <c:otherwise>
      <li><a href="<%=this.makeLink(parms, "long")%>" title="Detailed List of Alarms">Long Listing</a></li>
        </c:otherwise>
      </c:choose>
      <li><a href="javascript:void()" onclick="javascript:window.open('<%=Util.calculateUrlBase(req, "alarm/severity.jsp")%>','', 'fullscreen=no,toolbar=no,status=no,menubar=no,scrollbars=no,resizable=yes,directories=no,location=no,width=525,height=158')" title="Open a window explaining the alarm severities">Severity Legend</a></li>
      
      <% if( req.isUserInRole( Authentication.ROLE_ADMIN ) || !req.isUserInRole( Authentication.ROLE_READONLY ) ) { %>
        <% if ( alarmCount > 0 ) { %>
          <li>
            <!-- hidden form for acknowledging the result set -->
            <form style="display:inline" method="post" action="<%= Util.calculateUrlBase(req, "alarm/acknowledgeByFilter") %>" name="acknowledge_by_filter_form">
              <input type="hidden" name="redirectParms" value="<c:out value="<%=req.getQueryString()%>"/>" />
              <input type="hidden" name="actionCode" value="<%=action%>" />
              <%=Util.makeHiddenTags(req)%>
            </form>
            <% if( parms.ackType == AcknowledgeType.UNACKNOWLEDGED ) { %> 
              <a href="javascript:void()" onclick="if (confirm('Are you sure you want to acknowledge all alarms in the current search including those not shown on your screen?  (<%=alarmCount%> total alarms)')) { document.acknowledge_by_filter_form.submit(); }" title="Acknowledge all alarms that match the current search constraints, even those not shown on the screen">Acknowledge entire search</a>
            <% } else { %>
              <a href="javascript:void()" onclick="if (confirm('Are you sure you want to unacknowledge all alarms in the current search including those not shown on your screen)?  (<%=alarmCount%> total alarms)')) { document.acknowledge_by_filter_form.submit(); }" title="Unacknowledge all alarms that match the current search constraints, even those not shown on the screen">Unacknowledge entire search</a>
            <% } %>
          </li>
        <% } %>
      <% } %>
      </ul>
      </div>
      <!-- end menu -->


            <jsp:include page="/includes/alarm-querypanel.jsp" flush="false" />
          
            <% if( alarmCount > 0 ) { %>
              <% String baseUrl = this.makeLink(parms); %>
              <jsp:include page="/includes/resultsIndex.jsp" flush="false" >
                <jsp:param name="count"    value="<%=alarmCount%>" />
                <jsp:param name="baseurl"  value="<%=baseUrl%>"    />
                <jsp:param name="limit"    value="<%=parms.limit%>"      />
                <jsp:param name="multiple" value="<%=parms.multiple%>"   />
              </jsp:include>
            <% } %>          


            <% if( parms.filters.size() > 0 || parms.ackType == AcknowledgeType.UNACKNOWLEDGED || parms.ackType == AcknowledgeType.ACKNOWLEDGED ) { %>
              <% int length = parms.filters.size(); %>
              <p>Search constraints:
                  <% if( parms.ackType == AcknowledgeType.UNACKNOWLEDGED ) { %>
                    <span class="filter">alarm is outstanding <a href="<%=this.makeLink(parms, AcknowledgeType.ACKNOWLEDGED)%>" title="Show acknowledged alarms">[-]</a></span>
                  <% } else if( parms.ackType == AcknowledgeType.ACKNOWLEDGED ) { %>
                    <span class="filter">alarm is acknowledged <a href="<%=this.makeLink(parms, AcknowledgeType.UNACKNOWLEDGED)%>" title="Show outstanding alarms">[-]</a></span>
                  <% } %>            
                
                  <% for( int i=0; i < length; i++ ) { %>
                    <% Filter filter = parms.filters.get(i); %>
                    &nbsp; <span class="filter"><%=WebSecurityUtils.sanitizeString(filter.getTextDescription())%> <a href="<%=this.makeLink( parms, filter, false)%>" title="Remove filter">[-]</a></span>
                  <% } %>
              </p>           
            <% } %>

	<!-- Popup message box for alarm export action -->
	<div id="exportConfirmation" style="display:none">
		<center>
			<div id="alertText">&nbsp;</div><br>
			Select your file format : 
			<input type="radio" name="format" value="PDF" checked="checked">PDF
			<!-- <input type="radio" name="format" value="XLS">XLS -->
			<input type="radio" name="format" value="HTML">HTML
			<input type="radio" name="format" value="CSV">CSV<br><br>
			<input type="button" onclick="javascript:callExportAction();" value="Ok" />
			<input type="button" onclick="javascript:hideTransBackground();" value="Cancel"/>
		</center>
	</div>
	
      <% if( req.isUserInRole( Authentication.ROLE_ADMIN ) || !req.isUserInRole( Authentication.ROLE_READONLY ) ) { %>
          <form action="<%= Util.calculateUrlBase(request, "alarm/acknowledge") %>" method="post" name="alarm_action_form">
          <input type="hidden" name="redirectParms" value="<c:out value="<%=req.getQueryString()%>"/>" />
          <input type="hidden" name="actionCode" value="<%=action%>" />
	  
	  <!-- Hidden datas for alarm purge and export action-->
	  <input type="hidden" name="nodeid" value="node=" />
	  <input type="hidden" name="exactuei" value="exactUei=" />
	  <input type="hidden" name="ipaddress" value="interface=" />
	  <input type="hidden" name="format" value="pdf" />
	  <input type="hidden" name="reportId" value="local_alarm-report" />
	  <div id="progressBar" class="jquery-ui-like"><div><center>Action in progress, Please wait...</center></div></div>
	  <div id="backgroundPopup"></div><body/>
	  
          <%=Util.makeHiddenTags(req)%>
      <% } %>
			<jsp:include page="/includes/key.jsp" flush="false" />
      <table>
		<thead>
			<tr>
			     <% if( req.isUserInRole( Authentication.ROLE_ADMIN ) || !req.isUserInRole( Authentication.ROLE_READONLY ) ) { %>
					<% if ( parms.ackType == AcknowledgeType.UNACKNOWLEDGED ) { %>
					<th width="3%"><nobr>Ack</nobr></th>
					<% } else if ( parms.ackType == AcknowledgeType.ACKNOWLEDGED ) { %>
					<th width="3%"><nobr>UnAck</nobr></th>
					<% } else if ( parms.ackType == AcknowledgeType.BOTH ) { %>
					<th width="3%"><nobr>Ack?</nobr></th>
					<% } %>
				<% } else { %>
					<th width="1%">&nbsp;</th>
				<% } %>

				<th width="8%">
					<%=this.makeSortLink( parms, SortStyle.ID,        SortStyle.REVERSE_ID,        "id",        "ID" )%>
					<br />
					<%=this.makeSortLink( parms, SortStyle.SEVERITY,  SortStyle.REVERSE_SEVERITY,  "severity",  "Severity"  )%>
				</th>
	  
				<th width="19%">
				      <%=this.makeSortLink( parms, SortStyle.NODE,      SortStyle.REVERSE_NODE,      "node",      "Node"      )%>
				      <c:if test="${param.display == 'long'}">
				      <br />
				      <%=this.makeSortLink( parms, SortStyle.INTERFACE, SortStyle.REVERSE_INTERFACE, "interface", "Interface" )%>
				      <br />
				      <%=this.makeSortLink( parms, SortStyle.SERVICE,   SortStyle.REVERSE_SERVICE,   "service",   "Service"   )%>
				      </c:if>
				</th>
	     
				<th width="3%">
					<%=this.makeSortLink( parms, SortStyle.COUNT,  SortStyle.REVERSE_COUNT,  "count",  "Count"  )%>
				</th>
	
				<th width="20%">
				      <%=this.makeSortLink( parms, SortStyle.LASTEVENTTIME,  SortStyle.REVERSE_LASTEVENTTIME,  "lasteventtime",  "Last Event Time"  )%>
				      <c:if test="${param.display == 'long'}">
				      <br />
				      <%=this.makeSortLink( parms, SortStyle.FIRSTEVENTTIME,  SortStyle.REVERSE_FIRSTEVENTTIME,  "firsteventtime",  "First Event Time"  )%>
				      <br />
				      <% if ( parms.ackType == AcknowledgeType.ACKNOWLEDGED ) { %>
				      <%=this.makeSortLink( parms, SortStyle.ACKUSER,  SortStyle.REVERSE_ACKUSER,  "ackuser",  "Acknowledged By"  )%>
				      <% } %>
				      </c:if>
				</th>
				<th width="48%">Description</th>
			</tr>
		</thead>


		<% for( int i=0; i < alarms.length; i++ ) { 
			pageContext.setAttribute("alarm", alarms[i]);
		%> 

		<tr class="<%=alarms[i].getSeverity().getLabel()%>">
			<% if( parms.ackType == AcknowledgeType.BOTH ) { %>
              <td class="divider" valign="middle" rowspan="1">
                <nobr>
                  <input type="checkbox" name="alarm" disabled="true" <%=alarms[i].isAcknowledged() ? "checked='true'" : ""%> /> 
                </nobr>
          <% } else if( req.isUserInRole( Authentication.ROLE_ADMIN ) || !req.isUserInRole( Authentication.ROLE_READONLY ) ) { %>
              <td class="divider" valign="middle" rowspan="1">
                <nobr>
                  <input type="checkbox" name="alarm" value="<%=alarms[i].getId()%>" /> 
                </nobr>
          <% } else { %>
            <td valign="middle" rowspan="1" class="divider">&nbsp;
          <% } %>
          </td>

          
          <td class="divider bright" valign="middle" rowspan="1">
	  
	   <!-- Get the events details for this Alarm Id -->
          <a style="vertical-align:middle" href="alarm/detail.htm?id=<%=alarms[i].getId()%>"><%=alarms[i].getId()%></a>
	   
	<c:if test="<%= alarms[i].getStickyMemo() != null && alarms[i].getStickyMemo().getId() != null%>">
                <img style="vertical-align:middle" src="images/AlarmMemos/StickyMemo.png" width="20" height="20" 
		     title="<%=alarms[i].getStickyMemo().getBody() %>"/>
            </c:if>
            <c:if test="<%= alarms[i].getReductionKeyMemo() != null && alarms[i].getReductionKeyMemo().getId() != null%>">
                <img style="vertical-align:middle" src="images/AlarmMemos/JournalMemo.png" width="20" height="20" 
                     title="<%=alarms[i].getReductionKeyMemo().getBody() %>"/>
            </c:if>

          <c:if test="${param.display == 'long'}">
            <% if(alarms[i].getUei() != null) { %>
              <% Filter exactUEIFilter = new ExactUEIFilter(alarms[i].getUei()); %>
                <br />UEI
              <% if( !parms.filters.contains( exactUEIFilter )) { %>
                <nobr>
                  <a href="<%=this.makeLink( parms, exactUEIFilter, true)%>" class="filterLink" title="Show only events with this UEI">${addPositiveFilter}</a>
                  <a href="<%=this.makeLink( parms, new NegativeExactUEIFilter(alarms[i].getUei()), true)%>" class="filterLink" title="Do not show events for this UEI">${addNegativeFilter}</a>
                </nobr>
              <% } %>
            <% } else { %>
              &nbsp;
            <% } %>
            <% Filter severityFilter = new SeverityFilter(alarms[i].getSeverity()); %>      
            <% if( !parms.filters.contains( severityFilter )) { %>
		<br />Sev.
              <nobr>
                <a href="<%=this.makeLink( parms, severityFilter, true)%>" class="filterLink" title="Show only alarms with this severity">${addPositiveFilter}</a>
                <a href="<%=this.makeLink( parms, new NegativeSeverityFilter(alarms[i].getSeverity()), true)%>" class="filterLink" title="Do not show alarms with this severity">${addNegativeFilter}</a>

              </nobr>
            <% } %>
          </c:if>
          </td>
          <td class="divider">
	    <% if(alarms[i].getNodeId() != null && alarms[i].getNodeLabel()!= null ) { %>
              <% Filter nodeFilter = new NodeFilter(alarms[i].getNodeId(), getServletContext()); %>             
              <% String[] labels = this.getNodeLabels( alarms[i].getNodeLabel() ); %>
              <a href="element/node.jsp?node=<%=alarms[i].getNodeId()%>" title="<%=labels[1]%>"><%=labels[0]%></a>
                    
              <% if( !parms.filters.contains(nodeFilter) ) { %>
                <nobr>
                  <a href="<%=this.makeLink( parms, nodeFilter, true)%>" class="filterLink" title="Show only alarms on this node">${addPositiveFilter}</a>
                  <a href="<%=this.makeLink( parms, new NegativeNodeFilter(alarms[i].getNodeId(), getServletContext()), true)%>" class="filterLink" title="Do not show alarms for this node">${addNegativeFilter}</a>
                </nobr>
              <% } %>
            <% } else { %>
              &nbsp;
            <% } %>
          <c:if test="${param.display == 'long'}">
		<br />
            <% if(alarms[i].getIpAddr() != null ) { %>
              <% Filter intfFilter = new InterfaceFilter(alarms[i].getIpAddr()); %>
              <% if( alarms[i].getNodeId() != null ) { %>
                <c:url var="interfaceLink" value="element/interface.jsp">
                  <c:param name="node" value="<%=String.valueOf(alarms[i].getNodeId())%>"/>
                  <c:param name="intf" value="<%=InetAddressUtils.str(alarms[i].getIpAddr())%>"/>
                </c:url>
                <a href="<c:out value="${interfaceLink}"/>" title="More info on this interface"><%=InetAddressUtils.str(alarms[i].getIpAddr())%></a>
              <% } else { %>
                <%=InetAddressUtils.str(alarms[i].getIpAddr())%>
              <% } %>
              <% if( !parms.filters.contains(intfFilter) ) { %>
                <nobr>
                  <a href="<%=this.makeLink( parms, intfFilter, true)%>" class="filterLink" title="Show only alarms on this IP address">${addPositiveFilter}</a>
                  <a href="<%=this.makeLink( parms, new NegativeInterfaceFilter(alarms[i].getIpAddr()), true)%>" class="filterLink" title="Do not show alarms for this interface">${addNegativeFilter}</a>
                </nobr>
              <% } %>
            <% } else { %>
              &nbsp;
            <% } %>
          <br />
            <% if(alarms[i].getServiceType() != null && !"".equals(alarms[i].getServiceType().getName())) { %>
              <% Filter serviceFilter = new ServiceFilter(alarms[i].getServiceType().getId()); %>
              <% if( alarms[i].getNodeId() != null && alarms[i].getIpAddr() != null ) { %>
                <c:url var="serviceLink" value="element/service.jsp">
                  <c:param name="node" value="<%=String.valueOf(alarms[i].getNodeId())%>"/>
                  <c:param name="intf" value="<%=InetAddressUtils.str(alarms[i].getIpAddr())%>"/>
                  <c:param name="service" value="<%=String.valueOf(alarms[i].getServiceType().getId())%>"/>
                </c:url>
                <a href="<c:out value="${serviceLink}"/>" title="More info on this service"><c:out value="<%=alarms[i].getServiceType().getName()%>"/></a>
              <% } else { %>
                <c:out value="<%=alarms[i].getServiceType().getName()%>"/>
              <% } %>
              <% if( !parms.filters.contains( serviceFilter )) { %>
                <nobr>
                  <a href="<%=this.makeLink( parms, serviceFilter, true)%>" class="filterLink" title="Show only alarms with this service type">${addPositiveFilter}</a>
                  <a href="<%=this.makeLink( parms, new NegativeServiceFilter(alarms[i].getServiceType().getId()), true)%>" class="filterLink" title="Do not show alarms for this service">${addNegativeFilter}</a>
                </nobr>
              <% } %>                            
            <% } %>
            </c:if>
          </td>          
          <td class="divider" valign="middle" rowspan="1" >
	    <% if(alarms[i].getId() > 0 ) { %>           
                <nobr>
                  <a href="event/list.htm?sortby=id&amp;acktype=unack&amp;filter=alarm%3d<%=alarms[i].getId()%>"><%=alarms[i].getCounter()%></a>
                </nobr>
            <% } else { %>
            <%=alarms[i].getCounter()%>
            <% } %>
          </td>
          <td class="divider">
            <nobr><span title="Event <%= alarms[i].getLastEvent().getId()%>"><a href="event/detail.htm?id=<%= alarms[i].getLastEvent().getId()%>"><fmt:formatDate value="${alarm.lastEventTime}" type="date" dateStyle="short"/>&nbsp;<fmt:formatDate value="${alarm.lastEventTime}" type="time" pattern="HH:mm:ss"/></a></span></nobr>
            <nobr>
              <a href="<%=this.makeLink( parms, new AfterLastEventTimeFilter(alarms[i].getLastEventTime()), true)%>"  class="filterLink" title="Only show alarms occurring after this one">${addAfterFilter}</a>            
              <a href="<%=this.makeLink( parms, new BeforeLastEventTimeFilter(alarms[i].getLastEventTime()), true)%>" class="filterLink" title="Only show alarms occurring before this one">${addBeforeFilter}</a>
            </nobr>
          <c:if test="${param.display == 'long'}">
          <br />
            <nobr><fmt:formatDate value="${alarm.firstEventTime}" type="date" dateStyle="short"/>&nbsp;<fmt:formatDate value="${alarm.firstEventTime}" type="time" pattern="HH:mm:ss"/></nobr>
            <nobr>
              <a href="<%=this.makeLink( parms, new AfterFirstEventTimeFilter(alarms[i].getFirstEventTime()), true)%>"  class="filterLink" title="Only show alarms occurring after this one">${addAfterFilter}</a>            
              <a href="<%=this.makeLink( parms, new BeforeFirstEventTimeFilter(alarms[i].getFirstEventTime()), true)%>" class="filterLink" title="Only show alarms occurring before this one">${addBeforeFilter}</a>
            </nobr>
          <br />
              <% if ( parms.ackType == AcknowledgeType.ACKNOWLEDGED ) { %>
			<nobr><%=alarms[i].getAckUser()%></nobr>          
            <nobr>
              <a href="<%=this.makeLink( parms, new AcknowledgedByFilter(alarms[i].getAckUser()), true)%>"  class="filterLink" title="Only show alarms ack by this user">${addPositiveFilter}</a>            
              <a href="<%=this.makeLink( parms, new NegativeAcknowledgedByFilter(alarms[i].getAckUser()), true)%>" class="filterLink" title="Only show alarms ack by other users">${addNegativeFilter}</a>
            </nobr>
			<% }%>
          </c:if>
          </td>
          <td class="divider"><%=this.getTextDesc(alarms[i].getDescription())%></td>
       </tr> 
      <% } /*end for*/%>
	
      </table>
			<hr />
			 <p><%=alarms.length%> alarms &nbsp;
      <% if( req.isUserInRole( Authentication.ROLE_ADMIN ) || !req.isUserInRole( Authentication.ROLE_READONLY ) ) { %>
          <input TYPE="reset" />
          <input TYPE="button" VALUE="Select All" onClick="checkAllCheckboxes()"/>
          <select name="alarmAction">
        <% if( parms.ackType == AcknowledgeType.UNACKNOWLEDGED ) { %>
          <option value="acknowledge">Acknowledge Alarms</option>
        <% } else if( parms.ackType == AcknowledgeType.ACKNOWLEDGED ) { %>
          <option value="unacknowledge">Unacknowledge Alarms</option>
        <% } %>
          <option value="clear">Clear Alarms</option>
          <option value="escalate">Escalate Alarms</option>
	 <!--
	  <optgroup label="Export Alarms">
	        <option value="exportall">Export All</option>
          	<option value="export">Export Selected</option>
	   </optgroup>
	  <optgroup label="Purge Alarms">
	        <option value="purgeall">Purge All</option>
          	<option value="purge">Purge Selected</option>
	   </optgroup>
	  -->
          </select>
          <input type="button" value="Go" onClick="submitForm(document.alarm_action_form.alarmAction.value)" />
      <% } %>
        </p>
      </form>

      <%--<br/>
      <% if(req.isUserInRole(Authentication.ROLE_ADMIN)) { %>
        <a HREF="admin/alarms.jsp" title="Acknowledge or Unacknowledge All Alarms">[Acknowledge or Unacknowledge All Alarms]</a>
      <% } %>--%>

 <!-- id="eventlist" -->

            <% if( alarmCount > 0 ) { %>
              <% String baseUrl = this.makeLink(parms); %>
              <jsp:include page="/includes/resultsIndex.jsp" flush="false" >
                <jsp:param name="count"    value="<%=alarmCount%>" />
                <jsp:param name="baseurl"  value="<%=baseUrl%>"    />
                <jsp:param name="limit"    value="<%=parms.limit%>"      />
                <jsp:param name="multiple" value="<%=parms.multiple%>"   />
              </jsp:include>
            <% } %>


<jsp:include page="/includes/bookmark.jsp" flush="false" />
<jsp:include page="/includes/footer.jsp" flush="false" />


<%!
    String urlBase;

    protected String makeSortLink( AlarmQueryParms parms, SortStyle style, SortStyle revStyle, String sortString, String title ) {
      StringBuffer buffer = new StringBuffer();

      buffer.append( "<nobr>" );
      
      if( parms.sortStyle == style ) {
          buffer.append( "<img src=\"images/arrowdown.gif\" hspace=\"0\" vspace=\"0\" border=\"0\" alt=\"" );
          buffer.append( title );
          buffer.append( " Ascending Sort\"/>" );
          buffer.append( "&nbsp;<a href=\"" );
          buffer.append( this.makeLink( parms, revStyle ));
          buffer.append( "\" title=\"Reverse the sort\">" );
      } else if( parms.sortStyle == revStyle ) {
          buffer.append( "<img src=\"images/arrowup.gif\" hspace=\"0\" vspace=\"0\" border=\"0\" alt=\"" );
          buffer.append( title );
          buffer.append( " Descending Sort\"/>" );
          buffer.append( "&nbsp;<a href=\"" );
          buffer.append( this.makeLink( parms, style )); 
          buffer.append( "\" title=\"Reverse the sort\">" );
      } else {
          buffer.append( "<a href=\"" );
          buffer.append( this.makeLink( parms, style ));
          buffer.append( "\" title=\"Sort by " );
          buffer.append( sortString );
          buffer.append( "\">" );   
      }

      buffer.append( title );
      buffer.append( "</a>" );

      buffer.append( "</nobr>" );

      return( buffer.toString() );
    }

    
    public String getFiltersAsString(List<Filter> filters ) {
        StringBuffer buffer = new StringBuffer();
    
        if( filters != null ) {
            for( int i=0; i < filters.size(); i++ ) {
                buffer.append( "&amp;filter=" );
                String filterString = AlarmUtil.getFilterString(filters.get(i));
                buffer.append(Util.encode(filterString));
            }
        }      
    
        return( buffer.toString() );
    }
    
    public String makeLink( SortStyle sortStyle, AcknowledgeType ackType, List<Filter> filters, int limit, String display ) {
      StringBuffer buffer = new StringBuffer( this.urlBase );
      buffer.append( "?sortby=" );
      buffer.append( sortStyle.getShortName() );
      buffer.append( "&amp;acktype=" );
      buffer.append( ackType.getShortName() );
      if (limit > 0) {
          buffer.append( "&amp;limit=" ).append(limit);
      }
      if (display != null) {
          buffer.append( "&amp;display=" ).append(display);
      }
      buffer.append( this.getFiltersAsString(filters) );

      return( buffer.toString() );
    }

    public String eventMakeLink( AlarmQueryParms parms, Filter filter, boolean add ) {
      List<Filter> filters = new ArrayList<Filter>( parms.filters );
      if( add ) {
        filters.add( filter );
      }
      else {
        filters.remove( filter );
      }
      StringBuffer buffer = new StringBuffer( "event/list.htm" );
      buffer.append( "?sortby=" );
      buffer.append( parms.sortStyle.getShortName() );
      buffer.append( "&amp;acktype=" );
      buffer.append( parms.ackType.getShortName() );
      buffer.append( this.getFiltersAsString(filters) );

      return( buffer.toString() );
    }


    public String makeLink( AlarmQueryParms parms ) {
      return( this.makeLink( parms.sortStyle, parms.ackType, parms.filters, parms.limit, parms.display) );
    }

    public String makeLink(AlarmQueryParms parms, String display) {
      return makeLink(parms.sortStyle, parms.ackType, parms.filters, parms.limit, display);
    }

    public String makeLink( AlarmQueryParms parms, SortStyle sortStyle ) {
      return( this.makeLink( sortStyle, parms.ackType, parms.filters, parms.limit, parms.display) );
    }


    public String makeLink( AlarmQueryParms parms, AcknowledgeType ackType ) {
      return( this.makeLink( parms.sortStyle, ackType, parms.filters, parms.limit, parms.display) );
    }


    public String makeLink( AlarmQueryParms parms, List<Filter> filters ) {
      return( this.makeLink( parms.sortStyle, parms.ackType, filters, parms.limit, parms.display) );
    }

    public String makeLink( AlarmQueryParms parms, Filter filter, boolean add ) {
      List<Filter> newList = new ArrayList<Filter>( parms.filters );
      if( add ) {
        newList.add( filter );
      }
      else {
        newList.remove( filter );
      }

      return( this.makeLink( parms.sortStyle, parms.ackType, newList, parms.limit, parms.display ));
    }

    public String[] getNodeLabels( String nodeLabel ) {
        String[] labels = null;

        if( nodeLabel.length() > 32 ) {
            String shortLabel = nodeLabel.substring( 0, 31 ) + "...";                        
            labels = new String[] { shortLabel, nodeLabel };
        }
        else {
            labels = new String[] { nodeLabel, nodeLabel };
        }

        return( labels );
    }
%>

<%!
    protected String getTextDesc( String desc ) {
         if ( desc != null && desc.indexOf("<table>") > 0 ) {
             return desc.substring( 0, desc.indexOf("<table>"));  
         }
         return desc;
    }
%>
<script type="text/javascript">
   //Query status for the purge action
    var actionStatus = "<%=actionStatus%>";
    var seperateStatus = actionStatus.split(",");
    var regularNoun = (parseInt(seperateStatus[0]) == 1)?'alarm is':'alarms are';
    var queryStatus = seperateStatus[1];
    if(queryStatus == "<%=AlarmPurgeController.SUCCESS_ACTION%>"){
	alert("The "+regularNoun+" successfully deleted from the DB");
    }else if(queryStatus == "<%=AlarmPurgeController.FAILURE_ACTION%>"){
	alert("The "+regularNoun+" not able to delete from the DB");
    }
</script>
<% request.getSession().setAttribute("actionStatus", "null"); %>
