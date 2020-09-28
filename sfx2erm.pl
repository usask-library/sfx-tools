#!/usr/bin/perl

###
###  sfx2erm.pl - Convert the resolved SFX data file to a format suitable for ERM
###
###  This script converts the resolved SFX data file (the one with
###  resolved URLs produced by sfx_resolve_urls.pl) into a format
###  suitable for import into Innovative Interfaces ERM module.
###  ERM seems to have trouble with the UTF-8 characters in the SFX file,
###  so the output of this script is converted to ISO-8859-1
###
###
###  Doug Macdonald (Doug.Macdonald@usask.ca)
###  Darryl Friesen (Darryl.Friesen@usask.ca)
###  University of Saskatchewan Library
###
###  Version 3.22
###

use strict;
use Encode;
use Getopt::Long;

my $VERSION = 'SFX-Tools/3.22 SFX to ERM File Format Converter';


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

### ALT_LOOKUP needs to be a boolean here in the script
$Config{'ALT_LOOKUP'} = 1 if ((uc($Config{'ALT_LOOKUP'}) eq 'TRUE') || (uc($Config{'ALT_LOOKUP'}) eq 'YES'));
$Config{'ALT_LOOKUP'} = 0 if ((uc($Config{'ALT_LOOKUP'}) eq 'FALSE') || (uc($Config{'ALT_LOOKUP'}) eq 'NO'));

# Set some defaults for captions in the ERM file (if they weren't specified in sfx-tools.conf);
$Config{'ENUMCAPTION1'} = 'Volume' if ($Config{'ENUMCAPTION1'} eq '');
$Config{'ENUMCAPTION2'} = 'Issue' if ($Config{'ENUMCAPTION2'} eq '');

print $VERSION . "\n" if ($Config{'DEBUG_LEVEL'});


### In the case where no URL was returned by the SFX API, this URL will be used.
### It should produce the standard SFX menu instead of linking directly to the journal
my $openURL = $Config{'SFX_SERVER'} . '?url_ver=Z39.88-2004&url_ctx_fmt=infofi/fmt:kev:mtx:ctx&ctx_enc=info:ofi/enc:UTF-8&ctx_ver=Z39.88-2004&rfr_id=info:sid/sfxit.com:azlist&sfx.ignore_date_threshold=1&rft.object_id=';


### Get the current date and time
my ($sec, $min, $hr, $mday, $curmon, $curyr) = localtime(time);
$curyr += 1900;
$curmon += 1;



