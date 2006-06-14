#!/usr/bin/perl

# Perl hack for clausifying with Flotter in the TPTP way.
# You will need SPASS 2.1 (http://spass.mpi-sb.mpg.de/download/sources/spass21.tgz),
# my patch (spass21patch) to it, and
# the tptp4X tool from Geoff Sutcliffe's
# TPTPWorld (http://www.cs.miami.edu/~tptp/TPTPWorld.tgz).
# After patching (patch -p0 < spass21patch) and compiling SPASS,
# you will need the SPASS program and the dfg2tptp tool.

# SYNOPSIS:
# ./FlotterOnTPTP problem.fof >problem.cnf

use FileHandle;
use IPC::Open2;

my $FlotterOnTPTPHome = "/home/graph/tptp/Systems/FlotterOnTPTP---1.3";

local $/;

# export to dfg and run patched SPASS producing the SPASS cnf and clause2fla table

$_ = `$FlotterOnTPTPHome/tptp4X -x -f dfg $ARGV[0] | $FlotterOnTPTPHome/SPASS -Flotter  -DocProof -Stdin`;

# parse the SPASS cnf and the clause2fla table

m/(begin_problem(.|\n)*end_problem\.\n)(.|\n)*FLOTTER needed.*\n.*\n((.|\n)*)/;
$_=$1; $t=$4;

# replace clause numbers with secret names - otherwise my dfg2tptp does not keep the clause name

s/\),(\d+)\)\./),my_secret_cnf\1)./g;

# replace conjecture by negated_conjecture, run through patched dfg2tptp
# and put to new tptp, parse it all to $cnf1

$pid = open2(*Reader, *Writer, "$FlotterOnTPTPHome/dfg2tptp|sed -e 's/,conjecture,/,negated_conjecture,/g' | $FlotterOnTPTPHome/tptp4X -- " );

print Writer "$_\n";
$cnf1= <Reader>;

# $cnf1=`echo "$_"|./dfg2tptp|sed -e 's/,conjecture,/,negated_conjecture,/g' | ./ReformatTPTP --`;

# parse the clause2fla table to %h

%h=(); while($t=~m/\n(\d+): *(.*)/g) {$h{"my_secret_cnf$1"}=$2;};

# replace the secret clause names with "c", and add the cnf_conversion inference slot

$_=$cnf1;
s/(\bmy_secret_cnf(\d+)\b)([^.]+)\)\./c\2\3,inference(cnf_conversion,[flotter],[$h{$1}]))./g;
print $_;

