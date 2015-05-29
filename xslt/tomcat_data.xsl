<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:variable name="portsToGet" select="'443, 8443, 7443'" />
	<xsl:variable name="varsToGet"
			select="'keystoreType, keystoreFile, keystorePass'" />
	<xsl:template match="/">
		<xsl:for-each select="/Server/Service/Connector">
			<xsl:if test="contains($portsToGet, @port)">
				<xsl:variable name="currentPort" select="@port" />
				<xsl:for-each select="@*">
					<xsl:if test="contains($varsToGet, name())">
						<xsl:value-of select="$currentPort"/>
						<xsl:text>-</xsl:text>
						<xsl:value-of select="name()"/>
						<xsl:text>=</xsl:text>
						<xsl:value-of select="."/>
						<xsl:text>&#xA;</xsl:text>
					</xsl:if>
				</xsl:for-each>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
