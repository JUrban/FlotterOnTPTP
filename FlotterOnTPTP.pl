#!/usr/bin/perl -w
# $Revision: 1.11 $

=head1 NAME

FlotterOnTPTP.pl ( Clausify with Flotter in the TPTP way)

=head1 SYNOPSIS

FlotterOnTPTP.pl [options] fofproblem

# produce TPTP3 cnf format

FlotterOnTPTP.pl problem.fof >problem.cnf

# read input from pipe, produce cnf format, and run E

cat problem.fof | ./FlotterOnTPTP.pl | eprover -s -tAuto -xAuto --tstp-in

# run eproof directly:

./FlotterOnTPTP.pl  -s eproof -t 4 problem.fof

# prepare input for Vampire, then run it (no pipes for Vampire AFAIK)

FlotterOnTPTP.pl -f oldtptp problem.fof >problem.cnf

vampire --mode casc -t 300 problem.cnf

# run vampire directly

./FlotterOnTPTP.pl -f oldtptp -s vampire -t 4 problem.fof


 Options:
   --format[=<arg>],   	    -f[<arg>]
   --transform[=<arg>],	    -t[<arg>]
   --user[=<arg>],	    -u[<arg>]
   --system[=<arg>],	    -s[<arg>]
   --timelimit[=<arg>],	    -T[<arg>]
   --help,                  -h
   --man

=head1 OPTIONS

=over 8

=item B<<< --format[=<arg>], -f[<arg>] >>>

Specify the output format. The default is the TPTP3 format (tptp).
Run B<tptp4x -h> for a list of supported formats.

=item B<<< --transform[=<arg>], -t[<arg>] >>>

Transform the formulae. Default is no transformation.
Run B<tptp4x -h> for a list of supported transformations.

=item B<<< --user[=<arg>], -u[<arg>] >>>

Specify the user type. The default is human (pretty printing).
Run B<tptp4x -h> for a list of supported user types.

=item B<<< --system[=<arg>], -s[<arg>] >>>

Specify a system launched on the clausified output. The default is none.
Currently supported are: vampire (run with --mode casc),
eprover (run with -s -tAuto -xAuto --tstp-in), and
eproof (run with -tAuto -xAuto --tstp-format).

=item B<<< --timelimit[=<arg>], -T[<arg>] >>>

Specify the time limit for a system run through -s. The default is 300.

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
use File::Temp qw/ :mktemp  /;
#------------------------------------------------------------------------------
my $FlotterOnTPTPHome = "/home/graph/tptp/Systems/FlotterOnTPTP---1.3";
my $Format = "tptp";
my $Transform = "none";
my $User = "human";
my $System = "none";
my $Timelimit = 300;
my $pid;

$SIG{'QUIT'} = 'QUITHandler';
$SIG{'XCPU'} = 'QUITHandler';
$SIG{'ALRM'} = 'ALRMHandler';

Getopt::Long::Configure ("bundling","no_ignore_case");

GetOptions('format|f=s'     	=> \$Format,
	   'transform|t=s' 	=> \$Transform,
	   'user|u=s'    	=> \$User,
	   'system|s=s' 	=> \$System,
	   'timelimit|T=i'    	=> \$Timelimit,
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
  $_=$1; $t= "\n" . $4;
}
else {
  print("ERROR: Cannot translate to DFG\n");
  die("\n");
}

# replace clause numbers in the cnf with secret names - otherwise my dfg2tptp does not keep the clause name

s/\),(\d+)\)\./),my_secret_cnf$1)./g;

# replace conjecture by negated_conjecture, run through patched dfg2tptp
# and put to new tptp, parse it all to $cnf1

$pid = open2(*Reader, *Writer, "$FlotterOnTPTPHome/dfg2tptp|sed -e 's/,conjecture,/,negated_conjecture,/g' | $FlotterOnTPTPHome/tptp4X -f $Format -t $Transform -u $User -- " );

print Writer "$_\n";
close Writer;
my $cnf1= <Reader>;

# parse the clause2fla table to %h
# print $t;
my %h=();
while($t =~ m/\n(\d+): *(.*)/g) {$h{"my_secret_cnf$1"}=$2;};

# replace the secret clause names with "c", and add the cnf_conversion inference slot
$_ = $cnf1;
# print $cnf1;
if ($Format eq "tptp")
{
    s/(\bmy_secret_cnf(\d+)\b)([^.]+)\)\./c$2$3,inference(cnf_conversion,[system(flotter)],[$h{$1}]))./g;
}
my $cnf2= $_;

SWITCH: for($System)
    {
	if(/^none$/)
	{
	    print $cnf2;
	    last SWITCH;
	}
	if(/^eprover$/)
	{
	    open2(*EReader1, *EWriter1, 
		  "$FlotterOnTPTPHome/eprover -s -tAuto -xAuto --tstp-in --cpu-limit=$Timelimit ");
	    print EWriter1 $cnf2;
	    close EWriter1;
	    $_ = <EReader1>;
	    print $_;
	    last SWITCH;
	};
	if(/^eproof$/)
	{
	    open2(*EReader2, *EWriter2, 
		  "$FlotterOnTPTPHome/eproof -t Auto -x Auto --tstp-format --cpu-limit=$Timelimit ");
	    print EWriter2 $cnf2;
	    close EWriter2;
	    $_ = <EReader2>;

	    # now forge the proof
	    my $fofs = "";
	    while(m/,file\(.<stdin>., c(\d+)\)\)\./g)
	    {
		$fofs = $fofs . ", " . $h{"my_secret_cnf$1"}
	    }
	    s/,file\(.<stdin>., c(\d+)\)\)\./,inference(cnf_conversion,[flotter],[$h{"my_secret_cnf$1"}]))./g;
	    @fofs1= split(/, */, $fofs);
	    foreach $key1 ( @fofs1 ) { if(!($key1 eq "")) {$sortedfofs{$key1} = (); }}
	    @sfofs = keys %sortedfofs;
	    $r1 = '\b(fof\((' . join('|', @sfofs) . ')\b[^.]*\)\.)';
	    $regexp = qr/$r1/;
	    $fof=`cat $ARGV[0]`;
	    while($fof=~m/$regexp/g) { print "$1\n";}
	    print $_;
	    last SWITCH;
	};
	if(/^vampire$/)
	{
	    ###TODO: learn how to run vampire through pipe
	    $vamp_in = mktemp("___vamptmp___XXXXX");
	    open(VIN,">$vamp_in") or die "Cannot open file $vamp_in for writing";
	    print VIN $cnf2;
	    close(VIN);
        $pid = open(VOUT,"$FlotterOnTPTPHome/vampire --mode casc -t $Timelimit $vamp_in|") or die("Cannot start vampire\n");
        while ($_ = <VOUT>) {
	        print $_;
        }
        close(VOUT);
        if (-e $vamp_in) {
	        unlink($vamp_in);
        }
	    last SWITCH;
	};
	die "Unhandled system name: $System";
    }

#------------------------------------------------------------------------------
sub QUITHandler {
    my ($Signal) = @_;

    kill($Signal,$pid);
    if (-e $vamp_in) {
        unlink($vamp_in);
    }
}
#------------------------------------------------------------------------------
__END__
