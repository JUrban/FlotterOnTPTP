#!/usr/bin/perl -w

# create Prolog data from E protocol, giving it a name from ARGV[0]
# run like:
# for i in `ls prot*`; do ./mkprol_prot.pl $i; done >allprots.pl

use strict;

print "protocol('", $ARGV[0], "',[";

my $nm= $ARGV[0];

my $comma = 0;
while(<>)
{
    if(!(m/^#/))
    {
	my @problem_run = split;
#	die "bad problem: $nm, $_" unless ($#problem_run == 8);
	if (($#problem_run == 8) && ($problem_run[3] eq "success"))
	{
	    if($comma==1) { print ","; } else { $comma = 1 }
	    print "['", $problem_run[0], "',", $problem_run[2], "]";
	}
    }
}
print "]).\n";
