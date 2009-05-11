<?xml version="1.0"?>
<!--
  An XML transformation style sheet for converting the Subversion log listing to xhtml.
-->
<xsl:stylesheet version='1.0'
                xmlns:xsl='http://www.w3.org/1999/XSL/Transform'
                xmlns:exsl='http://exslt.org/common'
                xmlns:date='http://exslt.org/dates-and-times'
                extension-element-prefixes='exsl'>

  <xsl:param name='file' />
  <xsl:param name='revision' />
  <xsl:param name='base' />
  <xsl:param name='page-len' select='500' />
  <xsl:param name='F' select='concat("log-", $revision, "-pg")' />
  <xsl:param name='age' select='0' />

  <xsl:variable name='entry-count' select='count(/log/logentry)' />
  <xsl:variable name='page-count' select='ceiling($entry-count div $page-len)' />
  <xsl:variable name='page' select='0' />
  <xsl:variable name='today' select='date:date()' />
  <xsl:variable name='now' select='date:seconds()' />
  <xsl:variable name='title'>
    <xsl:if test='$file != ""'>
      <xsl:value-of select='concat("Log for: ", $file)'/>
      <xsl:if test='$revision != ""'><xsl:value-of select='concat(" r", $revision)'/></xsl:if>
    </xsl:if>
  </xsl:variable>

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
      <html xmlns='http://www.w3.org/1999/xhtml'
            xmlns:date='http://exslt.org/dates-and-times'>
        <xsl:text>&#10;</xsl:text>
        <head>
          <title><xsl:value-of select='$title'/></title>
          <link rel='stylesheet' type='text/css' href='{$base}/svnlog.css'/>
        </head>
        <xsl:text>&#10;</xsl:text>
        <!--<body xml:space='preserve'>-->
        <body>
          <xsl:call-template name='toc'>
            <xsl:with-param name='page' select='$page'/>
          </xsl:call-template>
          <xsl:if test='$page = 1 and $title != ""'>
            <table class="T"><tr><th class="H"><xsl:value-of select='$title'/></th>
            <th class="D"><xsl:value-of select='$today'/></th></tr></table>
            <xsl:text>&#10;</xsl:text>
          </xsl:if>
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
        <td class='rev'><xsl:value-of select='@revision'/></td>
        <td class='author'><xsl:value-of select='author'/></td>
        <xsl:variable name='S' select='date:seconds(date)' />
        <xsl:variable name='s' select='round($now - $S)' />
        <xsl:variable name='d' select='floor($now div 86400) - floor($S div 86400)' />
        <xsl:variable name='T' select='concat(substring-before(date, "T"),
                                              "&#xA0;&#xA0;",
                                              substring-before(substring-after(date, "T"), "."))' />
        <td class='date' title='{$T}'><xsl:choose>
          <xsl:when test='$age = 0'><xsl:value-of select='$T'/></xsl:when>
          <xsl:when test='$d &gt; 729'><xsl:value-of select='floor($d div 365)'/> years</xsl:when>
          <xsl:when test='$d &gt; 59'><xsl:value-of select='floor($d div 30)'/> months</xsl:when>
          <xsl:when test='$d &gt; 13'><xsl:value-of select='floor($d div 7)'/> weeks</xsl:when>
          <xsl:when test='$d &gt; 1'><xsl:value-of select='$d'/> days</xsl:when>
          <xsl:when test='$s &gt; 7199'><xsl:value-of select='floor($s div 3600)'/> hours</xsl:when>
          <xsl:when test='$s &gt; 119'><xsl:value-of select='floor($s div 60)'/> minutes</xsl:when>
          <xsl:when test='$s = 1'>1 second</xsl:when>
          <xsl:otherwise><xsl:value-of select='$s'/> seconds</xsl:otherwise>
        </xsl:choose></td>
      </tr>
      <tr>
        <td class='msg' colspan='3'>
        <xsl:for-each xmlns:str='http://exslt.org/strings' select='str:split(msg, "&#x0A;")'>
          <xsl:if test='position() != 1'><br/></xsl:if>
          <xsl:choose>
            <xsl:when test='starts-with(text(), " ")'>&#xA0;<xsl:value-of select='substring-after(text(), " ")'/></xsl:when>
            <xsl:when test='starts-with(text(), "&#9;")'>&#xA0;<xsl:value-of select='text()'/></xsl:when>
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
      <xsl:variable name='act' select='@action' />
      <td class='act {$act}'><xsl:value-of select='translate($act, "AMDR", "")'/></td>
      <td class='path' colspan='2'><xsl:value-of select='$path'/></td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