{
    package EJournal;

    sub new {
        my ($class, $title, $issn, $isbn, $object_id, $target, $url) = @_;
        my $self;
        $self->{'title'} = $title;
        $self->{'issn'} = $issn;
        $self->{'isbn'} = $isbn;
        $self->{'target'} = $target;
        $self->{'startDate'} = [];
        $self->{'endDate'} = [];
        $self->{'embargo'} = 0;
        $self->{'object_id'} = $object_id;
        $self->{'startVolume'} = '';
        $self->{'endVolume'} = '';
        $self->{'startIssue'} = '';
        $self->{'endIssue'} = '';
        $self->{'errlevel'} = 0;
        $self->{'errmsg'} = '';
        if ($url ne '') {
            $self->{'URL'} = $url;
        }
        else {
            $self->{'URL'} = $openURL . $object_id;
        }

        bless($self, $class);
        return $self;
    }

    sub ToString {
        my $self = shift;
        my $displaystr = "";

        foreach my $start (@{$self->{startDate}}) {
            my $end = shift @{$self->{endDate}};
            $displaystr .= $self->{title} . "|";
            $displaystr .= $self->{issn} . "|";
            $displaystr .= $self->{isbn} . "|";
            $displaystr .= $start . "|";
            $displaystr .= $end . "|";
            $displaystr .= $self->{target} . "|";
            $displaystr .= $self->{URL} . "|";
            $displaystr .= $self->{embargo};
            if ($Config{'ALT_LOOKUP'}) {
                $displaystr .= '|SFX(' . $self->{object_id} . ')';
            }
            $displaystr .= '|' . $Config{'ENUMCAPTION1'} . '|' . $self->{startVolume} . '|' . $self->{endVolume};
            $displaystr .= '|' . $Config{'ENUMCAPTION2'} . '|' . $self->{startIssue} . '|' . $self->{endIssue};
            $displaystr .= "\r\n";
        }
        return $displaystr;
    }

    sub SetDate {
        my ($self, $yr, $mn, $day) = @_;

        ### What happens to ERM if we return just the year, instead of assuming first/last of the month
        #return sprintf("%d/%d/%d",$mn,$day,$yr);
        return $yr;
    }

    sub ParseFix {
        my ($self, $fix) = @_;

        #($pid,$issn,$target,$startDate,$endDate,$embargo) = split /\|/,$fix;
    }

    sub ParseAvailability {
        my $self = shift;
        my $avail = shift;

        if ($avail eq "") {
        }
        # Availability: from YEAR volume VOLUME issue ISSUE (i.e. Availability: from 2001 volume 25 issue A)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\w+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, "";
            $self->{startVolume} = $2;
            $self->{startIssue} = $3;
        }
        # Availability: from YEAR volume VOLUME (i.e. Availability: from 2001 volume 22)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, "";
            $self->{startVolume} = $2;
        }
        # Availability: from YEAR issue ISSUE  (i.e. Availability: from 1986 issue 1)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, "";
            $self->{startIssue} = $2;
        }
        # Availability: from YEAR  (i.e. Availability: from 2003)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, "";
        }
        # Availability: YEAR  (i.e. Availability: 2003)
        elsif ($avail =~ m#^\s*Availability:\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($1, 12, 31);
        }
        # Availability: YEAR volume VOLUME issue ISSUE  (i.e. Availability: 2002 volume 540 issue 3)
        elsif ($avail =~ m#^\s*Availability:\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            #push @{$self->{startDate}}, $self->SetDate($1,1,1);
            #push @{$self->{endDate}}, $self->SetDate($1,12,31);
            $self->{startVolume} = $2;
            $self->{startIssue} = $3;
        }
        # Availability: from YEAR volume VOLUME issue ISSUE to YEAR volume VOLUME issue ISSUE  (i.e. Availability: from 1989 volume 2 issue 1 to 1992 volume 5 issue 1)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($4, 12, 31);
            $self->{startVolume} = $2;
            $self->{startIssue} = $3;
            $self->{endVolume} = $5;
            $self->{endIssue} = $6;
        }
        # Availability: from YEAR issue ISSUE to YEAR issue ISSUE  (i.e. Availability: from 1989 issue 1 to 1992 issue 1)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+issue\s+(\d+)\s+to\s+(\d{4})\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($3, 12, 31);
            $self->{startIssue} = $2;
            $self->{endIssue} = $4;
        }
        # Availability: from YEAR issue ISSUE to YEAR volume VOLUME issue ISSUE  (i.e. Availability: from 1849 issue 1 to 1995 volume 43 issue 1)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+issue\s+(\d+)\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($3, 12, 31);
            $self->{startIssue} = $2;
            $self->{endVolume} = $4;
            $self->{endIssue} = $5;
        }
        # Availability: from YEAR issue ISSUE to YEAR volume VOLUME  (i.e. Availability: from 1998 issue 311 to 2005 volume 342)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+issue\s+(\d+)\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($3, 12, 31);
            $self->{startIssue} = $2;
            $self->{endVolume} = $4;
        }
        # Availability: from YEAR volume VOLUME issue ISSUE to YEAR volume VOLUME  (i.e. Availability: from 1992 volume 1 issue 1 to 1993 volume 2)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($4, 12, 31);
            $self->{startVolume} = $2;
            $self->{startIssue} = $3;
            $self->{endVolume} = $5;
        }
        # Availability: from YEAR volume VOLUME issue ISSUE to YEAR issue ISSUE  (i.e. Availability: from 1962 volume 1 issue 1 to 1995 issue 1)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s+to\s+(\d{4})\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($4, 12, 31);
            $self->{startVolume} = $2;
            $self->{startIssue} = $3;
            $self->{endIssue} = $5;
        }
        # Availability: from YEAR volume VOLUME to YEAR volume VOLUME issue ISSUE  (i.e.  Availability: from 1949 volume 1 to 2000 volume 50 issue 6)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($3, 12, 31);
            $self->{startVolume} = $2;
            $self->{endVolume} = $4;
            $self->{endIssue} = $5;
        }
        # Availability: from YEAR volume VOLUME issue ISSUE to YEAR  (i.e.  Availability: from 1997 volume 273 issue 4 to 2001)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s+to\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($4, 12, 31);
            $self->{startVolume} = $2;
            $self->{startIssue} = $3;
        }
        # Availability: from YEAR volume VOLUME to YEAR volume VOLUME  (i.e. Availability: from 1915 volume 1 to 1925 volume 11)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($3, 12, 31);
            $self->{startVolume} = $2;
            $self->{endVolume} = $4;
        }
        # Availability: from YEAR to YEAR volume VOLUME issue ISSUE  (i.e. Availability: from 1995 to 2001 volume 133 issue 4)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($2, 12, 31);
            $self->{endVolume} = $3;
            $self->{endIssue} = $4;
        }
        # Availability: from YEAR to YEAR volume VOLUME  (i.e. Availability: from 1995 to 2004 volume 38)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($2, 12, 31);
            $self->{endVolume} = $3;
        }
        # Availability: from YEAR to YEAR issue ISSUE  (i.e. Availability: from 1995 to 2004 issue 38)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+to\s+(\d{4})\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($2, 12, 31);
            $self->{endIssue} = $3;
        }
        # Availability: from YEAR volume VOLUME to YEAR  (i.e. Availability: from 1959 volume 1 to 2003)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+to\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($3, 12, 31);
            $self->{startVolume} = $2;
        }
        # Availability: from YEAR issue undef to YEAR  (Availability: from 1963 issue undef to 1997)
        #  ** This one looks like an error within SFX
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+issue\s+undef\s+to\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($2, 12, 31);
        }
        # Availability: from YEAR volume VOLUME issue undef to YEAR volume VOLUME  (i.e. Availability: from 2000 volume 42 issue undef  to 2002 volume 44)
        #  ** This one looks like an error within SFX
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d+)\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+undef\s+to\s+(\d+)\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $1;
            push @{$self->{endDate}}, $3;
            $self->{startVolume} = $2;
            $self->{endVolume} = $4;
        }
        # Availability: from YEAR to YEAR (i.e. Availability: from 1999 to 2000)
        elsif ($avail =~ m#^\s*Availability:\s+from\s+(\d{4})\s+to\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($1, 1, 1);
            push @{$self->{endDate}}, $self->SetDate($2, 12, 31);
        }
        # Availability: Most recent NUMBER years available  (i.e. Availability: Most recent 2 years available)
        elsif ($avail =~ m#^\s*Availability:\s+Most\s+recent\s+(\d+)\s+(year|years)\s+available\s*$#) {
            push @{$self->{startDate}}, $self->SetDate($curyr - $1, $curmon, 1);
            push @{$self->{endDate}}, "";
        }
        # Availability: Most recent NUMBER year not available  (i.e. Availability: Most recent 1 year not available)
        elsif ($avail =~ m#^\s*Availability: Most recent (\d+) (year|years) not available\s*$#) {
            $self->{embargo} = $1 * 365;
        }
        # Availability: Most recent NUMBER year NUMBER months not available  (i.e. Availability: Most recent 1 year 6 months not available)
        elsif ($avail =~ m#^\s*Availability: Most recent (\d+) (year|years) (\d+) months not available\s*$#) {
            $self->{embargo} = ($1 * 365) + ($2 * 30);
        }
        # Availability: Most recent NUMBER months not available  (i.e. Availability: Most recent 6 months not available)
        elsif ($avail =~ m#^\s*Availability: Most recent (\d+) (months|month) not available\s*$#) {
            $self->{embargo} = $1 * 30;
        }
        # Availability: to YEAR volume VOLUME issue ISSUE  (i.e. Availability: to 2000 volume 50 issue 6)
        elsif ($avail =~ m#^\s*Availability:\s+to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, "";
            push @{$self->{endDate}}, $self->SetDate($1, 12, 31);
            $self->{endVolume} = $2;
            $self->{endIssue} = $3;
        }
        # to YEAR volume VOLUME issue ISSUE  (i.e. to 2000 volume 50 issue 6)
        elsif ($avail =~ m#^\s*to\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, "";
            push @{$self->{endDate}}, $self->SetDate($1, 12, 31);
            $self->{endVolume} = $2;
            $self->{endIssue} = $3;
        }
        # Availability: in YEAR volume VOLUME issue ISSUE  (i.e. Availability: in 1983 volume 76 issue 2)
        elsif ($avail =~ m#^\s*Availability:\s+in\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s+issue\s+(\d+)\s*$#) {
            push @{$self->{startDate}}, $1;
            push @{$self->{endDate}}, $1;
            $self->{startVolume} = $2;
            $self->{endVolume} = $2;
            $self->{startIssue} = $3;
            $self->{endIssue} = $3;
        }
        # Availability: in YEAR volume VOLUME  (i.e. Availability: in 2005 volume 1)
        elsif ($avail =~ m#^\s*Availability:\s+in\s+(\d{4})\s+volume\s+(\d+[A-Za-z]?)\s*$#) {
            push @{$self->{startDate}}, $1;
            push @{$self->{endDate}}, $1;
            $self->{startVolume} = $2;
            $self->{endVolume} = $2;
        }
        # Availability: in YEAR  (i.e. Availability: in 1993)
        elsif ($avail =~ m#^\s*Availability:\s+in\s+(\d{4})\s*$#) {
            push @{$self->{startDate}}, $1;
            push @{$self->{endDate}}, $1;
        }
        else {
            $self->{errlevel} = 1;
            $self->{errmsg} = 'Unparsed availablity: ' . $avail . "\n";
        }
    }
}


