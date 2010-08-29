#!/usr/bin/perl

use Config;

sub permute
{
	my @defines = @_;
	my @result = ('');
	
	foreach $define (@defines)
	{
		push @result, map { length($_) == 0 ? $define : "$_,$define" } @result;
	}

	@result;
}

sub gcctoolset
{
	my $gccversion = `gcc -dumpversion`;
	chomp($gccversion);

	my $gcc = "gcc$gccversion";

	return ($^O =~ /darwin/) ? ($gcc, "${gcc}_x64", "${gcc}_ppc") : (`uname -m` =~ /64/) ? ("${gcc}_x64") : ($gcc);
}

@alltoolsets = ($^O =~ /MSWin/) ? (bcc, cw, dmc, ic8, ic9, ic9_x64, ic10, ic10_x64, ic11, ic11_x64, mingw34, mingw44, mingw45, mingw45_0x, mingw46_x64, msvc6, msvc7, msvc71, msvc8, msvc8_x64, msvc9, msvc9_x64, msvc10, msvc10_x64, xbox360, ps3_gcc, ps3_snc) : ($^O =~ /solaris/) ? (suncc, suncc_x64) : &gcctoolset();

$fast = scalar grep(/^fast$/, @ARGV);
@toolsets = map { /^fast$/ ? () : ($_) } @ARGV;
@toolsets = @toolsets ? @toolsets : @alltoolsets;

@configurations = (debug, release);
@defines = (PUGIXML_NO_XPATH, PUGIXML_NO_EXCEPTIONS, PUGIXML_NO_STL, PUGIXML_WCHAR_MODE);
$stddefine = 'PUGIXML_STANDARD';

if ($fast)
{
	@defines = (PUGIXML_WCHAR_MODE);
	@configurations = (debug);
}

@definesets = permute(@defines);

print "### autotest begin " . scalar localtime() . "\n";

# print SVN revision info
print "### autotest revision $1\n" if (`svn info` =~ /Revision:\s+(\d+)/);

# build all configurations
%results = ();

foreach $toolset (@toolsets)
{
	my $cmdline = "jam";

	# parallel build on non-windows platforms (since jam can't detect processor count)
	$cmdline .= " -j6" if ($^O !~ /MSWin/);
	
	# add toolset
	$cmdline .= " toolset=$toolset";

	# add configurations
	$cmdline .= " configuration=" . join(',', @configurations);

	# add definesets
	$cmdline .= " defines=$stddefine";

	foreach $defineset (@definesets)
	{
		$cmdline .= ":$defineset" if ($defineset ne '');

		# any configuration with prepare but without result is treated as failed
		foreach $configuration (@configurations)
		{
			print "### autotest $Config{archname} $toolset $configuration [$defineset] prepare\n";
		}
	}

	print STDERR "*** testing $toolset... ***\n";

	# launch command
	print "### autotest launch $cmdline\n";

	open PIPE, "$cmdline autotest=on coverage |" || die "$cmdline failed: $!\n";

	# parse build output
	while (<PIPE>)
	{
		# ... autotest release [wchar] success
		if (/^\.\.\. autotest (\S+) \[(.*?)\] success/)
		{
			my $configuration = $1;
			my $defineset = ($2 eq $stddefine) ? '' : $2;

			print "### autotest $Config{archname} $toolset $configuration [$defineset] success\n";
		}
		# ... autotest release [wchar] gcov
		elsif (/^\.\.\. autotest (\S+) \[(.*?)\] gcov/)
		{
			my $configuration = $1;
			my $defineset = ($2 eq $stddefine) ? '' : $2;

			if (/pugixml\.cpp' executed:([^%]+)%/)
			{
				print "### autotest $Config{archname} $toolset $configuration [$defineset] coverage $1\n";
			}
			else
			{
				print;
			}
		}
		else
		{
			print;
		}
	}

	close PIPE;
}

print "### autotest end " . scalar localtime() . "\n";
