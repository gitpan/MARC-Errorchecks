#!/usr/bin/perl -w

package MARC::Errorchecks;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require AutoLoader;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. @EXPORT = qw();



$VERSION = 1.04;

=head1 NAME

MARC::Errorchecks

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

=head1 TO DO

Maintain check-all subroutine, a wrapper that calls all the subroutines in Errorchecks, to simplify calling code in .pl.

Verify each of the codes in the data against current lists and lists of changes. Maintain code list data when future changes occur.
Possibly move the code list data into a separate file (e.g., MARC::Errorchecks::CodeData)

Determine whether extra tabs are being added to warnings.
Examine how warnings are returned and see if a better way is available.

Add functionality.

 -Ending punctuation (in Lintadditions.pm, and 300 dealt with here, and now 5xx (some)).
 -Matching brackets and parentheses in fields?
 -Geographical headings miscoded as subjects.
 
 Possibly rewrite as object-oriented?
 If not, optimize this and the Lintadditions.pm checks.
 Example: reduce number of repeated breaking-out of fields into subfield parts.
 So, subroutines that look for double spaces and double punctuation might be combined.

Deal with other TO DO items found below.
This includes fixing problem of "bibliographical references" being required if 008 contents has 'b'.

=cut

#########################################
########## Initial includes #############
#########################################

use MARC::Record;

#########################################
#########################################
#########################################

#########################################

=head2 check_all_subs

Calls each error-checking subroutine in Errorchecks.
Gathers all errors and returns those errors in an array (reference).

=head2 TO DO (check_all_subs)

Make sure to update this subroutine as additional subroutines are added.

=cut

sub check_all_subs {

	my $record = shift;
	my @errorstoreturn = ();

	#call each subroutine and add its errors to @errorstoreturn

	push @errorstoreturn, (@{check_internal_spaces($record)});

	push @errorstoreturn, (@{check_trailing_spaces($record)});

	push @errorstoreturn, (@{check_double_periods($record)});

	push @errorstoreturn, (@{check_008($record)});

	push @errorstoreturn, (@{check_010($record)});

	push @errorstoreturn, (@{check_end_punct_300($record)});

	push @errorstoreturn, (@{check_bk008_vs_300($record)});

	push @errorstoreturn, (@{check_490vs8xx($record)});

	push @errorstoreturn, (@{check_240ind1vs1xx($record)});

	push @errorstoreturn, (@{check_245ind1vs1xx($record)});

	push @errorstoreturn, (@{matchpubdates($record)});

	push @errorstoreturn, (@{check_bk008_vs_bibrefandindex($record)});

	push @errorstoreturn, (@{check_041vs008lang($record)});

	push @errorstoreturn, (@{check_5xxendingpunctuation($record)});

	push @errorstoreturn, (@{findfloatinghypens($record)});

	push @errorstoreturn, (@{video007vs300vs538($record)});

	push @errorstoreturn, (@{ldrvalidate($record)});

	push @errorstoreturn, (@{geogsubjvs043($record)});

	push @errorstoreturn, (@{findemptysubfields($record)});

	push @errorstoreturn, (@{check_040present($record)});

	push @errorstoreturn, (@{check_nonpunctendingfields($record)});

	push @errorstoreturn, (@{check_fieldlength($record)});

## add more here ##
##push @errorstoreturn, (@{});

	return \@errorstoreturn;

} # check_all_subs


#########################################
#########################################
#########################################
#########################################



#########################################
#########################################
#########################################
#########################################

=head2 check_double_periods($record)

Looks for more than one period within subfields after 010.
Exception: Exactly 3 periods together are treated as ellipses.

Looks for multiple commas.

=head2 TO DO (check_double_periods)

Find exceptions where double periods may be allowed.
Find exceptions where more than 3 periods can be next to each other.
Deal with the exceptions.

=cut

sub check_double_periods {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();


	#get all fields in record
	my @fields = $record->fields();

	foreach my $field (@fields) {
		#skip tags lower than 011
		next if ($field->tag() <= 10);

		my @subfields = $field->subfields();
		my @newsubfields = ();

		#break subfields into code-data array (so the entire field is in one array)
		while (my $subfield = pop(@subfields)) {
			my ($code, $data) = @$subfield;
			unshift (@newsubfields, $code, $data);
		} # while

		#examine data portion of each subfield
		for (my $index = 1; $index <=$#newsubfields; $index+=2) {
			my $subdata = $newsubfields[$index];
			#report subfield data with more than one period but not exactly 3
			if (($subdata =~ /\.\.+/) && ($subdata !~ /\.\.\.[^\.]*/)) { 

				push @warningstoreturn, join '', ($field->tag(), ": has multiple consecutive periods that do not appear to be ellipses.");

			} #if has multiple periods
			#report subfield data with more than one comma
			if ($subdata =~ /\,\,+/) { 

				push @warningstoreturn, join '', ($field->tag(), ": has multiple consecutive commas.");

			} #if has multiple commas
		} #for each subfield
	} #for each field

	return \@warningstoreturn;


} # check_double_periods

#########################################
#########################################
#########################################
#########################################

=head2 check_internal_spaces($record)

Looks for more than one space within subfields after 010.
Ignores 035 field, since multiple spaces could be allowed.

=head2 TO DO (check_internal_spaces)

=cut

sub check_internal_spaces {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#get all fields in record
	my @fields = $record->fields();

	foreach my $field (@fields) {
		#skip tags lower than 011
		next if ($field->tag() <= 10);
		#skip 035 field as well
		next if ($field->tag() == 35);
		#skip 787 field as well
		next if ($field->tag() == 787);

		my @subfields = $field->subfields();
		my @newsubfields = ();

		#break subfields into code-data array (so the entire field is in one array)
		while (my $subfield = pop(@subfields)) {
			my ($code, $data) = @$subfield;
			unshift (@newsubfields, $code, $data);
		} # while

		#examine data portion of each subfield
		for (my $index = 1; $index <=$#newsubfields; $index+=2) {
			my $subdata = $newsubfields[$index];

			#report subfield data with more than one space
			if ($subdata =~ /  +/) {
				push @warningstoreturn, join '', ($field->tag(), ": has multiple internal spaces.");
			} #if has multiple spaces

########################################
### added check for space at beginning of field
########################################
			if ($subdata =~ /^ /) {
				#skip 016 field
				return \@warningstoreturn if ($field->tag() == 16);
				push @warningstoreturn, join '', ($field->tag(), ": Subfield starts with a space.");
			} #if has multiple spaces
########################################
########################################

		} #for each subfield
	} #for each field

	return \@warningstoreturn;

} # check_internal_spaces

#########################################
#########################################
#########################################
#########################################

=head2 check_trailing_spaces($record)

Looks for extra spaces at the end of fields greater than 010.
Ignores 016 extra space at end.

=head2 TO DO (check_trailing_spaces)

Rewrite to incorporate 010 and 016 space checking.

Consider allowing trailing spaces in 035 field.

=cut

sub check_trailing_spaces {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#look at each field in record
	foreach my $field ($record->fields()) {
		#skip control fields and LCCN (010)
		next if ($field->tag()<=10);
		#skip 016 fields
		next if ($field->tag() == 16);

		#create array holding arrayrefs for subfield code and data
		my @subfields= $field->subfields();

		#look at data in last subfield
		my $lastsubfield = pop (@subfields);

		#each $subfield is an array ref containing a subfield code character and subfield data
		my ($code, $data) = @$lastsubfield;

		#look for one or more instances of spaces at end of subfield data
		if ($data =~ /\s+$/) {
			#field had extra spaces
			push @warningstoreturn, join '', ($field->tag(), ": has trailing spaces.");
		} #if had extra spaces
	} #foreach field

	return \@warningstoreturn;

} # check_trailing_spaces

#########################################
#########################################
#########################################
#########################################

=head2 check_008($record)

Code for validating 008s in MARC records.
Validates each byte of the 008, based on MARC::Errorchecks::validate008($field008, $mattype, $biblvl)

=head2 TO DO (check_008)

Improve validate008 subroutine (see that sub for more information):
 -Break byte 18-34 checking into separate sub so it can be used for 006 validation as well.
 -Optimize efficiency.

Revised 12-2-2004 to use new validate008() sub.
 
=cut

sub check_008 {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	# set variables needed for 008 validation
	my $leader = $record->leader();
	#$mattype and $biblvl are from LDR/06 and LDR/07
	my $mattype = substr($leader, 6, 1); 
	my $biblvl = substr($leader, 7, 1);
	my $field008 = $record->field('008')->as_string();

	#call validate008 subroutine from Errorchecks.pm (this package)
	@warningstoreturn = @{MARC::Errorchecks::validate008($field008, $mattype, $biblvl)};

	return \@warningstoreturn;

} # check_008

#########################################
#########################################
#########################################
#########################################

=head2 check_010($record)

Verifies 010 subfield 'a' has proper spacing.

=head2 TO DO (check_010)

Think about whether subfield 'z' needs proper spacing.

Deal with non-digit characters in original 010a field.
Currently these are simply reported and the space checking is skipped.

Maintain date ranges in checking validity of numbers.

Modify date ranges according to local catalog needs.

Determine whether this subroutine can be implemented in MARC::Lintadditions/Lint--I don't remember why it is here rather than there?

=cut


sub check_010 {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

##############################################
## Declare variables needed for each record ##
##############################################

	# $field_010 will have MARC::Field version of the 010 field of the record
	my $field_010;
	#$cleaned010a will have the finished cleaned 010a data
	my $cleaned010a;

	#skip records with no 010 and no 010$a
	unless (($record->field('010')) && ($record->field('010')->subfield('a'))) {return \@warningstoreturn;}

	# record has an 010 with subfield a, so check for errors and then do cleanup
	else {

		$field_010 = $record->field('010');
		# $orig010a contains base subfield 'a' for comparison
		my $orig010a = $field_010->subfield('a');
		# $subfielda will be cleaned and then compared with the original
		my $subfielda = $field_010->subfield('a');

		#Get number portion of subfield
		$subfielda =~ s/\D*(\d{8,10})\D*/$1/;
		#report error if 8-10 digit number was not found
		unless ($1) {push @warningstoreturn, ("010: Could not find an 8-10 digit number in subfield 'a'.");}

#######################################################
# LCCN validity checks and setting of cleaned version # 
#######################################################
		#check validity of resulting digits
		if ($subfielda =~ /^\d{8}$/) {
			my $year = substr($subfielda, 0, 2);
			#should be old lccn, so first 2 digits are 00 or > 80
			#The 1980 limit is a local practice.
			#Change the date ranges according to local needs (e.g. if LC records back to 1900 exist in the catalog, eliminate this section of the error check)
			if (($year >= 1) && ($year < 80)) {push @warningstoreturn, ("010: First digits of LCCN are $year.");}
			#otherwise, 8 digit lccn needs 3 spaces before, 1 after, so put that in $cleaned010a
			else {
				$cleaned010a = "   $subfielda ";
			} #else $subfielda has valid lccn
		} #if lccn is 8 digits

		#otherwise if $subfielda is 10 digits
		elsif ($subfielda =~ /^\d{10}$/) {
			my $year = substr($subfielda, 0, 4);
			# no valid 10 digit will be less than 2001
#########################################
# change upper limit as years progress
#########################################
			if (($year < 2001) || ($year > 2006)) {push @warningstoreturn, ("010: First digits of LCCN are $year");}
			#otherwise, 10 digit lccn needs 2 spaces before, 0 after, so put that in $cleaned010a
			else {
				$cleaned010a = "  $subfielda";
			} #else $subfielda has valid lccn
		} #elsif lccn is 10 digits

		# lccn is not 8 or 10 digits so report error
		else {push @warningstoreturn, ("010: LCCN subfield 'a' is not 8 or 10 digits");}

		#return if warnings have been found to this point
		if (@warningstoreturn) {return \@warningstoreturn;}

###########################################
### Compare cleaned field with original ###
###########################################

		#if original and cleaned match, go to next record
		if ($orig010a eq $cleaned010a) {return \@warningstoreturn;}

		#if cleaned version does not match original, report this error
		else {
			#but only if $orig010a has no non-digitchars
			if ($orig010a !~ /^[ \d]*$/) {push @warningstoreturn, ("010: Subfield 'a' has non-digits.");} #if non-digits
			else {
				push @warningstoreturn, ("010: Subfield 'a' has improper spacing.");
			} #else improper spacing
		} #else original and cleaned 010 do not match
	} # else record has 010subfielda


	return \@warningstoreturn;


} # check_010

#########################################
#########################################
#########################################
#########################################

=head2 NAME

check_end_punct_300($record)

=head2 DESCRIPTION

Reports an error if an ending period in 300 is missing if 4xx exists, or if 300 ends with closing parens-period if 4xx does not exist.

=cut


sub check_end_punct_300 {

	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#get leader and retrieve its relevant bytes
	my $leader = $record->leader();
	#$encodelvl ('8' for CIP, ' ' [space] for 'full')
	my $encodelvl = substr($leader, 17, 1);


	#skip CIP-level records
	if ($encodelvl eq '8') {return \@warningstoreturn;}

	#retrieve any 4xx fields in record
	my @fields4xx = $record->field('4..');

	if ($record->field('300')) {
		my $field300 = $record->field('300');
		my @subfields = $field300->subfields();
		my @newsubfields = ();
	
		#break down code and data for last subfield
		my $subfield = pop(@subfields);
		my ($code, $data) = @$subfield;
		unshift (@newsubfields, $code, $data);

		#last subfield should end in period if 4xx exists
		if (@fields4xx && ($newsubfields[-1] !~ /\.$/)) {
			push @warningstoreturn, ("300: 4xx exists but 300 does not end with period.");
		}
		#last subfield should not end in closing parens-period unless 4xx exists
		elsif (($newsubfields[-1] =~ /\)\.$/) && !(@fields4xx)) {push @warningstoreturn, ("300: 4xx does not exist but 300 ends with parens-period."); 
		}
	} #if 300 field exists

