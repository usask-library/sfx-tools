#!/usr/bin/perl
###
###  sfx2ejdb.pl - Convert the resolved SFX data file to a format suitable
###                for use in an E-Journal A-Z type database system
###
###  Darryl Friesen (Darryl.Friesen@usask.ca)
###  University of Saskatchewan Library
###
###  Version 3.22
###

use strict;
use Encode;
use Getopt::Long;

my $VERSION = 'SFX-Tools/3.22 SFX to E-Journal File Format Converter';


### Default config file is a file named 'sfxtools.conf' located in the same directory as the scripts.
### We first need to find out what directory the scripts are being run from
use FindBin qw($Bin);
use lib "$Bin/../lib";

my $ConfigFile = $Bin . '/sfx-tools.conf';


###
### Get command line options
###
my $DEBUG = 0;


### Allowable command line arguments
my %options = (
    'config' => \$ConfigFile,
    'debug'  => \$DEBUG
);
GetOptions(\%options, 'config=s', 'altlookup!', 'debug+');


###
###  Read config file
###
open(CONFIG, $ConfigFile) || die('Unable to open configuration file ' . $ConfigFile . ': ' . $! . "\n");
my %Config = (
    'DEBUG_LEVEL' => 0
);
while (<CONFIG>) {
    chomp;              # no newline
    s/#.*//;            # no comments
    s/^\s+//;           # no leading white
    s/\s+$//;           # no trailing white
    next unless length; # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $Config{uc($var)} = $value;
}
### Command-line DEBUG value should override the one from the config file
$Config{'DEBUG_LEVEL'} = $DEBUG if ($DEBUG > 0);

print $VERSION . "\n" if ($Config{'DEBUG_LEVEL'});

my %longest;

my %TargetGroups = (
    'AIP Scitation'              => 'AIP Scitation',
    'Allen Press'                => 'Allen Press',
    #  'American Chemical Society'	=> 'American Chemical Society',	# currently only 1 activated
    'American Physical Society'  => 'American Physical Society',
    'BioMed Central'             => 'BioMed Central',
    #  'Books24x7'			=> 'Books24x7',	# currently only 1 activated
    'CSA SAGE'                   => 'SAGE Journals Online',
    'East View'                  => 'East View',
    'EBSCOHOST'                  => 'EBSCOhost',
    #  'W B Saunders'		=> 'Elsevier Health',	# currently only 1 activated
    'Elsevier SD'                => 'Elsevier ScienceDirect',
    'GALEGROUP'                  => 'GaleGroup',
    'HIGHWIRE'                   => 'HighWire Press',
    'IEEE'                       => 'IEEE/IEE Electronic Library',
    'Ingenta Connect'            => 'Ingenta Connect',
    'Institute of Physics'       => 'Institute of Physics',
    'JSTOR'                      => 'JSTOR',
    'Metapress'                  => 'Metapress',
    'Project Muse'               => 'Project Muse',
    'ProQuest'                   => 'ProQuest',
    'Royal Society of Chemistry' => 'Royal Society of Chemistry',
    'Synergy'                    => 'Synergy',
    'Wiley Interscience'         => 'Wiley Interscience'
);