### Open up our output files, one for the ERM data, one for (availability) errors
open(OUT, '>' . $Config{'DATA_DIR'} . '/erm_data.txt') || die("ERROR: Failed to open output file " . $Config{'DATA_DIR'} . "/erm_data.txt: $!\n");
open(ERR, '>' . $Config{'DATA_DIR'} . '/erm_errors.log') || die("ERROR: Failed to open error log file " . $Config{'DATA_DIR'} . "/erm_errors.log: $!\n");


### Process the SFX data dump file
open(ECOLLECTION, $Config{'DATA_DIR'} . '/sfx_data.txt') || die("Failed to open SFX data file " . $Config{'DATA_DIR'} . "/sfx_data.txt: $!\n");
if ($Config{'ALT_LOOKUP'}) {
    print OUT "TITLE|ISSN|ISBN|START_DATE|END_DATE|PROVIDER|URL|EMBARGO|ALTLOOKUP|ENUMCAPTION1|ENUMSTART1|ENUMEND1|ENUMCAPTION2|ENUMSTART2|ENUMEND2\n";
}
else {
    print OUT "TITLE|ISSN|ISBN|START_DATE|END_DATE|PROVIDER|URL|EMBARGO|ENUMCAPTION1|ENUMSTART1|ENUMEND1|ENUMCAPTION2|ENUMSTART2|ENUMEND2\n";
}

