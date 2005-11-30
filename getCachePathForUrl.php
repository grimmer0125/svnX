#! /usr/bin/php
<?
//
// Creates and a returns a unique path for caching items related to an url.
//
// $1 : Path to user's Caches directory (usually ~Library/Caches)
// $2 : the url to cache
// $3 : revision id (optional)
//
 
$userCache = $_SERVER["argv"][1];
$url = $_SERVER["argv"][2];

if ( $_SERVER["argv"][3] )
{
   $rev = $_SERVER["argv"][3];
   $rev = strtr($rev, ":/", ";_");
}

$userCache = realpath($userCache);

if ( chdir($userCache) )
{
   $url_arr = parse_url($url);

   $url_path = '/_child_'.$rev.'/_root';
   
   if ( $url_arr['path'] != '/' )
   {
      $url_path .=  implode('/_child_'.$rev.'/', explode('/', $url_arr['path']));
   }
   
   $path = "com.lachoseinteractive.svnX/".$url_arr['scheme'].'/'.
            $url_arr['host'].'/'.
            (($url_arr['port']=='')?('_'):($url_arr['port'])).'/' .
            (($url_arr['user']=='')?('_'):($url_arr['user'])).'/' .
            (($url_arr['pass']=='')?('_'):($url_arr['pass'])).$url_path;

   $a = `/bin/mkdir -p '$path'`;
   
   echo realpath("$userCache/$path");
}

?>