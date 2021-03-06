# Perl hack for clausifying with Flotter in the TPTP way, 
# running E-PROVER on the clausification, and mangling the inferences together..
# You will need SPASS 2.1 (http://spass.mpi-sb.mpg.de/download/sources/spass21.tgz),
# my patch (spass21patch) to it, and
# the ReformatTPTP tool from Geoff Sutcliffe's
# TPTPWorld (http://www.cs.miami.edu/~tptp/TPTPWorld.tgz).
# After patching (patch -p0 < spass21patch) and compiling SPASS,
# you will need the SPASS program and the dfg2tptp tool.

# SYNOPSIS:
# perl -F EFlotterOnTPTP problem.fof >solution.tptp

local $/;

# export to dfg and run patched SPASS producing the SPASS cnf and clause2fla table

$_ = `./ReformatTPTP -f dfg $ARGV[0] |./SPASS -Flotter  -DocProof -Stdin`;

# parse the SPASS cnf and the clause2fla table

m/(begin_problem(.|\n)*end_problem\.\n)(.|\n)*FLOTTER needed.*\n.*\n((.|\n)*)/;
$_=$1; $t=$4;

# replace clause numbers with secret names - otherwise my dfg2tptp does not keep the clause name

s/\),(\d+)\)\./),my_secret_cnf\1)./g;

# replace conjecture by negated_conjecture, run through patched dfg2tptp
# and put to new tptp, parse it all to $cnf1

$cnf1=`echo "$_"|./dfg2tptp|sed -e 's/,conjecture,/,negated_conjecture,/g'| ./ReformatTPTP --`;

# parse the clause2fla table to %h

%h=(); while($t=~m/\n(\d+): *(.*)/g) {$h{"my_secret_cnf$1"}=$2;};

# replace the secret clause names with "c", and add the cnf_conversion inference slot

$_=$cnf1;
s/(\bmy_secret_cnf(\d+)\b)([^.]+)\)\./c\2\3,inference(cnf_conversion,[flotter],[$h{$1}]))./g;
$cnf2 = $_;
# print $_;

# now run E (without timelimit so far)
$prf=`echo "$_"|eproof -t Auto -x Auto --tstp-format`;
$_=$prf;
while(m/,file\(.<stdin>., c(\d+)\)\)\./g) { $fofs = $fofs . ", " . $h{"my_secret_cnf$1"} }
s/,file\(.<stdin>., c(\d+)\)\)\./,inference(cnf_conversion,[flotter],[$h{"my_secret_cnf$1"}]))./g;
@fofs1= split(/, */, $fofs);
foreach $key1 ( @fofs1 ) { if(!($key1 eq "")) {$sortedfofs{$key1} = (); }}
@sfofs = keys %sortedfofs;
$r1 = '\b(fof\((' . join('|', @sfofs) . ')\b[^.]*\)\.)';
$regexp = qr/$r1/;
$fof=`cat $ARGV[0]`;
while($fof=~m/$regexp/g) { print "$1\n";}
print $_;