while (<ECOLLECTION>) {
    ### Split the line into it's component parts
    my ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded) = split("\t");

    ### If we are limiting the ERM output to just JOURNAL, make sure we skip anything that isn't
    if (($Config{'ERM_INCLUDE_TYPE'} eq 'JOURNAL') &&
        (($OBJECT_TYPE ne 'JOURNAL') && ($OBJECT_TYPE ne 'SERIES') && ($OBJECT_TYPE ne 'CONFERENCE') && ($OBJECT_TYPE ne 'NEWSPAPER') && ($OBJECT_TYPE ne 'TRANSCRIPT') && ($OBJECT_TYPE ne 'WIRE'))) {
        print ERR "Skipping BOOK:\t" . $PORTFOLIO_ID . "\t" . $OBJECT_TYPE . "\t" . $TARGET_PUBLIC_NAME . "\t" . $TITLE . "\n" if ($Config{'DEBUG_LEVEL'});
        next;
    }

    ### Create a new ejournal record
    my $record = EJournal->new($TITLE, $ISSN, $ISBN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $URL);

    ### Parse the SFX availability statements
    my @lines = split /<br>/, $THRESHOLD;
    foreach my $line (@lines) {
        $record->ParseAvailability($line);
    }

    ### Dump the record either to the error log or the ERM output file
    if ($record->{errlevel} > 0) {
        print ERR join('|', 'ERROR', $PORTFOLIO_ID, $OBJECT_ID, $TARGET_PUBLIC_NAME, $TITLE, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $record->{errmsg}) . "\n";
    }
    else {
        print OUT Encode::encode('iso-8859-1', Encode::decode_utf8($record->ToString()));
    }
}
close ECOLLECTION;
close OUT;
close ERR;

exit;






