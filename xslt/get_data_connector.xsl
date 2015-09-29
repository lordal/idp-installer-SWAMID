<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                              xmlns:resolver="urn:mace:shibboleth:2.0:resolver" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                              xmlns:pc="urn:mace:shibboleth:2.0:resolver:pc" xmlns:ad="urn:mace:shibboleth:2.0:resolver:ad" 
                              xmlns:dc="urn:mace:shibboleth:2.0:resolver:dc" xmlns:enc="urn:mace:shibboleth:2.0:attribute:encoder" 
                              xmlns:sec="urn:mace:shibboleth:2.0:security" 
                              xsi:schemaLocation="urn:mace:shibboleth:2.0:resolver classpath:/schema/shibboleth-2.0-attribute-resolver.xsd
                                                  urn:mace:shibboleth:2.0:resolver:pc classpath:/schema/shibboleth-2.0-attribute-resolver-pc.xsd
                                                  urn:mace:shibboleth:2.0:resolver:ad classpath:/schema/shibboleth-2.0-attribute-resolver-ad.xsd
                                                  urn:mace:shibboleth:2.0:resolver:dc classpath:/schema/shibboleth-2.0-attribute-resolver-dc.xsd
                                                  urn:mace:shibboleth:2.0:attribute:encoder classpath:/schema/shibboleth-2.0-attribute-encoder.xsd
                                                  urn:mace:shibboleth:2.0:security classpath:/schema/shibboleth-2.0-security.xsd">

	<xsl:template match="/">
		<xsl:for-each select="/resolver:AttributeResolver/resolver:AttributeDefinition">
			<xsl:if test="@id='eduPersonTargetedID'">
				<xsl:text>ref=</xsl:text><xsl:value-of select="resolver:Dependency/@ref"/><xsl:text>&#xA;</xsl:text>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