####testing ######
# see what records have no 300
	else {push @warningstoreturn, ("300: Record has no 300.");}
##########################################

	# report any errors
	return \@warningstoreturn;

} # check_end_punct_300

#########################################
#########################################
#########################################
#########################################

=head2 NAME

check_bk008_vs_300($record)

=head2 DESCRIPTION

300 subfield 'b' vs. presence of coding for illustrations in 008/18-21.

Ignores CIP records completely.
Ignores non-book records completely (for the purposes of this subroutine).

If 300 'b' has wording, reports errors if matching 008/18-21 coding is not present.
If 008/18-21 coding is present, but similar wording is not present in 300, reports errors.

Note: plates are an exception, since they are noted in $a rather than $b of the 300.
So, they need to be checked twice--once if 'f' is the only code in the 008/18-21, and again amongst other codes.

Also checks for 'p.' or 'v.' in subfield 'a'

=head2 LIMITATIONS

Only accounts for a single 300 field (300 was recently made repeatable).

Older/more specific code checking is limited due to lack of use (by our catalogers).
For example, coats of arms, facsim., etc. are usually now given as just 'ill.'
So the error check allows either the specific or just ill. for all except maps.

Depends upon 008 being coded for book monographs.

Subfield 'a' and 'c' wording checks ('p.' or 'v.'; 'cm.', 'in.', 'mm.') only look at first of each kind of subfield.

=head2 TO DO (check_bk008_vs_300($record))

Take care of case of 008 coded for serials/continuing resources.

Find exceptions to $a having 'p.' or 'v.' for books.

Find exceptions to $c having 'cm.', 'mm.', or 'in.' preceded by digits.

Deal with other LIMITATIONS.

Account for upcoming rule change in which metric units have no punctuation.
When that rule goes into effect, move 300$c checking to check_end_punct_300($record).

Reverse checks to report missing 008 code if specific wording is present in 300.

Reverse check for plates vs. 'f'

=cut

sub check_bk008_vs_300 {

	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#get leader and retrieve its relevant bytes (mattype ('a' for 'books')), 
	#$encodelvl ('8' for CIP, ' ' [space] for 'full')
	#$biblvl will be useful in future version, where seriality matters

	my $leader = $record->leader();
	my $mattype = substr($leader, 6, 1); 
	#my $biblvl = substr($leader, 7, 1);
	my $encodelvl = substr($leader, 17, 1);


	#skip CIP-level records
	if ($encodelvl eq '8') {return \@warningstoreturn;
	}
#####################################
#####################################
### skip non-book records for now ###
	elsif ($mattype ne 'a') {return \@warningstoreturn;}
#####################################
#####################################
	#otherwise, match 008/18-21 vs. 300.
	else {

		my $field008 = $record->field('008')->as_string();
		#illustration codes are in bytes 18-21
		my $illcodes = substr($field008, 18, 4);
		my ($hasill, $hasmap, $hasport, $hascharts, $hasplans, $hasplates, $hasmusic, $hasfacsim, $hascoats, $hasgeneal, $hasforms, $hassamples, $hasphono, $hasphotos, $hasillumin);

		#make sure field 300 exists
		if ($record->field('300')) {
			#get 300 field as a MARC::Field object
			my $field300 = $record->field('300');
			#set variables for 
			my $subfielda = $field300->subfield('a') if ($field300->subfield('a'));
			my $subfieldb = $field300->subfield('b') if ($field300->subfield('b'));
			my $subfieldc = $field300->subfield('c') if ($field300->subfield('c'));

#######################################
### 300 subfield 'a' and 'c' checks ###
#######################################

			#Check for 'p.' or 'v.' or leaves in subfield 'a'
			if ($subfielda) {
				push @warningstoreturn, ("300: Check subfield _a for p. or v.") unless (($subfielda =~  /\(?.*\b[pv]\.[,\) ]?/)||($subfielda =~/ leaves / && ($subfielda !~ / leaves of plates/)));
			}
			#report missing subfield a
			else {
				push @warningstoreturn, ("300: Subfield _a is not present.");
			} #else $subfielda is undefined

			#check for 'cm.', 'mm.' or 'in.' in subfield 'c'
			if ($subfieldc) {
				push @warningstoreturn, ("300: Check subfield _c for cm., mm. or in.") unless ($subfieldc =~ /\d+ (([cm]m\.)|(in\.))/);
			}
			#report missing subfield c
			else {
				push @warningstoreturn, ("300: Subfield _c is not present.");
			} #else $subfieldc is undefined
#######################################

##### 008 ill. vs. 300 wording basic checks 
			# if $illcodes not coded and no subfield 'b' no problem so move on
			if (($illcodes =~ /^\s{4}$/) && !($subfieldb)) {return \@warningstoreturn;} 
			# 008 is coded blank (4 spaces) but 300 subfield 'b' exists so error
			elsif (($illcodes =~ /^\s{4}$/) && ($subfieldb)) {push @warningstoreturn, ("008: bytes 18-21 (Illustrations) coded blank but 300 has subfield 'b'."); return \@warningstoreturn;} 
			# 008 has valid code but no 300 subfield 'b' so error
			elsif (($illcodes =~ /[a-e,g-m,o,p]/) && !($subfieldb)) {push @warningstoreturn, ("008: bytes 18-21 (Illustrations) have valid code but 300 has no subfield 'b'."); return \@warningstoreturn;} 

##############
			#otherwise, check 008/18-21 vs. 300 subfield 'b'
			# valid coding in 008/18-21 and have 300 $b
			elsif (($illcodes =~ /[a-e,g-m,o,p]/) && ($subfieldb)) {
				# start comparing
				#call subroutine to do main checking
				my $illcodewarnref = parse008vs300b($illcodes, $subfieldb);
				push @warningstoreturn, (join "\t", @$illcodewarnref) if (@$illcodewarnref);

				#take care of special case of plates when other codes are present
				if (($illcodes =~ /f/) && ($subfielda)) {
					#report error if 'plate' does not appear in 300$a
					unless ($subfielda =~ /plate/) {push @warningstoreturn, ("300: bytes 18-21 (Illustrations) is coded f for plates but 300 subfield a is $subfielda "); 
					} #unless subfield 'a' has plate(s)
				} #if 008ill. has 'f' but 300 does not have 'plate'(s) 
			} #elsif valid 008/18-21 and 300$b exists

			#elsif $illcodes is coded only 'f' (plates), which are noted in 300$a
			elsif (($illcodes =~ /f/) && ($subfielda)) {
				#report error if 'plate' does not appear in 300$a
				unless ($subfielda =~ /plate/) {
					push @warningstoreturn, ("300: bytes 18-21 (Illustrations) is coded f for plates but 300 subfield a is $subfielda "); 
					return \@warningstoreturn;
				} #unless subfield 'a' has plate(s)
			} #elsif 008ill. has 'f' but 300a does not have 'plate'(s)

			#otherwise, not valid 008/18-21
			else {
				push @warningstoreturn, ("008: bytes 18-21 (Illustrations) have a least one invalid character."); return \@warningstoreturn;
			} #else not valid 008/18-21
		} # if record has 300 field

		#else 300 does not exist in full book record so report error
		else {push @warningstoreturn, ("300: Record has no 300."); return \@warningstoreturn;}
	} #else (record is not CIP and is a book-type)

	return \@warningstoreturn;

} # check_bk008_vs_300($record)

#########################################
#########################################
#########################################
#########################################

=head2 NAME

 parse008vs300b($illcodes, $field300subb)
 
=head2 DESCRIPTION

008 illustration parse subroutine

checks 008/18-21 code against 300 $b

=head2 WHY?

To simplify the check_bk008_vs_300($record)  subroutine, which had many if-then statements. This moves the additional checking conditionals out of the way.
It may be integrated back into the main subroutine once it works.
This was written while constructing check_bk008_vs_300($record) as a separate script.

=head2 Synopsis/Usage description

	parse008vs300b($illcodes, $field300subb)

 #$illcodes is bytes 18-21 of 008
 #$subfieldb is subfield 'b' of record's 300 field

=head2 TO DO (parse008vs300b($$))

Integrate code into check_bk008_vs_300($record)?

Verify possibilities for 300 text

Move 'm' next to 'f' since it is likely to be indicated in subfield 'e' not 'b' of the 300.
Our catalogers do not generally code for sound recordings in this way in book records.

=cut

