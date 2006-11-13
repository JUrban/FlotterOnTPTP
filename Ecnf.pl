#!/usr/bin/perl -w
# Usage: ./Ecnf.pl foffile [deffile]

# This is eprover used as a clausifier, printing for each resulting clause
# the initial formulas from which it descends.
# Note that definitions can be invented by E during the process - they 
# are treated as initial formulas too, and if second file name is supplied,
# dumped into that file.
#
# TODO: do this right in C, or just make the parsing reliable e.g.
#       by parsing the XML produced by tptp4X instead of this.

use strict;
my $problem = shift or die "file name expected";
my $def_file = shift;
my $pid = open(ECNF,"eprover -l4 --cnf  --tstp-format --no-preprocessing $problem|") or die("Cannot start eprover\n");
my %refs = (); # hash of clause references

# get @parents' parents, if a parent has no parent, get him (he is either initial or definition)
sub GetRecRefs
{
    my (@parents) = @_;

    my %res = ();
    my $par;

    foreach $par ( @parents )
    {
	if (exists $refs{$par})
	{
	    @res{ @{$refs{$par}} } = ();
	}
	else
	{
	    $res{$par} = ();
	}
    }

    return keys %res;
}

open(DEFS,">$def_file") if(defined $def_file);

while ($_ = <ECNF>)
{
  # initial refs
  if(m/^fof\(([^,]+),.*\bfile\('[^']*', *(.+)\)\)\./)
  {
      $refs{$1} = [$2];
#      print "refs1($1) = $2;\n";
  }
  # definition
  elsif((defined $def_file) && 
	(m/^(cnf|fof)\(([^,]+),.*\bintroduced\(definition\)\)\./))
  {
      print DEFS $_;
  }
  # normal inferences
  elsif(m/^(cnf|fof)\(([^,]+),.*\binference\([^,]+, [^,]+, *\[(.*)\]\)\)\./)
  {
      my @r1 = split(/, */, $3);
      my @r2 = GetRecRefs(@r1);
      $refs{$2} = [ GetRecRefs(@r1) ];
#      print "refs2($2) = @r2;\n";
  }

  # why does not  apply_def use standard inference syntax?
  elsif(m/^(cnf|fof)\(([^,]+),.*\bapply_def\(([^\)]+)\)\)\./)
  {
      my @r1 = split(/, */, $3);
      my @r2 = GetRecRefs(@r1);
      $refs{$2} = [ GetRecRefs(@r1) ];
#      print "refs3($2) = @r2;\n";
  }

  # not sure how much is this 'exists' syntax standard ..., but is seems tyo do the job
  elsif(m/^cnf\(([^,]+),(.*, *)([^,]+),\[\'exists\'\]\)\./)
  {
      my $r1 = join(',', GetRecRefs($3));
      print "cnf($1,$2 inference(cnf_conversion,[system(eprover)],[$r1])).\n";
  }
}
close(ECNF);
open(DEFS) if(defined $def_file);

