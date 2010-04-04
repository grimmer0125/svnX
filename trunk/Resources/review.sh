#! /usr/bin/perl -w -Co
#
# review.sh <svn-tool> <options> <default-tab> <ctx-lines> <show-func> <show-chars> <dest-html> <paths...>
#

#use POSIX qw(locale_h); setlocale(LC_ALL, "en_US.UTF-8");
#use Encode::Guess;
#Encode::Guess->set_suspects(qw/utf8 utf16-be shiftjis euc-jp 7bit-jis/);

my ($svn, $options, $default_tab, $ctx_lines, $show_func, $show_chars, $dest_html)
	= ($ARGV[0], $ARGV[1], $ARGV[2], $ARGV[3], $ARGV[4], $ARGV[5], $ARGV[6]);
for (1..6) { shift; }

my $diff = "-U $ctx_lines";
if ("$show_func" ne '') {
	$diff .= ' -p --show-function-line=[[:blank:]]*[-+][[:blank:]]*([[:alpha:]_]';
}

open(STDOUT, ">$dest_html") || die "Can't redirect stdout";

$0 =~ s/\/[^\/]+$//g;
system('cat', "$0/Review.html");
if ($show_chars ne '') { system('cat', "$0/Review.js"); }

my ($path, $str);
foreach $path (@ARGV)
{
	$str = `$svn diff $options --non-interactive --diff-cmd /usr/bin/diff -x '$diff' '$path' 2> /dev/null`;
#	$str = `$svn diff $options --non-interactive '$path' | tr '\r' '\n' 2> /dev/null`;
	$_ = $str;
	if (0 && s/(^(Index.+\n|===+\n|---.+\n|\+\+\+.+\n){1,4})/$1/) {
		$head = $1; $body = substr($str, length $head);
		if (ref($decoder = Encode::Guess->guess($body))) { $body = $decoder->decode($body); }
		$str = $head . $body;
	#	print STDERR "[[[$head]]]\n";
	}
	$str =~ s/\\/\\\\/g;
	$str =~ s/\'/\\\'/g;
	$str =~ s/\r/\\r/g;
	$str =~ s/]]>/]\\]>/g;
	$str =~ s/<(\/script)>/<\\$1>/gi;
	$str =~ s/\n$//;
	$str =~ s/\n/',\n '/g;
	$str = "diff1($default_tab,[\n '$str']);";
	$str =~ s/(,\n '')?,\n( '(Index|Property changes on):)/,\n '']);\ndiff1($default_tab,[\n$2/g;
	$str =~ s/diff1\($default_tab,\[\n ''(,\n '')?\]\);//g;
	print("$str\n\n");
#	print Encode::encode("utf8", "$str\n\n");
}

print("//]]></script>\n</body>\n</html>\n");

