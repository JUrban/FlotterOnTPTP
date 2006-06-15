#!/usr/bin/perl -w
# $Revision: 1.8 $

=head1 NAME

FlotterOnTPTP.pl ( Clausify with Flotter in the TPTP way)

=head1 SYNOPSIS

FlotterOnTPTP.pl [options] fofproblem

# produce TPTP3 cnf format

FlotterOnTPTP.pl problem.fof >problem.cnf

# read input from pipe, produce cnf format, and run E

cat problem.fof | ./FlotterOnTPTP.pl | eprover -tAuto -xAuto --tstp-in

# prepare input for Vampire, then run it (no pipes for Vampire AFAIK)

FlotterOnTPTP.pl -f oldtptp problem.fof >problem.cnf
vampire --mode casc -t 300 problem.cnf

 Options:
   --format[=<arg>],   	    -f[<arg>]
   --transform[=<arg>],	    -t[<arg>]
   --user[=<arg>],	    -u[<arg>]
   --help,                  -h
   --man

=head1 OPTIONS

=over 8

=item B<<< --format[=<arg>], -f[<arg>] >>>

Specify the output format. The default is the TPTP3 format.
Run B<tptp4x -h> for a list of supported formats.

=item B<<< --transform[=<arg>], -t[<arg>] >>>

Transform the formulae. Default is no transformation.
Run B<tptp4x -h> for a list of supported transformations.

=item B<<< --user[=<arg>], -u[<arg>] >>>

Specify the user type. The default is human (pretty printing).
Run B<tptp4x -h> for a list of supported user types.

=item B<<< --help, -h >>>

Print a brief help message and exit.

=item B<<< --man >>>

Print the manual page and exit.

=back


=head1 DESCRIPTION

B<FlotterOnTPTP.pl> is a Perl hack for clausifying with Flotter
in the TPTP way. You will need SPASS 2.1
(http://spass.mpi-sb.mpg.de/download/sources/spass21.tgz),
Josef Urban's patch (spass21patch) to it
(http://kti.ms.mff.cuni.cz/cgi-bin/viewcvs.cgi/*checkout*/FlotterOnTPTP/spass21patch),
and the tptp4X tool from Geoff Sutcliffe's
TPTPWorld (http://www.cs.miami.edu/~tptp/TPTPWorld.tgz).
After patching (patch -p0 < spass21patch) and compiling SPASS,
you will need the SPASS program and the dfg2tptp tool.

=head1 LICENCE

License:     GPL (GNU GENERAL PUBLIC LICENSE)

=head1 AUTHORS

Josef Urban 	(urban at kti.mff.cuni.cz) and
Geoff Sutcliffe (geoff at cs.miami.edu)

=cut

use Getopt::Long;
use Pod::Usage;
use FileHandle;
use IPC::Open2;

my $FlotterOnTPTPHome = "~/FlotterOnTPTP/distro/FlotterOnTPTP";#"/home/graph/tptp/Systems/FlotterOnTPTP---1.3";
my $Format = "tptp";
my $Transform = "none";
my $User = "human";

Getopt::Long::Configure ("bundling","no_ignore_case");

GetOptions('format|f=s'     	=> \$Format,
	   'transform|t=s' 	=> \$Transform,
	   'user|u=s'    	=> \$User,
	   'help|h'          	=> \$help,
	   'man'             	=> \$man)
    or pod2usage(2);

pod2usage(1) if($help);
pod2usage(-exitstatus => 0, -verbose => 2) if($man);

# export to dfg and run patched SPASS producing the SPASS cnf and clause2fla table

if($#ARGV==0) {
  $_ = `$FlotterOnTPTPHome/tptp4X -x -f dfg $ARGV[0]`;
}
else { 
  if($#ARGV<0) {
    local $/;
    my $in = <>;
    open2(*Reader1, *Writer1, "$FlotterOnTPTPHome/tptp4X -x -f dfg -- ");
    print Writer1 $in;
    close Writer1;
    $_ = <Reader1>;
  }
  else { pod2usage(2); }
}

local $/;

if ($_ =~ "ERROR:") {
    print("ERROR: Cannot translate to DFG\n");
    die("\n");
}

open2(*Reader2, *Writer2, "$FlotterOnTPTPHome/SPASS -Flotter  -DocProof -Stdin");
print Writer2 $_;
close Writer2;
$_ = <Reader2>;

# parse the SPASS cnf and the clause2fla table

if(m/(begin_problem(.|\n)*end_problem\.\n)(.|\n)*FLOTTER needed.*\n.*\n((.|\n)*)/) {
  $_=$1; $t=$4;
}
else {
  print("ERROR: Cannot translate to DFG\n");
  die("\n");
}

# replace clause numbers with secret names - otherwise my dfg2tptp does not keep the clause name

s/\),(\d+)\)\./),my_secret_cnf$1)./g;

# replace conjecture by negated_conjecture, run through patched dfg2tptp
# and put to new tptp, parse it all to $cnf1

my $pid = open2(*Reader, *Writer, "$FlotterOnTPTPHome/dfg2tptp|sed -e 's/,conjecture,/,negated_conjecture,/g' | $FlotterOnTPTPHome/tptp4X -f $Format -t $Transform -u $User -- " );

print Writer "$_\n";
close Writer;
$cnf1= <Reader>;

# parse the clause2fla table to %h

%h=(); while($t=~m/\n(\d+): *(.*)/g) {$h{"my_secret_cnf$1"}=$2;};

# replace the secret clause names with "c", and add the cnf_conversion inference slot

$_=$cnf1;
s/(\bmy_secret_cnf(\d+)\b)([^.]+)\)\./c$2$3,inference(cnf_conversion,[system(flotter)],[$h{$1}]))./g;
print $_;

__END__
