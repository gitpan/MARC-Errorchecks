=head1 NAME

MARC::Errorchecks -- Cross-field error checks for MARC records according to MARC21, AACR2R, and LCRI rules.

=head1 DESCRIPTION

Module for storing MARC error-checking subroutines,
based on MARC21, AACR2R, and LCRIs.
These are used to find errors not easily checked by
the MARC::Lint and MARC::Lintadditions modules,
such as those that cross field boundaries.

Each subroutine should generally be passed a MARC::Record object.

Returned warnings/errors are generated as follows:
push @warningstoreturn, join '', ($field->tag(), ": [ERROR TEXT]\t");
return \@warningstoreturn;

=head2 DISTRIBUTION CONTENTS

In lib/ directory:
MARC::BBMARC (v. 1.07)-- Collection of misc. subs used by the scripts in the bin/ directory.
This may be added as a separate module distribution in the future, possibly under a different name.

In the bin/ directory:

 -bin/Lintallchecks.pl -- Uses MARC::Lint, MARC::Lintadditions, and MARC::Errorchecks 
to look for MARC21, AACR2/LCRI coding problems in a file of MARC21 records.

 MARC code list cleanup scripts (for generating the DATA section of MARC::Errorchecks and MARC::Lintadditions):
 (Require ASCII version of code lists, L<http://www.loc.gov/marc/>)
 -bin/countrycodelistclean.pl--L<http://www.loc.gov/marc/countries/cou_ascii.html>
 -bin/gaccleanupscript.pl--L<http://www.loc.gov/marc/geoareas/gacascii.html>
 -bin/languagecodelistclean.pl--L<http://www.loc.gov/marc/languages/langascii.html>

 Other possibly useful scripts:
 (All require MARC::BBMARC, available from L<http://home.inwave.com/eija/bryanmodules>)
 
 -bin/003cleanupscript.pl -- Compares 001 and 003 fields, cleans mismatched 003s and outputs to MARC-format file and reports unmatched 003s.
 -bin/007cleanupscript.pl -- Check validity of each 007 value (uses MARC::Lintadditions).
Reports any records needing manual correcting (outputs these to file).
Cleans fields with valid values, but that are too long, and outputs these to separate file.
 -bin/010cleanupscript.pl -- Fixes spacing problems in 010 subfield a.
 -bin/cleantrailingspaces.pl -- Looks for extra spaces at the end of fields greater than 010 (ignores 016), removes unnecessary spaces, outputs records that have been cleaned.

=head1 SYNOPSIS

 use MARC::Batch;
 use MARC::Errorchecks;

 #See also MARC::Lintadditions for more checks
 #use MARC::Lintadditions;

 #change file names as desired
 my $inputfile = 'marcfile.mrc';
 my $errorfilename = 'errors.txt';
 my $errorcount = 0;
 open (OUT, ">$errorfilename");
 #initialize $infile as new MARC::Batch object
 my $batch = MARC::Batch->new('USMARC', "$inputfile");
 my $errorcount = 0;
 #loop through batch file of records
 while (my $record = $batch->next()) {
  #if $record->field('001') #add this if some records in file do not contain an '001' field
  my $controlno = $record->field('001')->as_string();   #call MARC::Errorchecks subroutines

  my @errorstoreturn = ();

  # check everything

  push @errorstoreturn, (@{MARC::Errorchecks::check_all_subs($record)});

  # or only a few
  push @errorstoreturn, (@{MARC::Errorchecks::check_010($record)});
  push @errorstoreturn, (@{MARC::Errorchecks::check_bk008_vs_bibrefandindex($record)});

  # report results
  if (@errorstoreturn){
   #########################################
   print OUT join( "\t", "$controlno", @errorstoreturn, "\t\n");

   $errorcount++;
  }

 } #while

=cut