sub parse008vs300b {

	my $illcodes = shift;
	my $subfieldb = shift;
	#parse $illcodes
	my ($hasill, $hasmap, $hasport, $hascharts, $hasplans, $hasplates, $hasmusic, $hasfacsim, $hascoats, $hasgeneal, $hasforms, $hassamples, $hasphono, $hasphotos, $hasillumin);
	($illcodes =~ /a/) ? ($hasill = 1) : ($hasill = 0);
	($illcodes =~ /b/) ? ($hasmap = 1) : ($hasmap = 0);
	($illcodes =~ /c/) ? ($hasport = 1) : ($hasport = 0);
	($illcodes =~ /d/) ? ($hascharts = 1) : ($hascharts = 0);
	($illcodes =~ /e/) ? ($hasplans = 1) : ($hasplans = 0);
	($illcodes =~ /f/) ? ($hasplates = 1) : ($hasplates = 0);
	($illcodes =~ /g/) ? ($hasmusic = 1) : ($hasmusic = 0);
	($illcodes =~ /h/) ? ($hasfacsim = 1) : ($hasfacsim = 0);
	($illcodes =~ /i/) ? ($hascoats = 1) : ($hascoats = 0);
	($illcodes =~ /j/) ? ($hasgeneal = 1) : ($hasgeneal = 0);
	($illcodes =~ /k/) ? ($hasforms = 1) : ($hasforms = 0);
	($illcodes =~ /l/) ? ($hassamples = 1) : ($hassamples = 0);
	($illcodes =~ /m/) ? ($hasphono = 1) : ($hasphono = 0);
	($illcodes =~ /o/) ? ($hasphotos = 1) : ($hasphotos = 0);
	($illcodes =~ /p/) ? ($hasillumin = 1) : ($hasillumin = 0);

	my @illcodewarns = ();

	# Check and report errors

	#if 008/18-21 has code 'a', 300$b needs to have 'ill.'
	if ($hasill) {
		push @illcodewarns, ("300: bytes 18-21 have code 'a' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /ill\./);}
	# if 300$b has 'ill.', 008/18-21 should have 'a'
	elsif ($subfieldb =~ /ill\./) {push @illcodewarns, ("008: Bytes 18-21 do not have code 'a' but 300 subfield 'b' has 'ill.'")}

	#if 008/18-21 has code 'b', 300$b needs to have 'map' (or 'maps') 
	if ($hasmap) {push @illcodewarns, ("300: bytes 18-21 have code 'b' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /map/);}
	# if 300$b has 'map', 008/18-21 should have 'b'
	elsif ($subfieldb =~ /map/) {push @illcodewarns, ("008: Bytes 18-21 do not have code 'b' but 300 subfield 'b' has 'map' or 'maps'")}

	#if 008/18-21 has code 'c', 300$b needs to have 'port.' or 'ports.' (or ill.) 
	if ($hasport) {push @illcodewarns, ("300: bytes 18-21 have code 'c' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /port\.|ports\.|ill\./);}
	# if 300$b has 'port.' or 'ports.', 008/18-21 should have 'c'
	elsif ($subfieldb =~ /port\.|ports\./) {push @illcodewarns, ("008: Bytes 18-21 do not have code 'c' but 300 subfield 'b' has 'port.' or 'ports.'")}

	#if 008/18-21 has code 'd', 300$b needs to have 'chart' (or 'charts') (or ill.) 
	if ($hascharts) {push @illcodewarns, ("300: bytes 18-21 have code 'd' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /chart|ill\./);}
	#### add cross-check ###


	#if 008/18-21 has code 'e', 300$b needs to have 'plan' (or 'plans') (or ill.) 
	if ($hasplans) {push @illcodewarns, ("300: bytes 18-21 have code 'e' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /plan|ill\./);}
	#### add cross-check ###

	### Skip 'f' for plates, which are in 300$a ###

	#if 008/18-21 has code 'g', 300$b needs to have 'music' (or ill.) 
	if ($hasmusic) {push @illcodewarns, ("300: bytes 18-21 have code 'g' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /music|ill\./);}
	# if 300$b has 'music', 008/18-21 should have 'g'
	elsif ($subfieldb =~ /music/) {push @illcodewarns, ("008: Bytes 18-21 do not have code 'g' but 300 subfield 'b' has 'music'")}

	#if 008/18-21 has code 'h', 300$b needs to have 'facsim.' or 'facsims.' (or ill.) 
	if ($hasfacsim) {push @illcodewarns, ("300: bytes 18-21 have code 'h' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /facsim\.|facsims\.|ill\./);}
	#### add cross-check ###

	#if 008/18-21 has code 'i', 300$b needs to have 'coats of arms' (or 'coat of arms'?) (or ill.) 
	if ($hascoats) {push @illcodewarns, ("300: bytes 18-21 have code 'i' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /coats of arms|ill\./);}
	#### add cross-check ###

	#if 008/18-21 has code 'j', 300$b needs to have 'geneal. table' (or 'geneal. tables') (or ill.) 
	if ($hasgeneal) {push @illcodewarns, ("300: bytes 18-21 have code 'j' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /geneal\. table|ill\./);}
	#### add cross-check ###

	#if 008/18-21 has code 'k', 300$b needs to have 'forms' or 'form' (or ill.) 
	if ($hasforms) {push @illcodewarns, ("300: bytes 18-21 have code 'k' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /form[ s]|ill\./);}
	#### add cross-check ###

	#if 008/18-21 has code 'l', 300$b needs to have 'samples' (or ill.) 
	if ($hassamples) {push @illcodewarns, ("300: bytes 18-21 have code 'l' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /samples|ill\./);}
	#### add cross-check ###

##########################################
##########################################
### code 'm' appears to be for 'sound disc', 'sound cartridge', 'sound tape reel', 'sound cassette', 'roll' or 'cylinder'
#these would likely appear in subfield 'e' of the 300 (as accompanying material) for book records.
#so this should be treated separately, like plates ('f')
#This code is not used by our catalogers
	#if 008/18-21 has code 'm', 300$b needs to have 'phono'? (or ill.) 
	if ($hasphono) {push @illcodewarns, ("300: bytes 18-21 have code 'm' (phonodisc, sound disc, etc.).");}
##########################################
##########################################

	#if 008/18-21 has code 'o', 300$b needs to have 'photo.' or 'photos.' (or ill.) 
	if ($hassamples) {push @illcodewarns, ("300: bytes 18-21 have code 'o' but 300 subfield b is $subfieldb") unless ($subfieldb =~ /photo\.|photos\.|ill\./);}
	#### add cross-check ###

##########################################
##########################################
### I don't know what this is, so for this, report all
	#if 008/18-21 has code 'p', 300$b needs to have 'illumin'? (or ill.) 
	if ($hasillumin) {push @illcodewarns, ("300: bytes 18-21 have code 'p' but 300 subfield b is $subfieldb");}
	#### add cross-check ###
##########################################
##########################################

	return \@illcodewarns;

} #sub parse008vs300b


#########################################
#########################################
#########################################
#########################################

=head2 check_490vs8xx($record)

If 490 with 1st indicator '1' exists, then 8xx should exist.

=cut

sub check_490vs8xx {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#report error if 490 1st ind is 1 but 8xx does not exist
	if ($record->field(490) && ($record->field(490)->indicator(1) == 1)) {
		push @warningstoreturn, ("490: Indicator is 1 but 8xx does not exist.") unless ($record->field('8..'));
	}

	return \@warningstoreturn;

} # check_490vs8xx

#########################################
#########################################
#########################################
#########################################

#########################################
#########################################
#########################################
#########################################

=head2 check_240ind1vs1xx($record)

If 1xx exists then 240 1st indicator should be '1'. 
If 1xx does not exist then 240 should not be present.

However, exceptions to this rule are possible, so this should be considered an optional error.

=cut

sub check_240ind1vs1xx {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#report error if 240 exists but 1xx does not exist
	if (($record->field(240)) && !($record->field('1..'))) {
		push @warningstoreturn, ("240: Is present but 1xx does not exist.");
	}
	
	#report error if 240 1st ind is 0 but 1xx exists
	elsif (($record->field(240)) && ($record->field(240)->indicator(1) == 0) && ($record->field('1..'))) {
		push @warningstoreturn, ("240: First indicator is 0 but 1xx exists.");
	}

	return \@warningstoreturn;

} # check_240ind1vs1xx

#########################################
#########################################
#########################################
#########################################

=head2 check_245ind1vs1xx($record)

If 1xx exists then 245 1st indicator should be '1'. 
If 1xx does not exist then 245 1st indicator should be '0'.

However, exceptions to this rule are possible, so this should be considered an optional error.

=cut

sub check_245ind1vs1xx {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#report error if 245 1st ind is 1 but 1xx does not exist
	if (($record->field(245)->indicator(1) == 1)) {
		push @warningstoreturn, ("245: Indicator is 1 but 1xx does not exist.") unless ($record->field('1..'));
	}
	#report error if 245 1st ind is 0 but 1xx exists
	elsif (($record->field(245)->indicator(1) == 0)) {
		push @warningstoreturn, ("245: Indicator is 0 but 1xx exists.") if ($record->field('1..'));
	}

	return \@warningstoreturn;

} # check_245ind1vs1xx

#########################################
#########################################
#########################################
#########################################


=head2 matchpubdates($record)

Date matching 008, 050, 260

Attempts to match date of publication in 008 date1, 050 subfield 'b', and 260 subfield 'c'.

Reports errors when one of the fields does not match.
Reports errors if one of the dates cannot be found

Handles cases where 050 or 260 (or 260c) does not exist.
-Currently if the subroutine is unable to get either the date1, any 050 with $b, or a 260 with $c, it returns (exits).
-Future, or better, behavior, might be to continue processing for the other fields.

Handles cases where 050 is different due to conference dates.
Conference exception handling is currently limited to presence of 111 field or 110$d.


=head2 KNOWN PROBLEMS

May not deal well with serial records (problem not even approached).

Only examines 1st 260, does not account for more than one 260 (recent addition).

Relies upon 260$c date being the first date in the last 260$c subfield.

Has problem finding 050 date if it is not last set of digits in 050$b.

Process of getting 008date1 duplicates similar check in C<validate_008> subroutine.

=head2 TO DO

Improve Conference publication checking (limited to 111 field or 110$d being present for this version)
This may include comparing 110$d or 111$d vs. 050, and then comparing 008date1 vs. 260$c.

Fix parsing for 050$bdate.

For CIP, if 260 does not exist, compare only 050 and 008date1.
Currently, CIP records without 260 are skipped.

Account for undetermined dates, e.g. [19--?] in 260 and 008.

Account for older 050s with no date present.

=cut

sub matchpubdates {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#get leader and retrieve its relevant bytes, 
	#$encodelvl ('8' for CIP, ' ' [space] for 'full')

	my $leader = $record->leader();
	my $encodelvl = substr($leader, 17, 1);

########################################
####### may be used in future ##########
# my $mattype = substr($leader, 6, 1); # 
# my $biblvl = substr($leader, 7, 1);  #
########################################

	#skip CIP-level records unless 260 exists
	if ($encodelvl eq '8') {return \@warningstoreturn  unless ($record->field('260'));}

	my $field008 = $record->field('008')->as_string();
	#date1 is in bytes 7-10
	my $date1 = substr($field008, 7, 4);

	#report error in getting $date1
	## then ignore the rest of the record
	###need to account for dates such as '19--'
	unless ($date1 && ($date1 =~ /^\d{4}$/)) {push @warningstoreturn, ("008: Could not get date 1."); return \@warningstoreturn;
	} 

	#get 050(s) if it (they) exist(s)
	my @fields050 = $record->field('050') if (($record->field('050')) && $record->field('050')->subfield('b'));
	#report error in getting at least 1 050 with subfield _b
	##then ignore the rest of the record
	unless (@fields050) {push @warningstoreturn, ("050: Could not get 050 or 050 subfield 'b'."); return \@warningstoreturn;
	}

	#get 050 date, make sure each is the same if there are multiple fields

	my @dates050 = ();
	#look for date at end of $b in each 050
	foreach my $field050 (@fields050) {
		if ($field050->subfield('b')) {
			my $subb050 = $field050->subfield('b');
			#remove nondigits and look for 4 digits
			$subb050 =~  s/^.*?\b(\d{4}){1}\D*.*$/$1/;
			#add each found date to @dates050
			push @dates050, ($subb050) if ($subb050 =~ /\d{4}/);
		} # if 050 has $b
	} #foreach 050 field

	#compare each date in @dates050
	while (scalar @dates050 > 1) {
		#compare first and last
		($dates050[0] == $dates050[-1]) ? (pop @dates050) : (push @warningstoreturn, ("050: Dates do not match in each of the 050s."));
		#stop comparing if dates don't match
		last if @warningstoreturn;
	} # while  @dates050 has more than 1 date

	my $date050;

	#if successful, only one date will remain and @warningstoreturn will not have an 050 error
	if (($#dates050 == 0) && ((join "\t", @warningstoreturn) !~ /Dates do not match in each of the 050s/)) {

		# set $date050 to the date in @dates050 if it is exactly 4 digits
		if ($dates050[0] =~ /^\d{4}$/) {$date050 = $dates050[0];}
		else {push @warningstoreturn, ("050: Unable to find 4 digit year in subfield 'b'."); 
			return \@warningstoreturn;
		} #else
	} #if have 050 date without error 

	#get 260 field if it exists and has a subfield 'c'
	my $field260 = $record->field('260') if (($record->field('260')) && $record->field('260')->subfield('c'));
	unless ($field260) {push @warningstoreturn, ("260: Could not get 260 or 260 subfield 'c'."); return \@warningstoreturn;
	}

	#look for date in 260 _c (starting at the end of the field)
	##only want first date in last subfield _c

	my @subfields = $field260->subfields();
	my @newsubfields = ();
	my $wantedsubc;
	#break subfields into code-data array
	#stop when first subfield _c is reached (should be the last subfield _c of the field)
	while (my $subfield = pop(@subfields)) {
		my ($code, $data) = @$subfield;
		if ($code eq 'c' ) {$wantedsubc = $data; last;}
		#should not be necessary to rebuild 260
		#unshift (@newsubfields, $code, $data);
	} # while

	my $date260;

	#extract 4 digit date portion
	# account for [i.e. [date]]
	unless ($wantedsubc =~ /\[i\..?e\..*(\d{4}).*?\]/) {
		$wantedsubc =~ s/^.*?\b\D*(\d{4})\D*\b.*$/$1/;
}
	else {$wantedsubc =~ s/.*?\[i\..?e\..*(\d{4}).*?\].*/$1/;
}


	if ($wantedsubc =~ /^\d{4}$/) {$date260 = $wantedsubc;}
# i.e. date should be 2nd string of 4 digits
	elsif ($wantedsubc =~ /^\d{8}$/) {$date260 = substr($wantedsubc,4,4);}
	else {push @warningstoreturn, ("260: Unable to find 4 digit year in subfield 'c'."); return \@warningstoreturn;
	}

#####################################
#####################################
### to skip non-book records: ###
#if ($mattype ne 'a') {return \@warningstoreturn;}
#####################################
#####################################


##############################################
### Check for conference publication here ####
##############################################
	my $isconfpub = 0;

	if (($record->field(111)) || ($record->field(110) && $record->field(110)->subfield('d'))) {$isconfpub = 1;}

	#match 008 $date1, $date050, and $date260 unless record is for conference.
	unless ($isconfpub == 1) {
		unless ($date1 == $date050 && $date050 == $date260) {
			push @warningstoreturn, ("Pub. Dates: 008 date1, $date1, 050 date, $date050, and 260_c date, $date260 do not match."); return \@warningstoreturn;

		} #unless all three match
	} #unless conf
	# otherwise for conf. publications match only $date1 and $date260
	else {
		unless ($date1 == $date260) {
			push @warningstoreturn, ("Pub. Dates: 008 date1, $date1 and 260_c date, $date260 do not match."); return \@warningstoreturn;
		} #unless conf with $date1 == $date260
	} #else conf

	return \@warningstoreturn;

} # matchpubdates


#########################################
#########################################
#########################################
#########################################

=head2 check_bk008_vs_bibrefandindex($record)

 Ignores non-book records (other than cartographic materials).
 For cartographic materials, checks only for index coding (not bib. refs.).

 Examines 008 book-contents (bytes 24-27) and book-index (byte 31).
 Compares with 500 and 504 fields.
 Reports error if 008contents has 'b' but 504 does not have "bibliographical references."
 Reports error if 504 has "bibliographical references" but no 'b' in 008contents.
 Reports error if 008index has 1 but no 500 or 504 with "Includes .* index."
 Reports error if a 500 or 504 has "Includes .* index" but 008index is 0. 
 Reports error if "bibliographical references" appears in 500.
 Allows "bibliographical reference."

=head2 TO DO/KNOWN PROBLEMS

 As with other subroutines, this one treats all 008 as being coded for monographs.
 Serials are ignored for the moment.

 Account for records with "Bibliography" or other wording in place of "bibliographical references."
 Currently 'b' in 008 must match with "bibliographical reference" or "bibliographical references" in 504 (or 500--though that reports an error).

 Reverse check for other wording (or subject headings) vs. 008 'b' in contents.

 Check for other 008contents codes.

 Check for misspelled "bibliographical references."

 Check spacing if pagination is given in 504.

=cut

sub check_bk008_vs_bibrefandindex {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();


	my $leader = $record->leader();
	my $mattype = substr($leader, 6, 1); 
	#skip non-book (other than cartographic) records
	if ($mattype !~ /^[ae]$/) {return \@warningstoreturn;}

	my $field008 = $record->field('008')->as_string();
	my $bkindex = substr($field008,31,1);
	my $bkcontents = substr($field008,24,4);

#############################
	my @fields500 = ();
	my @fields504 = ();
	my @fields6xx = ();
	foreach my $field500 ($record->field('500')){
		push @fields500, ($field500->as_string());
	}
	foreach my $field504 ($record->field('504')){
		push @fields504, ($field504->as_string());
	}

####################################
### Workaround for bibliography as form of item.
	foreach my $field6xx ($record->field('6..')){
		push @fields6xx, ($field6xx->as_string());
	}
####################################

####################################

########################
## Check index coding ##
########################
	my $hasindexin500or504 = 0;
	#count 500s and 504s with 'Includes' 'index'
	$hasindexin500or504 = grep {$_ =~ /Includes.*index/} @fields500, @fields504;

	if (grep {$_ =~ /^Includes index(es)?\.$/}  @fields504) {
		push @warningstoreturn, ("504: 'Includes index.' or 'Includes indexes.' should be 500.")
	} # if 'Includes index(es).' in 504

	#error if $bkindex is 0 but 500 or 504 "Includes" "index"
	if (($bkindex == 0) && ($hasindexin500or504)) {
		push @warningstoreturn, ("008: Index is coded 0 but 500 or 504 mentions index.");
	} #if $bkindex is 0 but 500 or 504 "Includes" "index"

	#error if $bkindex is 1 but 500 or 504 does not have "Includes" "index"
	elsif (($bkindex == 1) && !($hasindexin500or504)) {
		push @warningstoreturn, ("008: Index is coded 1 but 500 or 504 does not mention index.");
	} #elsif $bkindex is 1 but 500 or 504 does not have "Includes" "index"

###############################

	#return if the $mattype is 'e' (cartographic)
	if ($mattype eq 'e') {return \@warningstoreturn;}

###############################


##########################
## Check bib ref coding ##
##########################

	my $hasbibrefs = 0;
	#set $hasbibrefs to 1 if 'b' appears in 008 byte 24-27
	$hasbibrefs = 1 if ($bkcontents =~ /b/);

	#get 504s with 'bibliographical references' #modified 11-4-04 to add 's?\.?\b'
	my @bibrefsin504 = grep {$_ =~ /bibliographical references?\.?\b/} @fields504;
	#get 500s with 'bibliographical references'
	my @bibrefsin500 = grep {$_ =~ /bibliographical references?\.?\b/} @fields500;
###### Temporary/uncertain method of checking for bibliography as form of item
	my @bib6xx = grep {$_ =~ /bibliography|bibliographies/i} @fields6xx;

	my $bibrefin504 = join '', @bibrefsin504;
	my $bibrefin500 = join '', @bibrefsin500;
	my $isbibliography = join '', @bib6xx;

	#report 500 with "bibliographical references"
	if ($bibrefin500) {
		push @warningstoreturn, ("500: Bibliographical references should be in 504.");
	} #if $bibrefin500

	#report 008contents 'b' but not 504 or 500 with bib refs 
	if (($hasbibrefs == 1) && !(($bibrefin504) || ($bibrefin500) ||($isbibliography))) {
push @warningstoreturn, ("008: Coded 'b' but 504 (or 500) does not mention 'bibliographical references', and 'bibliography' is not present in 6xx.");
} # if 008cont 'b' but not 504 or 500 with bib refs
#report 504 or 500 with bib refs but no 'b' in 008contents
	elsif (($hasbibrefs == 0) && (($bibrefin504) || $bibrefin500)) {
		push @warningstoreturn, ("008: Not coded 'b' but 504 (or 500) mentions 'bibliographical references'.");
	} # if 008cont 'b' but not 504 or 500 with bib refs

	return \@warningstoreturn;
 
} # check_bk008_vs_bibrefandindex

#########################################
#########################################
#########################################
#########################################

=head2 check_041vs008lang($record)

Compares first code in subfield 'a' of 041 vs. 008 bytes 35-37.

=cut

sub check_041vs008lang {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	my $field008 = $record->field('008')->as_string();
	my $langcode008 = substr($field008,35,3);

	#double check that lang code is present with 3 characters
	unless ($langcode008 =~ /^[\w ]{3}$/) {
		push @warningstoreturn, ("008: Could not get language code, $langcode008.");
	}

	#get first 041 subfield 'a' if it exists
	my $first041a;
	if ($record->field('041')) {
		$first041a = $record->field('041')->subfield('a') if ($record->field('041')->subfield('a'));
	}

	#skip records without 041 or 041$a
	unless ($first041a) {return \@warningstoreturn;}
	else {
		my $firstcode = substr($first041a,0,3);
		#compare 008lang vs. 1st 041a code
		unless ($firstcode eq $langcode008) {
			push @warningstoreturn, ("041: First code ($firstcode) does not match 008 bytes 35-37 (Language $langcode008).");
		}
	} # else $first041a exists

	return \@warningstoreturn;

} #check_041vs008lang

#########################################
#########################################
#########################################
#########################################

#########################################
#########################################
#########################################
#########################################

=head2 check_5xxendingpunctuation($record)

Validates punctuation in various 5xx fields.

Currently checks 500, 501, 504, 508, 511, 538, 546.

For 586, see check_nonpunctendingfields($record)

=head2 TO DO (check_5xxendingpunctuation)

Add checks for the other 5xx fields. 

Verify rules for these checks.

=cut

sub check_5xxendingpunctuation {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	my $leader = $record->leader();
	my $encodelvl = substr($leader, 17, 1);

	#check for CIP-level
	my $isCIP = 0;
	if ($encodelvl eq '8') {
		$isCIP = 1;
	}
	# check only certain fields
	my @fieldstocheck = ('500', '501', '504', '520', '538', '546', '508', '511');

	#get fields in @fieldstocheck
	my @fields5xx = $record->field(@fieldstocheck);


	#loop through set of 5xx fields to check in $record
	foreach my $field5xx (@fields5xx) {
		my $tag = $field5xx->tag();
		#skip 500s with LCCN or ISBN in PCIP
		if (($isCIP) && ($tag == 500) && ($field5xx->subfield('a') =~ /^(LCCN)|(ISBN)|(Preassigned)/)) {
		return \@warningstoreturn;
		}

		else {
			#look at last subfield (unless numeric)
			my @subfields = $field5xx->subfields();
			my @newsubfields = ();

			#break subfields into code-data array (so the entire field is in one array)
			while (my $subfield = pop(@subfields)) {
				my ($code, $data) = @$subfield;
				# skip numeric subfields (5)
				next if ($code =~ /^\d$/);

# valid punctuation: /(\)?[\!\?\.]\'?\"?$)/
# so, closing parens (or not), 
#either exclamation point, question mark or period,
#and, optionally, single and/or double quote


			my ($firstchars, $lastchars) = '';
			if (length($data) < 10) {
				#get full subfield if length < 10)
				$firstchars = $data;
				#get full subfield if length < 10)
				$lastchars = $data;
			} #if subfield length < 10
			elsif (length($data) >= 10) {
				#get first 10 chars of subfield
				$firstchars = substr($data,0,10);
				#get last 10 chars of subfield
				$lastchars = substr($data,(length($data)-10),(length($data)));
			} #elsif subfield length >= 10


				unless ($data =~ /(\)?[\!\?\.]\'?\"?$)/) {
					push @warningstoreturn, join '', ($field5xx->tag(), ": Check ending punctuation, ",  $firstchars, " ___ ", $lastchars);
				}
		# stop after first non-numeric
				last;
			} # while
		} # else tag is checkable
		
	} # foreach 5xx field

	return \@warningstoreturn;

} # check_5xxendingpunctuation


#########################################
#########################################
#########################################
#########################################

=head2 findfloatinghypens($record)

Looks at various fields and reports fields with space-hypen-space as errors.

=head2 TO DO (findfloatinghypens($record))

Find exceptions.

=cut

sub findfloatinghypens {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	# add or remove fields to be examined
	my @fieldstocheck = ('245', '246', '500', '501', '505', '508', '511', '520', '538', '546');

	#look at each of the fields
	foreach my $fieldtocheck (@fieldstocheck) {
		my @fields = $record->field($fieldtocheck);
		foreach my $checkedfield (@fields) {
			#get field as a string, without subfield coding
			my $fielddata = $checkedfield->as_string();
			#report error if space-hyphen-space appears in field
			if ($fielddata =~ / \- /) {
				push @warningstoreturn, join '', ($checkedfield->tag(), ": May have a floating hyphen, ",  substr($fielddata,0,(10||length($fielddata))));
			}
		} #foreach $checkedfield
	} #foreach $fieldtocheck

	return \@warningstoreturn;

} # findfloatinghypens

#########################################
#########################################
#########################################
#########################################


=head2 video007vs300vs538($record)

Comparison of 007 coding vs. 300abc subfield data and vs. 538 data for video records (VHS and DVD).

=head2 DESCRIPTION

Focuses on videocassettes (VHS) and videodiscs (DVD and Video CD).
Does not consider coding for motion pictures.

If LDR/06 is 'g' for projected medium,
(skipping those that aren't)
and 007 is present,
at least 1 007 should start with 'v'

If 007/01 is 'd', 300a should have 'videodisc(s)'.
300c should have 4 3/4 in.
Also, 538 should have 'DVD' 
If 007/01 is 'f', 300a should have 'videocassette(s)'
300c should have 1/2 in.
Also, 538 should have 'VHS format' or 'VHS hi-fi format' (case insensitive on hi-fi), plus a playback mode.

=head2 LIMITATIONS

Checks only videocassettes (1/2) and videodiscs (4 3/4).
Current version reports problems with other forms of videorecordings.

Accounts for existence of only 1 300 field.

Looks at only 1st subfield 'a' and 'c' of 1st 300 field.

=head2 TO DO

Account for motion pictures and videorecordings not on DVD (4 3/4 in.) or VHS cassettes.

Check proper plurality of 300a (1 videodiscs -> error; 5 videocassette -> error)

Monitor need for changes to sizes, particularly 4 3/4 in. DVDs.

Expand allowed terms for 538 as needed and revise current VHS allowed terms.

Update to allow SMDs of conventional terminology ('DVD') if such a rule passes.

Deal with multiple 300 fields.

Check GMD in 245$h

Clean up redundant code.

=cut

sub video007vs300vs538 {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();


	my $leader = $record->leader();
	my $mattype = substr($leader, 6, 1); 
	#my $encodelvl = substr($leader, 17, 1);

	#skip non-videos
	return \@warningstoreturn unless $mattype eq 'g';


	my @fields007 = ();

	if ($record->field('007')) {
		foreach my $field007 ($record->field('007'))
		{
			my $field007string = $field007->as_string(); 
			#skip non 'v' 007s
			next unless ($field007string =~ /^v/);
			#add 'v' 007s to @fields007 for further processing
			push @fields007, $field007string;
		} # foreach subfield 007
	} # if 007s exist
	else {
		#warn about nonexistent 007 in 'g' type records
		push @warningstoreturn, ("007: Record is coded $mattype but 007 does not exist.");
	} # else no 007s

	#report existence of multiple 'v' 007s
	if ($#fields007 > 0){
		push @warningstoreturn, ("007: Multiple 007 with first byte 'v' are present.");
	}
	#report nonexistence of 'v' 007 in 'g' type recor
	elsif ($#fields007 == -1) {
		push @warningstoreturn, ("007: Record is coded $mattype but no 007 has 'v' as its first byte.");
	}
	#else have exactly one 007 'v'
	else {
		# get bytes from the 007 for use in cross checks
		my @field007bytes = split '', $fields007[0];
		#report problem getting 'v' as first byte
		print "Problem getting first byte $fields007[0]" unless ($field007bytes[0] eq 'v');

		#declare variables for later
		my ($iscassette007, $isdisc007, $subfield300a, $subfield300b, $subfield300c, $viddiscin300, $vidcassettein300, $bw_only, $col_only, $col_and_bw, $dim300, $dvd538, $vhs538, $notdvd_or_vhs_in538);

		#check for byte 1 having 'd'--videodisc (DVD or VideoCD) and normal pattern
		if ($field007bytes[1] eq 'd') {
			$isdisc007 = 1;
			unless ( #normal 'vd _[vz]aiz_'
			$field007bytes[4] =~ /^[vz]$/ && #DVD or other
			$field007bytes[5] eq 'a' &&
			$field007bytes[6] eq 'i' &&
			$field007bytes[7] eq 'z'
			) {
				push @warningstoreturn, ("007: Coded 'vd' for videodisc but bytes do not match normal pattern.");
			} # unless normal pattern
		} # if 'vd'

		#elsif check for byte 1 having 'f' videocassette
		elsif ($field007bytes[1] eq 'f') {
			$iscassette007 = 1;
			unless ( #normal 'vf _baho_'
			$field007bytes[4] eq 'b' &&
			$field007bytes[5] eq 'a' &&
			$field007bytes[6] eq 'h' &&
			$field007bytes[7] eq 'o'
			) {
				push @warningstoreturn, ("007: Coded 'vf' for videocassette but bytes do not match normal pattern.");}
		} # elsif 'vf'

		#get 300 and 538 fields for cross-checks
		my $field300 = $record->field('300') if ($record->field('300'));

		#report nonexistent 300 field
		unless ($field300){
				push @warningstoreturn, ("300: May be missing.");		
		} #unless 300 field exists

		#get subfields 'a' 'b' and 'c' if they all exist
		elsif ($field300->subfield('a') && $field300->subfield('b') && $field300->subfield('c')) {
			$subfield300a = $field300->subfield('a');
			$subfield300b = $field300->subfield('b');
			$subfield300c = $field300->subfield('c');
		} #elsif 300a 300b and 300c exist

		#report missing subfield 'a' 'b' or 'c'
		else {
			push @warningstoreturn, ("300: Subfield 'a' is missing.") unless ($field300->subfield('a'));
			push @warningstoreturn, ("300: Subfield 'b' is missing.") unless ($field300->subfield('b'));
			push @warningstoreturn, ("300: Subfield 'c' is missing.") unless ($field300->subfield('c'));
		} # 300a or 300b or 300c is missing

######## get elements of each subfield ##########
		######### get SMD ###########
		if ($subfield300a) {
			if ($subfield300a =~ /videodisc/) {
				$viddiscin300 = 1;
			} #300a has videodisc
			elsif ($subfield300a =~ /videocassette/) {
				$vidcassettein300 = 1;
			} #300a has videocassette
			else {
				push @warningstoreturn, ("300: Not videodisc or videocassette, $subfield300a.");
			} #not videodisc or videocassette in 300a
		} #if subfielda exists
		###############################

		###### get color info #######
		if ($subfield300b) {
			#both b&w and color
			if (($subfield300b =~ /b.?\&.?w/) && ($subfield300b =~ /col\./)) {
				$col_and_bw = 1;
			} #if col. and b&w 
			#both but col. missing period
			elsif (($subfield300b =~ /b.?\&.?w/) && ($subfield300b =~ /col[^.]/)) {
				$col_and_bw = 1;
				push @warningstoreturn, ("300: Col. may need a period, $subfield300b.");
			} #elsif b&w and col (without period after col.)
			elsif (($subfield300b =~ /b.?\&.?w/) && ($subfield300b !~ /col\./)) {
				$bw_only = 1;
			} #if b&w only
			elsif (($subfield300b =~ /col\./) && ($subfield300b !~ /b.?\&.?w/)) {
				$col_only = 1;
			} #if col. only
			elsif (($subfield300b =~ /col[^.]/) && ($subfield300b !~ /b.?\&.?w/)) {
				$col_only = 1;
				push @warningstoreturn, ("300: Col. may need a period, $subfield300b.");
			} #if col. only (without period after col.)
			else {
				push @warningstoreturn, ("300: Col. or b&w are not indicated, $subfield300b.");
			} #not indicated
		} #if subfieldb exists
		###########################

		#### get dimensions ####
		if ($subfield300c) {
			if ($subfield300c =~ /4 3\/4 in\./) {
				$dim300 = '4.75';
			} #4 3/4 in.
			elsif ($subfield300c =~ /1\/2 in\./) {
				$dim300 = '.5';
			} #1/2 in.
		#### add other dimensions here ####
		###########################
		### elsif ($subfield300c =~ //) {}
		###########################
		###########################
			else {
				push @warningstoreturn, ("300: Dimensions are not 4 3/4 in. or 1/2 in., $subfield300c.");
			} # not normal dimension
		} #if subfieldc exists
		###########################

####################################
##### Compare SMD vs. dimensions ###
####################################
#$viddiscin300, $vidcassettein300
#$dim300
##### modify unless statement if dimensions change
		if ($viddiscin300) {
			push @warningstoreturn, ("300: Dimensions, $subfield300c, do not match SMD, $subfield300a.") unless ($dim300 eq '4.75');
		}
		elsif ($vidcassettein300) {
			push @warningstoreturn, ("300: Dimensions, $subfield300c, do not match SMD, $subfield300a.") unless ($dim300 eq '.5');
		}
####################################

###########################
####### Get 538s ##########
###########################

		my @fields538 = $record->field('538')->as_string() if ($record->field('538'));
		#report nonexistent 538 field
		unless (@fields538){
				push @warningstoreturn, ("538: May be missing in video record.");
		} #unless 538 field exists
		else {
			foreach my $field538 (@fields538) {
				if ($field538 =~ /(DVD)|(Video CD)/) {
					$dvd538 = 1;
				} #if dvd in 538
				#################################
				###### VHS wording in 538 is subject to change, so make note of changes
				#################################
				#538 should have VHS format and a playback mode (for our catalogers' current records)
				elsif ($field538 =~ /VHS ([hH]i-[fF]i)?( mono\.)? ?format, [ES]?L?P playback mode/) {
					$vhs538 = 1;
				} #elsif vhs in 538
				###
				### Add other formats here ###
				###
				else {
					#current 538 doesn't have DVD or VHS
					$notdvd_or_vhs_in538 = 1;
				} #else 
			} #foreach 538 field
		} # #else 538 exists

		## add other formats as first condition if necessary
		if (($vhs538||$dvd538) && ($notdvd_or_vhs_in538 == 1)) {
		$notdvd_or_vhs_in538 = 0;
		} #at least one 538 had VHS or DVD

# if $notdvd_or_vhs_in538 is 1, then no 538 had VHS or DVD
		elsif ($notdvd_or_vhs_in538 ==1) {
			push @warningstoreturn, ("538: Does not indicate VHS or DVD.");
		} #elsif 538 does not have VHS or DVD

###################################
##### Cross field comparisons #####
###################################

		#compare SMD in 300 vs. 007 and 538
		##for cassettes
		if ($iscassette007) {
			push @warningstoreturn, ("300: 007 coded for cassette but videocassette is not present in 300a.") unless ($vidcassettein300);
			push @warningstoreturn, ("538: 007 coded for cassette but 538 does not have 'VHS format, SP playback mode'.") unless ($vhs538);
		} #if coded cassette in 007
		##for discs
		elsif ($isdisc007) {
			push @warningstoreturn, ("300: 007 coded for disc but videodisc is not present in 300a.") unless ($viddiscin300);
			push @warningstoreturn, ("538: 007 coded for disc but 538 does not have 'DVD'.") unless ($dvd538);
		} #elsif coded disc in 007

###$bw_only, $col_only, $col_and_bw

		#compare 007/03 vs. 300$b for color/b&w
		if ($field007bytes[3] eq 'b') {
			push @warningstoreturn, ("300: Color in 007 coded 'b' but 300b mentions col., $subfield300b") unless ($bw_only);
		} #b&w
		elsif ($field007bytes[3] eq 'c') {
			push @warningstoreturn, ("300: Color in 007 coded 'c' but 300b mentions b\&w, $subfield300b") unless ($col_only);
		} #col.
		elsif ($field007bytes[3] eq 'm') {
			push @warningstoreturn, ("300: Color in 007 coded 'm' but 300b mentions only col. or b\&w, $subfield300b") unless ($col_and_bw);
		} #mixed
		elsif ($field007bytes[3] eq 'a') {
			#not really an error, but likely rare, especially for our current videos
			push @warningstoreturn, ("300: Color in 007 coded 'a', one color.");
		} #one col.

	} # else have exactly 1 'v' 007

	return \@warningstoreturn;


} # video007vs300vs538


#########################################
#########################################
#########################################
#########################################

=head2 ldrvalidate($record)

Validates bytes 5, 6, 7, 17, and 18 of the leader against MARC code list valid characters.

=head2 DESCRIPTION

Checks bytes 5, 6, 7, 17, and 18.

$ldrbytes{$key} has keys "\d\d", "\d\dvalid" for each of the bytes checked (05, 06, 07, 17, 18)

"\d\dvalid" is a hash ref containing valid code linked to the meaning of that code.

print $ldrbytes{'05valid'}->{'a'}, "\n";
yields: 'Increase in encoding level'

=head2 TO DO (ldrvalidate)

Customize (comment or uncomment) bytes according to local needs.

Examine other Lintadditions/Errorchecks subroutines using the leader to see if duplicate checks are being done.

Move or remove such duplicate checks.

Consider whether %ldrbytes needs full text of meaning of each byte.

=cut

##########################################
### Initialize valid ldr bytes in hash ###
##########################################

#source: MARC field list (http://www.loc.gov/marc/bibliographic/ecbdlist.htm)

#Current version of the hash below reflects settings for one institution
#Change (comment or uncomment) according to local needs

my %ldrbytes = (
	'05' => 'Record status',
	'05valid' => {
		'a' => 'Increase in encoding level',
		'c' => 'Corrected or revised',
#		'd' => 'Deleted',
		'n' => 'New',
		'p' => 'Increase in encoding level from prepublication'
	},
	'06' => 'Type of record',
	'06valid' => {
		'a' => 'Language material',
#		'b' => 'Archival and manuscripts control [OBSOLETE]',
		'c' => 'Notated music',
		'd' => 'Manuscript notated music',
		'e' => 'Cartographic material',
		'f' => 'Manuscript cartographic material',
		'g' => 'Projected medium',
#		'h' => 'Microform publications [OBSOLETE]',
		'i' => 'Nonmusical sound recording',
		'j' => 'Musical sound recording',
		'k' => 'Two-dimensional nonprojectable graphic',
		'm' => 'Computer file',
#		'n' => 'Special instructional material [OBSOLETE]',
		'o' => 'Kit',
		'p' => 'Mixed material',
		'r' => 'Three-dimensional artifact or naturally occurring object',
		't' => 'Manuscript language material'
	},
	'07' => 'Bibliographic level',
	'07valid' => {
		'a' => 'Monographic component part',
#		'b' => 'Serial component part',
#		'c' => 'Collection',
#		'd' => 'Subunit',
		'i' => 'Integrating resource',
		'm' => 'Monograph/item',
		's' => 'Serial'
	},
	'17' => 'Encoding level',
	'17valid' => {
		' ' => 'Full level',
		'1' => 'Full level, material not examined',
		'2' => 'Less-than-full level, material not examined',
#		'3' => 'Abbreviated level',
		'4' => 'Core level',
#		'5' => 'Partial (preliminary) level',
#		'7' => 'Minimal level',
		'8' => 'Prepublication level',
#		'u' => 'Unknown',
#		'z' => 'Not applicable'
	},
	'18' => 'Descriptive cataloging form',
	'18valid' => {
#		' ' => 'Non-ISBD',
		'a' => 'AACR 2',
#		'i' => 'ISBD',
#		'p' => 'Partial ISBD (BK) [OBSOLETE]',
#		'r' => 'Provisional (VM MP MU) [OBSOLETE]',
#		'u' => 'Unknown'
	}
); # %ldrbytes
################################

sub ldrvalidate {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	my $leader = $record->leader();
	my $status = substr($leader, 5, 1);
	my $mattype = substr($leader, 6, 1); 
	my $biblvl = substr($leader, 7, 1);
	my $encodelvl = substr($leader, 17, 1);
	my $catrules = substr($leader, 18, 1);

	#check LDR/05
	unless ($ldrbytes{'05valid'}->{$status}) {
		push @warningstoreturn, "LDR: Byte 05, Status $status is invalid.";
	}
	#check LDR/06
	unless ($ldrbytes{'06valid'}->{$mattype}) {
		push @warningstoreturn, "LDR: Byte 06, Material type $mattype is invalid.";
	}
	#check LDR/07
	unless ($ldrbytes{'07valid'}->{$biblvl}) {
		push @warningstoreturn, "LDR: Byte 07, Bib. Level, $biblvl is invalid.";
	}
	#check LDR/17
	unless ($ldrbytes{'17valid'}->{$encodelvl}) {
		push @warningstoreturn, "LDR: Byte 17, Encoding Level, $encodelvl is invalid.";
	}
	#check LDR/18
	unless ($ldrbytes{'18valid'}->{$catrules}) {
		push @warningstoreturn, "LDR: Byte 18, Cataloging rules, $catrules is invalid.";
	}

	return \@warningstoreturn;

} # ldrvalidate 

#########################################
#########################################
#########################################
#########################################

=head2 geogsubjvs043($record)

Reports absence of 043 if 651 or 6xx subfield z is present.

=head2 TO DO (geogsubjvs043)

Update/maintain list of exceptions (in the hash, %geog043exceptions).

=cut

my %geog043exceptions = (
	'English-speaking countries' => 1,
	'Foreign countries' => 1,
);

sub geogsubjvs043 {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();
	
	#skip records with no subject headings
	unless ($record->field('6..')) {return \@warningstoreturn;}
	else {
		my $hasgeog = 0;
		#get 043 field
		my $field043 = $record->field('043') if ($record->field('043'));
		#get all 6xx fields
		my @fields6xx = $record->field('6..');
		#look at each 6xx field
		foreach my $field6xx (@fields6xx) {
			#if field is 651, it is geog
			##may need to check these for exceptions
			if ($field6xx->tag() eq '651') {
				$hasgeog = 1
			} #if 6xx is 651
			#if field has subfield z, check for exceptions and report others
			elsif ($field6xx->subfield('z')) {
				my @subfields_z = ();
				#get all subfield 'z' in field
				push @subfields_z, ($field6xx->subfield('z'));
				#look at each subfield 'z'
				foreach my $subfieldz (@subfields_z) {
					#remove trailing punctuation and spaces
					$subfieldz =~ s/[ .,]$//;
					# unless text of z is an exception, it is geog.
					unless ($geog043exceptions{$subfieldz}) {
						$hasgeog = 1
					} #unless z is an exception
				} #foreach subfield z
			}# elsif has subfield 'z' but not an exception
		} #foreach 6xx field
		if ($hasgeog) {
			push @warningstoreturn, ("043: Record has 651 or 6xx subfield 'z' but no 043.") unless $field043;
		} #if record has geographic heading
	} #else 6xx exists

	return \@warningstoreturn;

} # geogsubjvs043




#########################################
#########################################
#########################################
#########################################

=head2 findemptysubfields($record)

 Looks for empty subfields.
 Skips 037 in CIP-level records and tags < 010.

=cut

sub findemptysubfields {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	my $leader = $record->leader();
	my $encodelvl = substr($leader, 17, 1);

	my @fields = $record->fields();
	foreach my $field (@fields) {
		#skip control tags
		next if ($field->tag() < 10);
		#skip CIP-level 037 fields
		if (($encodelvl =~ /^8$/) && ($field->tag() eq '037')) {
			next;
		} #if CIP and field 037

		#get all subfields
		my @subfields = $field->subfields() if $field->subfields();
		#break subfields into code and data
		while (my $subfield = pop(@subfields)) {
			my ($code, $data) = @$subfield;
			#check for empty subfield data
			if ($data eq '') {
				push @warningstoreturn, join '', ($field->tag(), ": Subfield $code is empty.");
			}
		} # while subfields
	} # foreach field

	return \@warningstoreturn;

} # findemptysubfields

#########################################
#########################################
#########################################
#########################################

=head2 check_040present($record)

Reports error if 040 is not present.
Can not use Lintadditions check_040 for this since that relies upon field existing before the check is executed.

=cut

sub check_040present {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	#report nonexistent 040 fields
	unless ($record->field('040')) {
			push @warningstoreturn, ("040: Record lacks 040 field.");
	}

	return \@warningstoreturn;

} # check_040present

#########################################
#########################################
#########################################
#########################################

=head2 check_nonpunctendingfields($record)

Checks for presence of punctuation in the fields listed below.
These fields are not supposed to end in punctuation unless the data ends in abbreviation, ___, or punctuation.

Fields checked: 240, 246, 440, 490, 586.

=head2 TO DO (check_nonpunctendingfields)

Add exceptions--abbreviations--or deal with them.
Currently all fields ending in period are reported.

=cut

#set exceptions for abbreviation check;
#these may be useful for 6xx check of punctuation as well
my %abbexceptions = (
	'U.S.A.' => 1,
	'arr.' => 1,
	'etc.' => 1,
	'L. A.' => 1,
	'A.D.' => 1,
	'B.I.G.' => 1,
	'Co.' => 1,
	'D.C.' => 1,
	'E.R.' => 1,
	'I.Q.' => 1,
	'Inc.' => 1,
	'J.F.K.' => 1,
	'Jr.' => 1,
	'O.K.' => 1,
	'R.E.M.' => 1,
	'St.' => 1,
	'T.R.' => 1,
	'U.S.' => 1,
	'bk.' => 1,
	'cc.' => 1,
	'ed.' => 1,
	'ft.' => 1,
	'jr.' => 1,
);

sub check_nonpunctendingfields {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	# check only certain fields
	my @fieldstocheck = ('240', '246', '440', '490', '586');

	
	my @fields = $record->field(@fieldstocheck);


	#loop through set of fields to check in $record
	foreach my $field (@fields) {
		my $tag = $field->tag();
		return \@warningstoreturn if $tag < 10;
		#look at last subfield (unless numeric?)
		my @subfields = $field->subfields();
		my @newsubfields = ();

		#break subfields into code-data array (so the entire field is in one array)
		while (my $subfield = pop(@subfields)) {
			my ($code, $data) = @$subfield;
			# skip numeric subfields (5) and other subfields (e.g. 240$o)
			next if (($code =~ /^\d$/) || ($tag==240 && $code =~ /o/));

# invalid punctuation: /[\.]\'?\"?$/
# so, periods should not usually be present, with some exceptions,
#and, optionally, single and/or double quote
#error prints first 10 and last 10 chars of subfield.
			my ($firstchars, $lastchars) = '';
			if (length($data) < 10) {
				#get full subfield if length < 10)
				$firstchars = $data;
				#get full subfield if length < 10)
				$lastchars = $data;
			} #if subfield length < 10
			elsif (length($data) >= 10) {
				#get first 10 chars of subfield
				$firstchars = substr($data,0,10);
				#get last 10 chars of subfield
				$lastchars = substr($data,-10,10);
			} #elsif subfield length >= 10

			if ($data =~ /[.]\'?\"?$/) {
				#get last words of subfield
				my @lastwords = split ' ', $data;
				#see if last word is a known exception
				unless ($abbexceptions{$lastwords[-1]}) {

					push @warningstoreturn, join '', ($field->tag(), ": Check ending punctuation (not normally added for this field), ", $firstchars, " ___ ",$lastchars);
				}
			}
			# stop after first non-numeric
			last;
		} # while
	} # foreach field


	return \@warningstoreturn;

} # check_nonpunctendingfields($record)

#########################################
#########################################
#########################################
#########################################

=head2 check_fieldlength($record)

Reports error if field is longer than 1870 bytes.
(1879 is actual limit, but I wanted to leave some extra room in case of miscalculation.)

This check relates to certain system limitations.

=head2 TO DO (check_fieldlength($record))

Use directory information in raw MARC to get the field lengths.

=cut

sub check_fieldlength {

	#get passed MARC::Record object
	my $record = shift;
	#declaration of return array
	my @warningstoreturn = ();

	my @fields = $record->fields();
	foreach my $field (@fields) {
		if (length($field->as_string()) > 1870) {
				push @warningstoreturn, join '', ($field->tag(), ": Field is longer than 1870 bytes.");
		}
	} #foreach field

	return \@warningstoreturn;

} # check_fieldlength

#########################################
#########################################
#########################################
#########################################

=head2 

Add new subs with code below.

=head2

sub  {

	#get passed MARC::Record object

	my $record = shift;

	#declaration of return array

	my @warningstoreturn = ();

	push @warningstoreturn, ("");

	return \@warningstoreturn;

} # 

=cut

#########################################
#########################################
#########################################
#########################################

#########################################
#########################################
#########################################
#########################################
#########################################
###### Validate 008 and related #########
#########################################
#########################################
#########################################
#########################################
#########################################
#########################################

##########################
##########################
##########################

=head2 NAME

parse008date($field008string)

=head2 DESCRIPTION


Subroutine parse008date returns four-digit year, two-digit month, and two-digit day.
It requres an 008 string at least 6 bytes long.


=head2 SYNOPSIS

 my ($earlyyear, $earlymonth, $earlyday);
 print ("What is the earliest create date desired (008 date, in yymmdd)? ");
 while (my $earlydate = <>) {
 chomp $earlydate;
 my $field008 = $earlydate;
 my $yyyymmdderr = MARC::Errorchecks::parse008date($field008);
 my @parsed008date = split "\t", $yyyymmdderr;
 $earlyyear = shift @parsed008date;
 $earlymonth = shift @parsed008date;
 $earlyday = shift @parsed008date;
 my $errors = join "\t", @parsed008date;
 if ($errors) {
 if ($errors =~ /is too short/) {
 print "Please enter a longer date, $errors\nEnter date (yymmdd): ";
 }
 else {print "$errors\nEnter valid date (yymmdd): ";}
 } #if errors
 else {last;}
 }

=cut

sub parse008date {

	my $field008 = shift;
	if (length ($field008) < 6) { return "\t\t\t$field008 is too short";}

	my $hasbadchars = "";
	my $dateentered = substr($field008,0,6);
	my $yearentered = substr($dateentered, 0, 2);
	#validate year portion--change dates to reflect local implementation of code 
	#(and for future use--after 2006)
	#year created less than 06 considered 200x
	if ($yearentered <= 6) {$yearentered += 2000;}
	#year created between 80 and 99 considered 19xx
	elsif ((80 <= $yearentered) && ($yearentered <= 99)) {$yearentered += 1900;}
	else {$hasbadchars .= "Year entered is after 2006 or before 1980\t";}

	#validate month portion
	my $monthentered = substr($dateentered, 2, 2);
	if (($monthentered < 1) || ($monthentered > 12)) {$hasbadchars .= "Month entered is greater than 12 or is 00\t";}

	#validate day portion
	my $dayentered = substr($dateentered, 4, 2);

	if (($monthentered =~ /^01$|^03$|^05$|^07$|^08$|^10$|^12$/) && (($dayentered < 1) || ($dayentered > 31))) {$hasbadchars .= "Day entered is greater than 31 or is 00\t";}
	elsif (($monthentered =~ /^04$|^06$|^09$|^11$/) && (($dayentered < 1) || ($dayentered > 30))) {$hasbadchars .= "Day entered is greater than 30 or is 00\t";}
	elsif (($monthentered =~ /^02$/) && (($dayentered < 1) || ($dayentered > 29))) {$hasbadchars .= "Day entered is greater than 29 or is 00\t";}

	return (join "\t", $yearentered, $monthentered, $dayentered, $hasbadchars)

} #parse008date

##########################
##########################
##########################

=head2 validate008 reworked

Reworking of the validate008 sub.
Revised to work more like other Errorchecks and Lintadditions checks.
Returns array ref of errors.
Previous version returned hash ref of 008 byte key-value pairs,
array ref of cleaned bytes, and scalar ref of errors.
New version returns only an array ref of errors.

=head2 validate008 ($field008, $mattype, $biblvl)

Checks the validity of 008 bytes.
Used by the check_008 method for 008 validation.

=head2 DESCRIPTION

Checks the validity of 008 bytes.
Depends upon 008 being based upon LDR/06,
so continuing resources/serials records may not work.
Checks LDR/07 for 's' for serials before checking material specific bytes.

=head2 OTHER INFO

Character positions 00-17 and 35-39 are defined the same across all types of material, with special consideration for position 06. 

Steps in validation code for format specific positions:

 1. add hash key and value pair for byte position(s)
 2. verify each byte against list of valid codes
 3. add valid characters as individual positions of cleaned array
 4. add any error to scalar containing tabbed errors


=head2 Synopsis

 use MARC::Record;
 use MARC::Errorchecks;

 #$mattype and $biblvl are from LDR/06 and LDR/07
 #my $mattype = substr($leader, 6, 1); 
 #my $biblvl = substr($leader, 7, 1);
 #my $field008 = $record->field('008')->as_string();
 my $field008 = '000101s20002000nyu                 eng d';
 my @warningsfrom008 =  @{MARC::Errorchecks::validate008($field008, $mattype, $biblvl)};

print join "\t", @warningsfrom008, "\n";

=head2 TO DO (validate008)

 Add requirement that 40 char string needs to be passed in.
 Add error checking for less than 40 char string.
 --Partially done--Less than 40 characters leads to error.
 Verify datetypes that allow multiple dates.

 Verify continuing resource checking (not thoroughly tested).

 Separate byte 18-34 checking so the same code can be used for 006 byte checking.

=head2 SKIP CODE for SERIALS

### This is not here for any particular reason, 
### I just wanted to save it for future use if I needed it.
	#stop checking if record is not coded 'm', monograph
	unless ($biblvl eq 'm') {
		push @warningstoreturn, ("LDR: Record coded $biblvl, not monograph. Further parsing of 008 will not be done for this record.");
		return (\@warningstoreturn);
	} #unless bib level is 'm'




=head2 TEST CODE

 #test code
 use MARC::Errorchecks;
 use MARC::Record;
 my $leader = '00050nam';
 my $field008 = '000101s20002000nyu                 eng d';
 my $mattype = substr($leader, 6, 1); 
 my $biblvl = substr($leader, 7, 1);

 print "$field008\n";
 my @warningsfrom008 =  @{validate008($field008, $mattype, $biblvl)};

print join "\t", @warningsfrom008, "\n";

=cut

#####################################


##########################################
######### Start validate008 sub ##########
##########################################

sub validate008 {

	#populate subroutine $field008 variable with passed string
	my $field008 = shift;
	#populate subroutine $mattype and $biblvl with passed strings
	my $mattype = shift;
	my $biblvl = shift;

	#declaration of return array
	my @warningstoreturn = ();

	#setup country and language code validation hashes
	#from the MARC::Lint::CodeData module
	use MARC::Lint::CodeData qw(%LanguageCodes %ObsoleteLanguageCodes %CountryCodes %ObsoleteCountryCodes);

	#make sure passed 008 field is exactly 40 bytes
	if (length($field008) != 40) {push @warningstoreturn, ("008: Not 40 bytes. Bytes not validated ($field008).");}

	#return if 008 field of 40 bytes was not found
	return (\@warningstoreturn) if (@warningstoreturn);

	#get the values of the all-format positions
	my %field008hash = (
	dateentered => substr($field008,0,6),
	datetype => substr($field008,6,1),
	date1 => substr($field008,7,4), 
	date2 => substr($field008,11,4),
	pubctry => substr($field008,15,3),
	### format specific 18-34 ###
	langcode => substr($field008,35,3),
	modrec => substr($field008,38,1),
	catsource => substr($field008,39,1)
	);

	#validate the all-format bytes

	# Date entered on file (byte[0]-[5])
	#6 digits, yymmdd
	#parse created date
	#call parse008date to do work of date error checking
	my $yyyymmdderr = MARC::Errorchecks::parse008date($field008hash{dateentered});
	my @parsed008date = split "\t", $yyyymmdderr;
	my $yearentered = shift @parsed008date;
	my $monthentered = shift @parsed008date;
	my $dayentered = shift @parsed008date;
	my $dateerrors = join "\t", @parsed008date;

	#unless date entered is only 6 digits and no errors were found, report the errors
	unless (($field008hash{dateentered} =~ /^\d{6}$/) && $dateerrors !~ /entered/) {
		push @warningstoreturn, ("008: Bytes 0-5, Date entered has bad characters. $dateerrors.");
	} 

	#Type of date/Publication status (byte[6])
	#my $datetype = substr($field008,6,1);
	unless ($field008hash{datetype} =~ /^[bcdeikmnpqrstu|]$/) {
		push @warningstoreturn, ("008: Byte 6, Date type has bad characters.");
	} 

###### Remove the following ###########
### Remnant of writing of code ####

   #b - No dates given; B.C. date involved
   #c - Continuing resource currently published
   #d - Continuing resource ceased publication
   #e - Detailed date
   #i - Inclusive dates of collection 
   #k - Range of years of bulk of collection 
   #m - Multiple dates
   #n - Dates unknown
   #p - Date of distribution/release/issue and production/recording session when different 
   #q - Questionable date
   #r - Reprint/reissue date and original date
   #s - Single known date/probable date
   #t - Publication date and copyright date 
   #u - Continuing resource status unknown
   #| - No attempt to code 
#########################################


	#Date 1 (byte[7]-[10])
	unless (($field008hash{date1} =~ /^[u\d|]{4}$/) || (($field008hash{date1} =~ /^\s{4}$/) && ($field008hash{datetype} =~ /^b$/)))
		{push @warningstoreturn, ("008: Bytes 7-10, Date1 has bad characters.")}; 

	###on date2, verify datetypes that are allowed to have only one date
	# Date 2 (byte[11]-[14])
	#check datetype for single date
	if ($field008hash{datetype} =~ /^[bqs]$/) {
		#if single, need to have four spaces as date2
		unless ($field008hash{date2} =~ /^\s{4}$/) {
			push @warningstoreturn, ("008: Bytes 11-14 Date2, has bad characters.")
		} #unless date2 has 4 blanks for types b, q, s
	} #if date type is b, q, or s
	#may need elsif for 4 blank spaces with other datetypes or other elsifs for different datetypes (e.g. detailed date, 'e')
	elsif ($field008hash{date2} !~ /^[u\d|]{4}$/) {
		push @warningstoreturn, ("008: Bytes 11-14, Date2 has bad characters.")}

	# Place of publication, production, or execution (byte[15]-[17])
	#my $pubctry = substr($field008,15,3);
	###Get codes from MARC Country Codes list

	#see if country code matches valid code
	my $validctrycode = 1 if $CountryCodes{$field008hash{pubctry}};
	#look for obsolete code match if valid code was not matched
	my $obsoletectrycode = 1 if $ObsoleteCountryCodes{$field008hash{pubctry}};

	unless ($validctrycode) {
		#code did not match valid code, so see if it may have been valid before
		if ($obsoletectrycode) {
			push @warningstoreturn, ("008: Bytes 15-17, Country of Publication ($field008hash{pubctry}) may be obsolete.");
		}
		else {
			push @warningstoreturn, ("008: Bytes 15-17, Country of Publication ($field008hash{pubctry}) is not valid.")
		}
	} #unless valid country code was found
	
#######################################################
#### byte[18]-[34] are format specific (see below) ####
######################################################

	# Language (byte[35]-[37])

#%LanguageCodes %ObsoleteLanguageCodes
	my $validlang = 1 if ($LanguageCodes{$field008hash{langcode}});
	#look for invalid code match if valid code was not matched
	my $obsoletelang = 1 if ($ObsoleteLanguageCodes{$field008hash{langcode}});

	# skip valid subfields
	unless ($validlang) {
		#report invalid matches as possible obsolete codes
		if ($obsoletelang) {
			push @warningstoreturn, ("008: Bytes 35-37, Language ($field008hash{langcode}) may be obsolete.");
		} #if obsolete
		else {
			push @warningstoreturn, ("008: Bytes 35-37, Language ($field008hash{langcode}) not valid.");
		} #else code not found 
	} # unless found valid code


	##################################################

	# Modified record (byte[38])
	#my $modrec = substr($field008,38,1);
	unless ($field008hash{modrec} =~ /^[dorsx|\s]$/) {
		push @warningstoreturn, ("008: Byte 38, Modified record has bad characters.");
	} #unless modrec has valid characters

	# Cataloging source (byte[39])
	#my $catsource = substr($field008,39,1);
	unless ($field008hash{catsource} =~ /^[cdu|\s]$/) {
		push @warningstoreturn, ("008: Byte 39, Cataloging source has bad characters.");
	} #unless Cataloging source is valid

	########################################
	########################################
	########################################
	##  Continuing Resources bytes 18-34  ##
	########################################
	########################################
	########################################

	### Check continuing resources (serials) ###
	if ($biblvl =~ /^[s]$/) {

		# Frequency (byte[18])
		$field008hash{frequency} = substr($field008,18,1);
		unless ($field008hash{frequency} =~ /^[abcdefghijkmqstuwz|\s]$/) {
			push @warningstoreturn, ("008: Byte 18, Continuing resources-Frequency has bad characters.");
		} #Continuing resources 18

		# Regularity (byte[19])
		$field008hash{regularity} = substr($field008,19,1);
		unless ($field008hash{regularity} =~ /^[nrux|]$/) {
			push @warningstoreturn, ("008: Byte 19, Continuing resources-Regularity has bad characters.");
		} #Continuing resources 19

		#ISSN center (byte[20])
		$field008hash{issncenter} = substr($field008,20,1);
		unless ($field008hash{issncenter} =~ /^[0124z|\s]$/) {
			push @warningstoreturn, ("008: Byte 20, Continuing resources-ISSN center has bad characters.")
		} #Continuing resources 20

		#Type of continuing resource (byte[21])
		$field008hash{typeofcontres} = substr($field008,21,1);
		unless ($field008hash{typeofcontres} =~ /^[dlmnpw|\s]$/) {
			push @warningstoreturn, ("008: Byte 21, Continuing resources-Type of continuing resource has bad characters.");
		} #Continuing resources 21

		#Form of original item (byte[22])
		$field008hash{formoforig} = substr($field008,22,1);
		unless ($field008hash{formoforig} =~ /^[abcdefs\s]$/) {
			push @warningstoreturn, ("008: Byte 22, Continuing resources-Form of original has bad characters.");
		} #Continuing resources 22

		#Form of item (byte[23])
		$field008hash{formofitem} = substr($field008,23,1);
		unless ($field008hash{formofitem} =~ /^[abcdfrs|\s]$/) {
			push @warningstoreturn, ("008: Byte 23, Continuing resources-Form of item has bad characters.");
		} #Continuing resources 23

		#Nature of entire work (byte[24])
		$field008hash{natureofwk} = substr($field008,24,1);
		unless ($field008hash{natureofwk} =~ /^[abcdefghiklmnopqrstuvwz|\s]$/) {
			push @warningstoreturn, ("008: Byte 24, Continuing resources-Nature of work has bad characters.");
		} #Continuing resources 24

		#Nature of contents (byte[25]-[27])
		$field008hash{contrescontents} = substr($field008,25,3);
		unless ($field008hash{contrescontents} =~ /^[abcdefghiklmnopqrstuvwz|\s]{3}$/) {
			push @warningstoreturn, ("008: Bytes 25-27, Continuing resources-Contents has bad characters.");
		} #Continuing resources 25-27

		#Government publication (byte[28])
		$field008hash{govtpub} = substr($field008,28,1);
		unless ($field008hash{govtpub} =~ /^[acfilmosuz|\s]$/) {
			push @warningstoreturn, ("008: Byte 28, Continuing resources-Govt publication has bad characters.");
		} #Continuing resources 28

		#Conference publication (byte[29])
		$field008hash{confpub} = substr($field008,29,1);
		unless ($field008hash{confpub} =~ /^[01|]$/) {
			push @warningstoreturn, ("008: Byte 29, Continuing resources-Conference publication has bad characters.");
		} #Continuing resources 29

		#Undefined (byte[30]-[32])
		$field008hash{contresundef30to32} = substr($field008,30,3);
		unless ($field008hash{contresundef30to32} =~ /^[|\s]{3}$/) {
			push @warningstoreturn, ("008: Bytes 30-32, Continuing resources-Undef30to32 has bad characters.");
		} #Continuing resources 30-32 

		#Original alphabet or script of title (byte[33])
		$field008hash{origalphabet} = substr($field008,33,1);
		unless ($field008hash{origalphabet} =~ /^[abcdefghijkluz|\s]$/) {
			push @warningstoreturn, ("008: Byte 33, Continuing resources-Original alphabet has bad characters.");
		} #Continuing resources 33

		#Entry convention (byte[34])
		$field008hash{entryconvention} = substr($field008,34,1);
		unless ($field008hash{entryconvention} =~ /^[012|]$/) {
			push @warningstoreturn, ("008: Byte 34, Continuing resources-Entry convention has bad characters.");
		} #Continuing resources 34

	} # Continuing Resources

	########################################
	########################################
	########################################
	########### Books bytes 18-34 ##########
	########################################
	########################################
	########################################


	elsif ($mattype =~ /^[at]$/) {

		# Illustrations (byte [18]-[21])
		$field008hash{illustrations} = substr($field008,18,4);
		unless ($field008hash{illustrations} =~ /^[abcdefghijklmop|\s]{4}$/) {
			push @warningstoreturn, ("008: Bytes 18-21, Books-Illustrations has bad characters.");
		} #Books-18-21

		# Target audience (byte 22)
		$field008hash{audience} = substr($field008,22,1);
		unless ($field008hash{audience} =~ /^[abcdefgj|\s]$/) {
			push @warningstoreturn, ("008: Byte 22, Books-Audience has bad characters.")
		} #Books 22

		# Form of item (byte 23)
		$field008hash{formofitem} = substr($field008,23,1);
		unless ($field008hash{formofitem} =~ /^[abcdfrs|\s]$/) {
			push @warningstoreturn, ("008: Byte 23, Books-Form of item has bad characters.")
		} #Books 23

		# Nature of contents (byte[24]-[27])
		$field008hash{bkcontents} = substr($field008,24,4);
		unless ($field008hash{bkcontents} =~ /^[abcdefgijklmnopqrstuvwz|\s]{4}$/) {
			push @warningstoreturn, ("008: Bytes 24-27, Books-Contents has bad characters.")
		} #Books 24-27

		#Government publication (byte 28)
		$field008hash{govtpub} = substr($field008,28,1);
		unless ($field008hash{govtpub} =~ /^[acfilmosuz|\s]$/) {
			push @warningstoreturn, ("008: Byte 28, Books-Govt publication has bad characters.")
		} #Books 28

		#Conference publication (byte 29)
		$field008hash{confpub} = substr($field008,29,1);
		unless ($field008hash{confpub} =~ /^[01|]$/) {
			push @warningstoreturn, ("008: Byte 29, Books-Conference publication has bad characters.")
		} #Books 29

		#Festschrift (byte 30)
		$field008hash{fest} = substr($field008,30,1);
		unless ($field008hash{fest} =~ /^[01|]$/) {
			push @warningstoreturn, ("008: Byte 30, Books-Festschrift has bad characters.")
		} #Books 30

		#Index (byte 31)
		$field008hash{bkindex} = substr($field008,31,1);
		unless ($field008hash{bkindex} =~ /^[01|]$/) {
			push @warningstoreturn, ("008: Byte 31, Books-Index has bad characters.");
		} #Books 31

		#Undefined (byte 32)
		$field008hash{obsoletebyte32} = substr($field008,32,1);
		unless ($field008hash{obsoletebyte32} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 32, Books-Obsoletebyte32 has bad characters.");
		} #Books 32

		#Literary form (byte 33)
		$field008hash{fict} = substr($field008,33,1);
		unless ($field008hash{fict} =~ /^[01cdefhijmpsu|\s]$/) {
			push @warningstoreturn, ("008: Byte 33, Books-Literary form has bad characters.");
		} #Books 33

		#Biography (byte 34)
		$field008hash{biog} = substr($field008,34,1);
		unless ($field008hash{biog} =~ /^[abcd|\s]$/) {
			push @warningstoreturn, ("008: Byte 34, Books-Biography has bad characters.");
		} #Books 34

	} ### Books

	########################################
	########################################
	########################################
	### Electronic Resources bytes 18-34 ###
	########################################
	########################################
	########################################

	#electronic resources/computer files
	elsif ($mattype =~ /^[m]$/) {

		#Undefined (byte 18-21)
		$field008hash{electresundef18to21} = substr($field008,18,4);
		unless ($field008hash{electresundef18to21} =~ /^[|\s]{4}$/) {
			push @warningstoreturn, ("008: Bytes 18-21, Electronic Resources-Undef18to21 has bad characters.");
		} #Electronic Resources 18-21

		#Target audience (byte 22)
		$field008hash{audience} = substr($field008,22,1);
		unless ($field008hash{audience} =~ /^[abcdefgj|\s]$/) {
			push @warningstoreturn, ("008: Byte 22, Electronic Resources-Audience has bad characters.");
		} #Electronic Resources 22

		#Undefined (byte[23]-[25])
		$field008hash{electresundef23to25} = substr($field008,23,3);
		unless ($field008hash{electresundef23to25} =~ /^[|\s]{3}$/) {
			push @warningstoreturn, ("008: Bytes 23-25, Electronic Resources-Undef23to25 has bad characters.");
		} #Electronic Resources 23-25

		#Type of computer file (byte[26])
		$field008hash{typeoffile} = substr($field008,26,1);
		unless ($field008hash{typeoffile} =~ /^[abcdefghijmuz|]$/) {
			push @warningstoreturn, ("008: Byte 26, Electronic Resources-Type of file has bad characters.");
		} #Electronic Resources 26

		#Undefined (byte[27])
		$field008hash{electresundef27} = substr($field008,27,1);
		unless ($field008hash{electresundef27} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 27, Electronic Resources-Undef27 has bad characters.");
		} #Electronic Resources 27

		#Government publication (byte [28])
		$field008hash{govtpub} = substr($field008,28,1);
		unless ($field008hash{govtpub} =~ /^[acfilmosuz|\s]$/) {
			push @warningstoreturn, ("008: Byte 28, Electronic Resources-Govt publication has bad characters.");
		} #Electronic Resources 28

		#Undefined (byte[29]-[34])
		$field008hash{electresundef29to34} = substr($field008,29,6);
		unless ($field008hash{electresundef29to34} =~ /^[|\s]{6}$/) {
			push @warningstoreturn, ("008: Bytes 29-34, Electronic Resources-Undef29to34 has bad characters.")
		} #Electronic Resources 29-34 

	} #electronic resources

	########################################
	########################################
	########################################
	#  Cartographic Materials bytes 18-34  #
	########################################
	########################################
	########################################

	#cartographic materials/maps

	elsif ($mattype =~ /^[ef]$/) {

		#Relief (byte[18]-[21])
		$field008hash{relief} = substr($field008,18,4);
		unless ($field008hash{relief} =~ /^[abcdefgijkmz|\s]{4}$/) {
			push @warningstoreturn, ("008: Bytes 18-21, Cartographic-Relief has bad characters.");
		} #Cartographic 18-21

		#Projection (byte[22]-[23])
		$field008hash{projection} = substr($field008,22,2);
		unless ($field008hash{projection} =~ /^\|\||\s\s|aa|ab|ac|ad|ae|af|ag|am|an|ap|au|az|ba|bb|bc|bd|be|bf|bg|bh|bi|bj|bo|br|bs|bu|bz|ca|cb|cc|ce|cp|cu|cz|da|db|dc|dd|de|df|dg|dh|dl|zz$/) {
			push @warningstoreturn, ("008: Bytes 22-23, Cartographic-Projection has bad characters.");
			} #Cartographic 22-23 

		#Undefined (byte[24])
		$field008hash{mapundef24} = substr($field008,24,1);
		unless ($field008hash{mapundef24} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 24, Cartographic-Undef24 has bad characters.");
		} #Cartographic 24

		#Type of cartographic material (byte[25])
		$field008hash{typeofmap} = substr($field008,25,1);
		unless ($field008hash{typeofmap} =~ /^[abcdefguz|]$/) {
			push @warningstoreturn, ("008: Byte 25, Cartographic-Type of map has bad characters.");
		} #Cartographic 25

		#Undefined (byte[26]-[27])
		$field008hash{mapundef26to27} = substr($field008,26,2);
		unless ($field008hash{mapundef26to27} =~ /^[|\s]{2}$/) {
			push @warningstoreturn, ("008: Bytes 26-27, Cartographic-Undef26to27 has bad characters.");
		} #Cartographic 26-27 

		#Government publication (byte[28])
		$field008hash{govtpub} = substr($field008,28,1);
		unless ($field008hash{govtpub} =~ /^[acfilmosuz|\s]$/) {
			push @warningstoreturn, ("008: Byte 28, Cartographic-Govt publication has bad characters.");
		} #Cartographic 28

		#Form of item (byte[29])
		$field008hash{formofitem} = substr($field008,29,1);
		unless ($field008hash{formofitem} =~ /^[abcdfrs|\s]$/) {
			push @warningstoreturn, ("008: Byte 29, Cartographic-Form of item has bad characters.");
		} #Cartographic 29

		#Undefined (byte[30])
		$field008hash{mapundef30} = substr($field008,30,1);
		unless ($field008hash{mapundef30} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 30, Cartographic-Undef30 has bad characters.");
		} #Cartographic 30

		#Index (byte[31])
		$field008hash{mapindex} = substr($field008,31,1);
		unless ($field008hash{mapindex} =~ /^[01|]$/) {
			push @warningstoreturn, ("008: Byte 31, Cartographic-Index has bad characters.");
		} #Cartographic 31

		#Undefined (byte[32])
		$field008hash{mapundef32} = substr($field008,32,1);
		unless ($field008hash{mapundef32} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 32, Cartographic-Undef32 has bad characters.");
		} #Cartographic 32

		#Special format characteristics (byte[33]-[34])
		$field008hash{specialfmtchar} = substr($field008,33,2);
		unless ($field008hash{specialfmtchar} =~ /^[ejklnoprz|\s]{2}$/) {
			push @warningstoreturn, ("008: Bytes 33-34, Cartographic-Special format characteristics has bad characters.");
			} #Cartographic 33-34

	} # Cartographic Materials

	########################################
	########################################
	########################################
	#  Music/Sound Recordings bytes 18-34  #
	########################################
	########################################
	########################################

	#music and sound recordings
	elsif ($mattype =~ /^[cdij]$/) {

		#Form of composition (byte[18]-[19])
		$field008hash{formofcomp} = substr($field008,18,2);
		unless ($field008hash{formofcomp} =~ /^\|\||an|bd|bg|bl|bt|ca|cb|cc|cg|ch|cl|cn|co|cp|cr|cs|ct|cy|cz|df|dv|fg|fm|ft|gm|hy|jz|mc|md|mi|mo|mp|mr|ms|mu|mz|nc|nn|op|or|ov|pg|pm|po|pp|pr|ps|pt|pv|rc|rd|rg|ri|rp|rq|sd|sg|sn|sp|st|su|sy|tc|ts|uu|vr|wz|zz$/) {
			push @warningstoreturn, ("008: Bytes 18-19, Music-Form of composition has bad characters.");
		} #Music 18-19

		#Format of music (byte[20])
		$field008hash{fmtofmusic} = substr($field008,20,1);
		unless ($field008hash{fmtofmusic} =~ /^[abcdegmnuz|]$/) {
			push @warningstoreturn, ("008: Byte 20, Music-Format of music has bad characters.");
		} #Music 20

		#Music parts (byte[21])
		$field008hash{musicparts} = substr($field008,21,1);
		unless ($field008hash{musicparts} =~ /^[defnu|\s]$/) {
			push @warningstoreturn, ("008: Byte 21, Music-Parts has bad characters.");
		} #Music 21

		#Target audience (byte[22])
		$field008hash{audience} = substr($field008,22,1);
		unless ($field008hash{audience} =~ /^[abcdefgj|\s]$/) {
			push @warningstoreturn, ("008: Byte 22, Music-Audience has bad characters.");
		} #Music 22

		#Form of item (byte[23])
		$field008hash{formofitem} = substr($field008,23,1);
		unless ($field008hash{formofitem} =~ /^[abcdfrs|\s]$/) {
			push @warningstoreturn, ("008: Byte 23, Music-Form of item has bad characters.");
		} #Music 23

		#Accompanying matter (byte[24]-[29])
		$field008hash{accompmat} = substr($field008,24,6);
		unless ($field008hash{accompmat} =~ /^[abcdefghikrsz|\s]{6}$/) {
			push @warningstoreturn, ("008: Bytes 24-29, Music-Accompanying material has bad characters.");
		} #Music 24-29 

		#Literary text for sound recordings (byte[30]-[31])
		$field008hash{textforsdrec} = substr($field008,30,2);
		unless ($field008hash{textforsdrec} =~ /^[abcdefghijklmnoprstz|\s]{2}$/) {
			push @warningstoreturn, ("008: Byte 30-31, Music-Text for sound recordings has bad characters.");
		} #Music 30-31

		#Undefined (byte[32])
		$field008hash{musicundef32} = substr($field008,32,1);
		unless ($field008hash{musicundef32} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 32, Music-Undef32 has bad characters.");
		} #Music 32

		#Transposition and arrangement (byte[33])
		$field008hash{transposeandarr} = substr($field008,33,1);
		unless ($field008hash{transposeandarr} =~ /^[abcnu|\s]$/) {
			push @warningstoreturn, ("008: Byte 33, Music-Transposition and arrangement has bad characters.");
		} #Music 33

		#Undefined (byte[34])
		$field008hash{musicundef34} = substr($field008,34,1);
		unless ($field008hash{musicundef34} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 34, Music-Undef34 has bad characters.");
		} #Music 34

	} # Music and Sound Recordings

	########################################
	########################################
	########################################
	####  Visual Materials bytes 18-34  ####
	########################################
	########################################
	########################################

	#visual materials
	elsif ($mattype =~ /^[gkor]$/) {

		#Running time for motion pictures and videorecordings (byte[18]-[20])
		$field008hash{runningtime} = substr($field008,18,3);
		unless ($field008hash{runningtime} =~ /^([|\d]{3}|\-{3}|n{3})$/) {
			push @warningstoreturn, ("008: Bytes 18-20, Visual materials-Runningtime has bad characters.")
		} #Visual materials 18-20

		#Undefined (byte[21])
		$field008hash{visualmatundef21} = substr($field008,21,1);
		unless ($field008hash{visualmatundef21} =~ /^[|\s]$/) {
			push @warningstoreturn, ("008: Byte 21, Visual materials-Undef21 has bad characters.");
		} #Visual materials 21

		#Target audience (byte[22])
		$field008hash{audience} = substr($field008,22,1);
		unless ($field008hash{audience} =~ /^[abcdefgj|\s]$/) {
			push @warningstoreturn, ("008: Byte 22, Visual materials-Audience has bad characters.");
		} #Visual materials 22

		#Undefined (byte[23]-[27])
		$field008hash{visualmatundef23to27} = substr($field008,23,5);
		unless ($field008hash{visualmatundef23to27} =~ /^[|\s]{5}$/) {
			push @warningstoreturn, ("008: Bytes 23-27, Visual materials-Undef23to27 has bad characters.");
		} #Visual materials 23-27 

		#Government publication (byte[28])
		$field008hash{govtpub} = substr($field008,28,1);
		unless ($field008hash{govtpub} =~ /^[acfilmosuz|\s]$/) {
			push @warningstoreturn, ("008: Byte 28, Visual materials-Govt publication has bad characters.");
		} #Visual materials 28

		#Form of item (byte[29])
		$field008hash{formofitem} = substr($field008,29,1);
		unless ($field008hash{formofitem} =~ /^[abcdfrs|\s]$/) {
			push @warningstoreturn, ("008: Byte 29, Visual materials-Form of item has bad characters.");
		} #Visual materials 29

		#Undefined (byte[30]-[32])
		$field008hash{visualmatundef30to32} = substr($field008,30,3);
		unless ($field008hash{visualmatundef30to32} =~ /^[|\s]{3}$/) {
			push @warningstoreturn, ("008: Bytes 30-32, Visual materials-Undef30to32 has bad characters.");
		} #Visual materials 30-32 

		#Type of visual material (byte[33])
		$field008hash{typevisualmaterial} = substr($field008,33,1);
		unless ($field008hash{typevisualmaterial} =~ /^[abcdfgiklmnopqrstvwz|]$/) {
			push @warningstoreturn, ("008: Byte 33, Visual materials-Type of visual material has bad characters.");
		}

		#Technique (byte[34])
		$field008hash{technique} = substr($field008,34,1);
		unless ($field008hash{technique} =~ /^[aclnuz|]$/) { push @warningstoreturn, ("008: Byte 34, Visual materials-Technique has bad characters.");
		} #Visual materials 34

	} #Visual Materials

	########################################
	########################################
	########################################
	####  Mixed Materials bytes 18-34   ####
	########################################
	########################################
	########################################

	#mixed materials
	elsif ($mattype =~ /^[p]$/) {

		#Undefined (byte[18]-[22])
		$field008hash{mixedundef18to22} = substr($field008,18,5);
		unless ($field008hash{mixedundef18to22} =~ /^[|\s]{5}$/) {
			push @warningstoreturn, ("008: Bytes 18-22, Mixed materials-Undef18to22 has bad characters.");
		} #Mixed materials 18-22 

		#Form of item (byte[23])
		$field008hash{formofitem} = substr($field008,23,1);
		unless ($field008hash{formofitem} =~ /^[abcdfrs|\s]$/) {
			push @warningstoreturn, ("008: Byte 23, Mixed materials-Form of item has bad characters.");
		} #Mixed materials 23

		#Undefined (byte[24]-[34])
		$field008hash{mixedundef24to34} = substr($field008,24,11);
		unless ($field008hash{mixedundef24to34} =~ /^[|\s]{11}$/) {
			push @warningstoreturn, ("008: Byes 24-34, Mixed materials-Undef24to34 has bad characters.");
		} #Mixed materials 24-30 

	} #Mixed Materials

	return (\@warningstoreturn);

} #validate008

#########################################
#########################################
#########################################
#########################################

#########################################
#########################################
#########################################
#########################################

#########################################
#########################################
#########################################
#########################################

=head1 CHANGES/VERSION HISTORY

Version 1.04: Updated Nov. 4-Dec. 4, 2004. Released Dec. 5, 2004.

 -Updated validate008() to use MARC::Lint::CodeData.
 -Removed DATA section, since this is now in MARC::Lint::CodeData.
 -Updated check_008() to use the new validate008().
 -Revised bib. refs. check to require 'reference' to be followed by optional 's', optional period, and word boundary (to catch things like 'referenced'.


Version 1.03: Updated Aug. 30-Oct. 16, 2004. Released Oct. 17. First CPAN version.

 -Moved subs to MARC::QBIerrorchecks
 --check_003($record)
 --check_CIP_for_stockno($record)
 --check_082count($record)
 -Fixed bug in check_5xxendingpunctuation for first 10 characters.
 -Moved validate008() and parse008date() from MARC::BBMARC (to make MARC::Errorchecks more self-contained).
 -Moved readcodedata() from BBMARC (used by validate008)
 -Moved DATA from MARC::BBMARC for use in readcodedata() 
 -Remove dependency on MARC::BBMARC
 -Added duplicate comma check in check_double_periods($record)
 -Misc. bug fixes
 Planned (future versions):
 -Account for undetermined dates in matchpubdates($record).
 -Cleanup of validate008
 --Standardization of error reporting
 --Material specific byte checking (bytes 18-34) abstracted to allow 006 validation.
  
Version 1.02: Updated Aug. 11-22, 2004. Released Aug. 22, 2004.

 -Implemented VERSION (uncommented)
 -Added check for presence of 040 (check_040present($record)).
 -Added check for presence of 2 082s in full-level, 1 082 in CIP-level records (check_082count($record)).
 -Added temporary (test) check for trailing punctuation in 240, 586, 440, 490, 246 (check_nonpunctendingfields($record))
 --which should not end in punctuation except when the data ends in such.
 -Added check_fieldlength($record) to report fields longer than 1870 bytes.
 --This should be rewritten to use the length in the directory of the raw MARC.
 -Fixed workaround in check_bk008_vs_bibrefandindex($record) (Thanks again to Rich Ackerman).
 
Version 1.01: Updated July 20-Aug. 7, 2004. Released Aug. 8, 2004.

 -Temporary (or not) workaround for check_bk008_vs_bibrefandindex($record) and bibliographies.
 -Removed variables from some error messages and cleanup of messages.
 -Code readability cleanup.
 -Added subroutines:
 --check_240ind1vs1xx($record)
 --check_041vs008lang($record)
 --check_5xxendingpunctuation($record)
 --findfloatinghypens($record)
 --video007vs300vs538($record)
 --ldrvalidate($record)
 --geogsubjvs043($record)
 ---has list of exceptions (e.g. English-speaking countries)
 --findemptysubfields($record)
 -Changed subroutines:
 --check_bk008_vs_300($record): 
 ---added cross-checking for codes a, b, c, g (ill., map(s), port(s)., music)
 ---added checking for 'p. ' or 'v. ' or 'leaves ' in subfield 'a'
 ---added checking for 'cm.', 'mm.', 'in.' in subfield 'c'
 --parse008vs300b
 ---revised check for 'm', phono. (which our catalogers don't currently use)
 --Added check in check_bk008_vs_bibrefandindex($record) for 'Includes index.' (or indexes) in 504
 ---This has a workaround I would like to figure out how to fix
 
Version 1.00 (update to 0.95): First release July 18, 2004.

 -Fixed bugs causing check_003 and check_010 subroutines to fail (Thanks to Rich Ackerman)
 -Added to documentation
 -Misc. cleanup
 -Added skip of 787 fields to check_internal_spaces
 -Added subroutines:
 --check_end_punct_300($record)
 --check_bk008_vs_300($record)
 ---parse008vs300b
 --check_490vs8xx($record)
 --check_245ind1vs1xx($record)
 --matchpubdates($record)
 --check_bk008_vs_bibrefandindex($record)

Version 1 (original version (actually version 0.95)): First release, June 22, 2004

=head1 SEE ALSO

MARC::Record -- Required for this module to work.

MARC::Lint -- In the MARC::Record distribution and basis for this module.

MARC::Lintadditons -- Extension of MARC::Lint for checks involving individual tags.
(vs. cross-field checking covered in this module).
Available at http://home.inwave.com/eija (and may be merged into MARC::Lint).

MARC pages at the Library of Congress (http://www.loc.gov/marc)

Anglo-American Cataloging Rules, 2nd ed., 2002 revision, plus updates.

Library of Congress Rule Interpretations to AACR2R.

MARC Report (http://www.marcofquality.com) -- More full-featured commercial program for validating MARC records.

=head1 LICENSE

This code may be distributed under the same terms as Perl itself. 

Please note that this module is not a product of or supported by the 
employers of the various contributors to the code.

=head1 AUTHOR

Bryan Baldus
eijabb@cpan.org

Copyright (c) 2003-2004

=cut

1;