#
#  Unmapped UTF-8 codes can be seen using the following in-line
#  perl script on the resultant tab delimited file
#
#     cat e-collection.tab | perl -e 'while (<>) { @stuff = split("\t"); print $stuff[5] . "\n"; } ' | grep -v -E "^[[:space:][:alnum:][:punct:]]+$" | more
#
my %utf8_sort_title = (
    "\xC2\x92"     => '', #   This is likely an error in the SFX title; c2 92 is a control character
    "\x1Bp"        => '', #   This is likely an error in the SFX title
    "\x1Bs"        => '', #   This is likely an error in the SFX title

    "\xC2\xA1"     => '',  #   ?
    "\xC2\xA2"     => '',  #   ?
    "\xC2\xA3"     => '',  #   ?
    "\xC2\xA4"     => '',  #   ?
    "\xC2\xA5"     => '',  #   ?
    "\xC2\xA6"     => '',  #   ?
    "\xC2\xA7"     => '',  #   ?
    "\xC2\xA8"     => '',  #   ?
    "\xC2\xA9"     => '',  #   ?
    "\xC2\xAA"     => '',  #   ?
    "\xC2\xAB"     => '',  #   ?
    "\xC2\xAC"     => '',  #   ?
    "\xC2\xAD"     => '',  #   ?
    "\xC2\xAE"     => '',  #   ?
    "\xC2\xAF"     => '',  #   ?
    "\xC2\xB0"     => '',  #   ?
    "\xC2\xB1"     => '',  #   ?
    "\xC2\xB2"     => '',  #   ?
    "\xC2\xB3"     => '',  #   ?
    "\xC2\xB4"     => '',  #   ?
    "\xC2\xB5"     => '',  #   ?
    "\xC2\xB6"     => '',  #   ?
    "\xC2\xB7"     => '',  #   ?
    "\xC2\xB8"     => '',  #   ?
    "\xC2\xB9"     => '',  #   ?
    "\xC2\xBA"     => '',  #   ?
    "\xC2\xBB"     => '',  #   ?
    "\xC2\xBC"     => '',  #   ?
    "\xC2\xBD"     => '',  #   ?
    "\xC2\xBE"     => '',  #   ?
    "\xC2\xBF"     => '',  #   ?
    "\xC3\x80"     => 'A', #   ?
    "\xC3\x81"     => 'A', #   ?
    "\xC3\x82"     => 'A', #   ?    "\xC3\x83" =>	'A',	#   ?    "\xC3\x84" =>	'A',	#   ?    "\xC3\x85" =>	'A',	#   ?    "\xC3\x86" =>	'AE',	#   ?    "\xC3\x87" =>	'C',	#   ?    "\xC3\x88" =>	'E',	#   ?    "\xC3\x89" =>	'E',	#   ?    "\xC3\x8A" =>	'E',	#   ?    "\xC3\x8B" =>	'E',	#   ?    "\xC3\x8C" =>	'I',	#   ?    "\xC3\x8D" =>	'I',	#   ?    "\xC3\x8E" =>	'I',	#   ?    "\xC3\x8F" =>	'I',	#   ?    "\xC3\x90" =>	'D',	#   ?    "\xC3\x91" =>	'N',	#   ?    "\xC3\x92" =>	'O',	#   ?    "\xC3\x93" =>	'O',	#   ?    "\xC3\x94" =>	'O',	#   ?    "\xC3\x95" =>	'O',	#   ?    "\xC3\x96" =>	'O',	#   ?    "\xC3\x97" =>	'x',	#   ?    "\xC3\x98" =>	'0',	#   ?    "\xC3\x99" =>	'U',	#   ?    "\xC3\x9A" =>	'U',	#   ?    "\xC3\x9B" =>	'U',	#   ?    "\xC3\x9C" =>	'U',	#   ?    "\xC3\x9D" =>	'Y',	#   ?    "\xC3\x9E" =>	'P',	#   ?    "\xC3\x9F" =>	'B',	#   ?    "\xC3\xA0" =>	'a',	#   ?    "\xC3\xA1" =>	'a',	#   ?    "\xC3\xA2" =>	'a',	#   ?    "\xC3\xA3" =>	'a',	#   ?    "\xC3\xA4" =>	'a',	#   ?    "\xC3\xA5" =>	'a',	#   ?    "\xC3\xA6" =>	'ae',	#   ?    "\xC3\xA7" =>	'c',	#   ?    "\xC3\xA8" =>	'e',	#   ?    "\xC3\xA9" =>	'e',	#   ?    "\xC3\xAA" =>	'e',	#   ?    "\xC3\xAB" =>	'e',	#   ?    "\xC3\xAC" =>	'i',	#   ?    "\xC3\xAD" =>	'i',	#   ?    "\xC3\xAE" =>	'i',	#   ?    "\xC3\xAF" =>	'i',	#   ?    "\xC3\xB0" =>	'o',	#   ?    "\xC3\xB1" =>	'n',	#   ?    "\xC3\xB2" =>	'o',	#   ?    "\xC3\xB3" =>	'o',	#   ?    "\xC3\xB4" =>	'o',	#   ?    "\xC3\xB5" =>	'o',	#   ?    "\xC3\xB6" =>	'o',	#   ?    "\xC3\xB7" =>	'',	#   ?    "\xC3\xB8" =>	'',	#   ?    "\xC3\xB9" =>	'u',	#   ?    "\xC3\xBA" =>	'u',	#   ?    "\xC3\xBB" =>	'u',	#   ?    "\xC3\xBC" =>	'u',	#   ?    "\xC3\xBD" =>	'y',	#   ?    "\xC3\xBE" =>	'p',	#   ?
    "\xC3\xBF"     => 'y', #   ?

    "\xC4\x80"     => 'A', #   A with macron
    "\xC4\x81"     => 'a', #   a with macron
    "\xC4\x93"     => 'e', #   LATIN SMALL LETTER E WITH MACRON
    "\xC4\xAB"     => 'i', #   LATIN SMALL LETTER I WITH MACRON
    "\xC4\xB1"     => 'i', #   LATIN SMALL LETTER DOTLESS I

    "\xC5\x8D"     => 'o', #   LATIN SMALL LETTER O WITH MACRON

    "\xCA\xBB"     => '', #   MODIFIER LETTER TURNED COMMA

    "\xCB\x87"     => '', #   Caron

    "\xCC\xA3"     => '', #   COMBINING DOT BELOW

    "\xEF\xB8\xA0" => '', #   Russian combining ligature
    "\xEF\xB8\xA1" => ''  #   Russian combining ligature
);


