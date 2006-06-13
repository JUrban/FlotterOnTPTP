# Perl hack for clausifying with Flotter in the TPTP way.
# You will need SPASS 2.1, my patch to it, and
# the ReformatTPTP tool from Geoff Sutcliffe's TPTPWorld

# run like:
# perl -F FlotterOnTPTP problem.fof >problem.cnf

local $/;

# temp file for ReformatTPTP
$tmpfile = "mmmfoo1";

# export to dfg and run patched SPASS producing the SPASS cnf and clause2fla table

$_ = `./ReformatTPTP -f dfg $ARGV[0] |./SPASS -Flotter  -DocProof -Stdin`;

# parse the SPASS cnf and the clause2fla table

m/(begin_problem(.|\n)*end_problem\.\n)(.|\n)*FLOTTER needed.*\n.*\n((.|\n)*)/;
$_=$1; $t=$4;

# replace clause numbers with secret names - otherwise my dfg2tptp does not keep the clause name

s/\),(\d+)\)\./),my_secret_cnf\1)./g;

# replace conjecture by negated_conjecture, run through patched dfg2tptp
# and put to new tptp, parse it all to $cnf1

$cnf1=`echo "$_"|./dfg2tptp|sed -e 's/,conjecture,/,negated_conjecture,/g'> $tmpfile; ./ReformatTPTP $tmpfile`;

# parse the clause2fla table to %h

%h=(); while($t=~m/\n(\d+): *(.*)/g) {$h{"my_secret_cnf$1"}=$2;};

# replace the secret clause names with "c", and add the cnf_conversion inference slot

$_=$cnf1;
s/(\bmy_secret_cnf(\d+)\b)([^.]+)\)\./c\2\3,inference(cnf_conversion,[flotter],[$h{$1}]))./g;
print $_;

# clenup the tempfile
`rm $tmpfile`;