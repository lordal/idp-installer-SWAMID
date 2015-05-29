<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:variable name="portsToGet" select="'443, 8443, 7443'" />
    <xsl:variable name="varsToGet" select="'KeyStoreType, KeyStorePath, KeyStorePassword'" />
    <xsl:variable name="currentPort"/>
    <xsl:key name="kCode" match="New" use="@id"/>

    <xsl:template match="/">
        <xsl:for-each select="/Configure/Call/Arg/New">
            <xsl:for-each select="./Set">
                <xsl:if test="@name = 'port'">
                    <xsl:if test="contains($portsToGet, current())">
                        <xsl:variable name="currentPort" select="."/>
                        <xsl:for-each select="../Arg/Array/Item/New/Arg">
                            <xsl:if test="@name = 'sslContextFactory'">
                                <xsl:for-each select="key('kCode', ./Ref/@refid)">
                                    <xsl:for-each select="./*">
                                        <xsl:for-each select="@name">
                                            <xsl:if test="contains($varsToGet, current())">
                                                <xsl:value-of select="$currentPort"/>
                                                <xsl:text>-</xsl:text>
                                                <xsl:value-of select="."/>
                                                <xsl:text>=</xsl:text>
                                                <xsl:for-each select="../.">
                                                    <xsl:value-of select="."/>
                                                </xsl:for-each>
                                                <xsl:text>&#xA;</xsl:text>
                                            </xsl:if>
                                        </xsl:for-each>
                                    </xsl:for-each>
                                </xsl:for-each>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:if>
                </xsl:if>
            </xsl:for-each>
            <xsl:text>&#xA;</xsl:text>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