### These are to correct display anomolies
my %utf8_display_title = (
    "\xC2\x92" => '', #   This is likely an error in the SFX title; c2 92 is a control character
    "\x1Bp"    => '', #   This is likely an error in the SFX title
    "\x1Bs"    => '', #   This is likely an error in the SFX title

    #    "\xC4\x93"	=>	"e"	# Corrects problem with Symploke
);


### Process the SFX data dump file
open(SFX, $Config{'DATA_DIR'} . '/sfx_data.txt') || die("Failed to open SFX data file " . $Config{'DATA_DIR'} . "/sfx_data.txt: $!\n");

### Open up our output files, one for the EJDB data, one for SFX Categories
open(OUT, '>' . $Config{'DATA_DIR'} . '/ejdb_data.txt') || die("ERROR: Failed to open EJDB output file " . $Config{'DATA_DIR'} . "/ejdb_data.txt: $!\n");
open(CAT, '>' . $Config{'DATA_DIR'} . '/ejdb_cats.txt') || die("ERROR: Failed to open EJDB category file " . $Config{'DATA_DIR'} . "/ejdb_cats.txt: $!\n");

my %Cats;
while (<SFX>) {
    chomp;

    ### Split the line into it's component parts
    my ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded) = split("\t");

    ### If we are limiting the EJDB output to just JOURNAL, make sure we skip anything that isn't
    if (($Config{'EJDB_INCLUDE_TYPE'} eq 'JOURNAL') &&
        (($OBJECT_TYPE ne 'JOURNAL') && ($OBJECT_TYPE ne 'SERIES') && ($OBJECT_TYPE ne 'CONFERENCE') && ($OBJECT_TYPE ne 'NEWSPAPER') && ($OBJECT_TYPE ne 'TRANSCRIPT') && ($OBJECT_TYPE ne 'WIRE'))) {
        print STDERR "sfx2ejdb: Skipping BOOK:\t" . $PORTFOLIO_ID . "\t" . $OBJECT_TYPE . "\t" . $TARGET_PUBLIC_NAME . "\t" . $TITLE . "\n" if ($Config{'DEBUG_LEVEL'});
        next;
    }

    if ($PORTFOLIO_ID eq '') {
        print STDERR "sfx2ejdb: Missing Portfolio_ID\n" if ($Config{'DEBUG_LEVEL'});
        next;
    }
    if ($TITLE eq '') {
        print STDERR "sfx2ejdb: Missing Title\n" if ($Config{'DEBUG_LEVEL'});
        next;
    }

    my $SortTitle = $TITLE;
    ### Misc characters
    $SortTitle =~ s/^[\.\,\-\s\'\"]+//;
    ### English articles
    $SortTitle =~ s/^A\s+//i;
    $SortTitle =~ s/^An\s+//i;
    $SortTitle =~ s/^The\s+//i;
    ### French articles
    $SortTitle =~ s/^Le\s+//i;
    $SortTitle =~ s/^La\s+//i;
    $SortTitle =~ s/^L\'+//i;
    $SortTitle =~ s/^Les\s+//i;
    ### Gernam articles
    $SortTitle =~ s/^De\s+//i;
    $SortTitle =~ s/^Der\s+//i;
    $SortTitle =~ s/^Das\s+//i;
    $SortTitle =~ s/^Die\s+//i;

    # Handle UTF-8 characters
    foreach my $search (keys(%utf8_sort_title)) {
        $SortTitle =~ s#$search#$utf8_sort_title{$search}#g;
    }

    foreach my $search (keys(%utf8_display_title)) {
        $TITLE =~ s#$search#$utf8_display_title{$search}#g;
    }

    # Group some of Targets together
    my $TargetGroup = $TARGET_PUBLIC_NAME;
    foreach my $target (keys(%TargetGroups)) {
        $TargetGroup = $TargetGroups{$target} if ($TARGET_PUBLIC_NAME =~ /^$target/i);
    }


    # Rank the targets; this can be used to display certain targets in preference to others
    my $TargetRank = 1000;

    $TargetRank = 10 if ($TARGET_PUBLIC_NAME =~ m#^American Chemical Society#);
    $TargetRank = 20 if ($TARGET_PUBLIC_NAME =~ m#^American Institute of Physics#);
    $TargetRank = 30 if ($TARGET_PUBLIC_NAME =~ m#^American Mathematical Society#);
    $TargetRank = 40 if ($TARGET_PUBLIC_NAME =~ m#^American Medical Association#);
    $TargetRank = 50 if ($TARGET_PUBLIC_NAME =~ m#^American Physical Society#);
    $TargetRank = 60 if ($TARGET_PUBLIC_NAME =~ m#^Annual Reviews#);
    $TargetRank = 70 if ($TARGET_PUBLIC_NAME =~ m#^Association for Computing Machinery#);
    $TargetRank = 80 if ($TARGET_PUBLIC_NAME =~ m#^BioMed Central#);
    $TargetRank = 90 if ($TARGET_PUBLIC_NAME =~ m#^BioOne#);
    $TargetRank = 100 if ($TARGET_PUBLIC_NAME =~ m#^Cambridge University Press#);
    $TargetRank = 110 if ($TARGET_PUBLIC_NAME =~ m#^Crystallography Journals#);
    $TargetRank = 120 if ($TARGET_PUBLIC_NAME =~ m#^CSIRO#);
    $TargetRank = 130 if ($TARGET_PUBLIC_NAME =~ m#^Duke University Journals#);
    $TargetRank = 140 if ($TARGET_PUBLIC_NAME =~ m#^EBSCO ATLA#);
    $TargetRank = 150 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier ScienceDirect#);
    $TargetRank = 160 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Agricultural#);
    $TargetRank = 170 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Business#);
    $TargetRank = 180 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Economics#);
    $TargetRank = 190 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Neuroscience#);
    $TargetRank = 200 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Pharmacology#);
    $TargetRank = 210 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Psychology#);
    $TargetRank = 220 if ($TARGET_PUBLIC_NAME =~ m#^Elsevier SD Backfile Social Sciences#);
    $TargetRank = 230 if ($TARGET_PUBLIC_NAME =~ m#^Emerald#);
    $TargetRank = 240 if ($TARGET_PUBLIC_NAME =~ m#^E\*Subscribe#);
    $TargetRank = 250 if ($TARGET_PUBLIC_NAME =~ m#^Hein Online#);
    $TargetRank = 260 if ($TARGET_PUBLIC_NAME =~ m#^IEEE#);
    $TargetRank = 260 if ($TARGET_PUBLIC_NAME =~ m#^IEEE Computer Society#);
    $TargetRank = 270 if ($TARGET_PUBLIC_NAME =~ m#^Institute of Physics#);
    $TargetRank = 280 if ($TARGET_PUBLIC_NAME =~ m#^Institute of Physics  Historical Archives#);
    $TargetRank = 290 if ($TARGET_PUBLIC_NAME =~ m#^Journals\@Ovid#);
    $TargetRank = 300 if ($TARGET_PUBLIC_NAME =~ m#^JSTOR Business Collection#);
    $TargetRank = 310 if ($TARGET_PUBLIC_NAME =~ m#^JSTOR Ecology and Botany#);
    $TargetRank = 320 if ($TARGET_PUBLIC_NAME =~ m#^JSTOR General Sciences#);
    $TargetRank = 330 if ($TARGET_PUBLIC_NAME =~ m#^JSTOR Arts and Sciences 1#);
    $TargetRank = 340 if ($TARGET_PUBLIC_NAME =~ m#^JSTOR Arts and Sciences 2#);
    $TargetRank = 350 if ($TARGET_PUBLIC_NAME =~ m#^JSTOR Arts and Sciences 3#);
    $TargetRank = 360 if ($TARGET_PUBLIC_NAME =~ m#^Kluwer Academic#);
    $TargetRank = 370 if ($TARGET_PUBLIC_NAME =~ m#^Miscellaneous Ejournals#);
    $TargetRank = 380 if ($TARGET_PUBLIC_NAME =~ m#^National Research Council Canada#);
    $TargetRank = 390 if ($TARGET_PUBLIC_NAME =~ m#^Nature#);
    $TargetRank = 400 if ($TARGET_PUBLIC_NAME =~ m#^netLibrary#);
    $TargetRank = 410 if ($TARGET_PUBLIC_NAME =~ m#^OCLC FirstSearch ECO#);
    $TargetRank = 420 if ($TARGET_PUBLIC_NAME =~ m#^Oxford University Press#);
    $TargetRank = 430 if ($TARGET_PUBLIC_NAME =~ m#^Portland Press#);
    $TargetRank = 440 if ($TARGET_PUBLIC_NAME =~ m#^Project Muse#);
    $TargetRank = 450 if ($TARGET_PUBLIC_NAME =~ m#^Royal Society of Chemistry#);
    $TargetRank = 460 if ($TARGET_PUBLIC_NAME =~ m#^Springer#);
    $TargetRank = 470 if ($TARGET_PUBLIC_NAME =~ m#^Synergy#);
    $TargetRank = 480 if ($TARGET_PUBLIC_NAME =~ m#^Thieme Connect#);
    $TargetRank = 490 if ($TARGET_PUBLIC_NAME =~ m#^Wiley Interscience#);
    $TargetRank = 500 if ($TARGET_PUBLIC_NAME =~ m#^EBSCOhost Electronic Journals Service#);
    $TargetRank = 510 if ($TARGET_PUBLIC_NAME =~ m#^Highwire Press#);
    $TargetRank = 520 if ($TARGET_PUBLIC_NAME =~ m#^Ingenta#);

    $TargetRank = 5000 if ($TARGET_PUBLIC_NAME =~ m#^GaleGroup#);

    # The 'longest' stuff is for debugging, to determine how large a VARCHAR field in our database tables
    #    $longest{'Title'}		= length($Title)	if (($longest{'Title'} eq '') || ($longest{'Title'} < length($Title)));
    #    $longest{'SortTitle'}	= length($SortTitle)	if (($longest{'SortTitle'} eq '') || ($longest{'SortTitle'} < length($SortTitle)));
    #    $longest{'ISSN'}		= length($ISSN)		if (($longest{'ISSN'} eq '') || ($longest{'ISSN'} < length($ISSN)));
    #    $longest{'Availability'}	= length($Availability)	if (($longest{'Availability'} eq '') || ($longest{'Availability'} < length($Availability)));
    #    $longest{'AbbrevTitle'}	= length($AbbrevTitle)	if (($longest{'AbbrevTitle'} eq '') || ($longest{'AbbrevTitle'} < length($AbbrevTitle)));


    print OUT join("\t", $PORTFOLIO_ID, $OBJECT_ID, $TITLE, $SortTitle, $ISSN, $eISSN, $TARGET_PUBLIC_NAME, $TargetGroup, $TargetRank, $THRESHOLD, $URL, $DateResolved, $DateAdded) . "\r\n";

    #    # Process the Category data;  Categories are seperated by a "|"
    my (@cats) = split(/\s+\|\s+/, $CATEGORIES);
    foreach my $cat (@cats) {
        # Remove any leading/trailing spaces
        $cat =~ s/^\s+//;
        $cat =~ s/^\s+//;

        # Categories are hierarchical using ' - ' to delimit levels.
        # Use a TAB between the levels instead
        $cat =~ s#\s+\-\s+#\t#g;

        # The categories apply to Objects, not Portfolios,
        # so we need track them for uniqueness
        if ($Cats{$OBJECT_ID . "\t" . $cat} eq '') {
            $Cats{$OBJECT_ID . "\t" . $cat} = 1;
            print CAT $OBJECT_ID . "\t" . $cat . "\n";
        }
    }
}
close(IN);
close(OUT);
close(CAT);

#foreach my $key (keys %longest)
#{
#    print STDERR $key . "\t" . $longest{$key} . "\n";
#}
