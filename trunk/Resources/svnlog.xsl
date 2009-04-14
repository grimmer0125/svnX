<?xml version="1.0"?>
<!--
  An XML transformation style sheet for converting the Subversion log listing to xhtml.
-->
<xsl:stylesheet version='1.0'
                xmlns:xsl='http://www.w3.org/1999/XSL/Transform'
                xmlns:exsl='http://exslt.org/common'
                extension-element-prefixes='exsl'>

  <xsl:param name='file' />
  <xsl:param name='revision' />
  <xsl:param name='base' />
  <xsl:param name='page-len' select='500' />
  <xsl:param name='F' select='concat("log-", $revision, "-pg")' />

  <xsl:variable name='entry-count' select='count(/log/logentry)' />
  <xsl:variable name='page-count' select='ceiling($entry-count div $page-len)' />
  <xsl:variable name='page' select='0' />

  <xsl:template match='*' />

  <xsl:template match='log'>
    <xsl:call-template name='page'>
      <xsl:with-param name='page' select='1'/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name='page'>
    <xsl:variable name='end' select='$page * $page-len' />
    <xsl:variable name='pos' select='$end - $page-len + 1' />
    <exsl:document method='html'
                   href='{$F}{$page}.html'
                   encoding='UTF-8'
                   omit-xml-declaration='no'
                   doctype-public='-//W3C//DTD XHTML 1.0 Strict//EN'
                   doctype-system='http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'
                   indent='yes'>
      <!--<html xml:space='preserve' xmlns='http://www.w3.org/1999/xhtml'>-->
      <html xmlns='http://www.w3.org/1999/xhtml'>
        <head>
          <xsl:if test='string-length($file) != 0'>
            <title>
              <xsl:text>Log for: </xsl:text><xsl:value-of select='concat($file, " r", $revision)'/>
            </title>
          </xsl:if>
          <link rel='stylesheet' type='text/css' href='{$base}/svnlog.css'/>
        </head>
        <!--<body xml:space='preserve'>-->
        <body>
          <xsl:call-template name='toc'>
            <xsl:with-param name='page' select='$page'/>
          </xsl:call-template>
          <table class='svn'>
            <xsl:apply-templates select='logentry[position() &gt;= $pos and position() &lt;= $end]'>
              <xsl:with-param name='page' select='$page'/>
            </xsl:apply-templates>
          </table>
        </body>
      </html>
    </exsl:document>
    <xsl:if test='$end &lt; $entry-count'>
      <xsl:call-template name='page'>
        <xsl:with-param name='page' select='$page + 1'/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template name='toc'>
    <xsl:if test='$page-count &gt; 1'>
      <table class='toc'><tbody><tr><td class='ar'>
<xsl:if test='$page = 1'><span class='O'>&#x140A;</span></xsl:if>
<xsl:if test='$page != 1'><a href='{$F}{$page - 1}.html'>&#x140A;</a></xsl:if>&#xA0;
<xsl:if test='$page = $page-count'><span class='O'>&#x1405;</span></xsl:if>
<xsl:if test='$page != $page-count'><a class='I' href='{$F}{$page + 1}.html'>&#x1405;</a></xsl:if>
</td><td class='pg'>
      <xsl:call-template name='link'>
        <xsl:with-param name='n' select='1'/>
        <xsl:with-param name='page' select='$page'/>
      </xsl:call-template>
      </td></tr></tbody></table>
    </xsl:if>
  </xsl:template>

  <xsl:template name='link'>
    <xsl:if test='$n &lt;= $page-count'>
      <xsl:if test='$n = $page'><span class='X'><xsl:value-of select='$n' /></span></xsl:if>
      <xsl:if test='$n != $page'><a href='{$F}{$n}.html'><xsl:value-of select='$n' /></a></xsl:if>&#xA0;
      <xsl:call-template name='link'>
        <xsl:with-param name='n' select='$n + 1'/>
        <xsl:with-param name='page' select='$page'/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match='logentry'>
    <xsl:variable name='page' select='$page' />
    <tbody class='entry'>
      <tr>
        <td class='rev'>r<xsl:value-of select='@revision'/></td>
        <td class='author'><xsl:value-of select='author'/></td>
        <td class='date'><xsl:value-of select='concat(substring-before(date, "T"),
                                                      "&#xA0;&#xA0;",
                                                      substring-before(substring-after(date, "T"),
                                                                       "."))'/></td>
      </tr>
      <tr>
        <td class='msg' colspan='3'>
        <xsl:for-each xmlns:str='http://exslt.org/strings' select='str:split(msg, "&#x0A;")'>
          <xsl:if test='position() != 1'><br/></xsl:if>
          <xsl:choose>
            <xsl:when test='starts-with(text(), " ")'><xsl:value-of select='concat("&#xA0;", substring-after(text(), " "))'/></xsl:when>
            <xsl:otherwise><xsl:value-of select='text()'/></xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
        </td>
      </tr>
      <xsl:apply-templates select='paths/path'/>
    </tbody>
  </xsl:template>

  <xsl:template match='paths/path'>
      <xsl:choose>
        <xsl:when test='string-length(@copyfrom-rev) != 0'>
          <xsl:call-template name='path1'>
           	<xsl:with-param name='path' select='concat(text(), "&#xA0;&#xA0;&#x21E6;&#xA0;&#xA0;", @copyfrom-rev, ":&#xA0;", @copyfrom-path)'/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name='path1'>
            <xsl:with-param name='path' select='text()'/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template name='path1'>
    <tr>
      <td class='act'><xsl:value-of select='@action'/></td>
      <td class='path' colspan='2'><xsl:value-of select='$path'/></td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
