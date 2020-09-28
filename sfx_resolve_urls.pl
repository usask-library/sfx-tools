#!/usr/bin/perl
###
###  sfx_resolve_urls.pl - Resolve journal level URLs for an SFX export file
###
###  Darryl Friesen (Darryl.Friesen@usask.ca)
###  University of Saskatchewan Library
###
###  Version 3.22
###

use strict;

use LWP;
use XML::Parser::Expat;
use Time::HiRes qw(usleep);
use Date::Calc qw(Today Delta_Days);
use File::Copy;

use Getopt::Long;

my $VERSION = 'SFX-Tools/3.22 URL Resolver';


### Default config file is a file named 'sfx-tools.conf' located in the same directory as the scripts.
### We first need to find out what directory the scripts are being run from
use FindBin qw($Bin);
use lib "$Bin/../lib";

my $ConfigFile = $Bin . '/sfx-tools.conf';

###
### Get command line options
###
my $DEBUG = 0;
my $FirstTime = 0;
my $ShowUsage = 0;

### Allowable command line arguments
my %options = (
    'config'     => \$ConfigFile,
    'first-time' => \$FirstTime,
    'debug'      => \$DEBUG,
    'help'       => \$ShowUsage
);
GetOptions(\%options, 'config=s', 'first-time!', 'debug+', 'help!');

if ($ShowUsage) {
    Usage();
    exit;
}


###
###  Read config file
###
open(CONFIG, $ConfigFile) || die('Unable to open configuration file ' . $ConfigFile . ': ' . $! . "\n");

####
my %Config = (
    'DEBUG_LEVEL' => 0,
    'TTL'         => 30,
    'MAX_LOOKUPS' => 10000,
    'SLEEP_TIME'  => 500000
);
while (<CONFIG>) {
    chomp;              # no newline
    s/#.*//;            # no comments
    s/^\s+//;           # no leading white
    s/\s+$//;           # no trailing white
    next unless length; # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);

    $var = uc($var);

    # Multi-value config settings
    if (($var eq 'IGNORE_TARGET') || ($var eq 'IGNORE_ISSN') || ($var eq 'IGNORE_OBJECT') ||
        ($var eq 'EXPIRE_TARGET') || ($var eq 'EXPIRE_ISSN') || ($var eq 'EXPIRE_OBJECT')) {
        $Config{$var}{$value} = 1;
    }
    # Single-value config settings
    else {
        $Config{$var} = $value;
    }
}
### Command-line DEBUG value should override the one from the config file
$Config{'DEBUG_LEVEL'} = $DEBUG if ($DEBUG > 0);

print $VERSION . "\n" if ($Config{'DEBUG_LEVEL'});

my $Today = sprintf("%4d-%02d-%02d", Today());

my (%SFX_Data, %SFX_Previous, %Resolve, %Object_IDs, $CurrentFile, $PreviousFile);

$CurrentFile = $Config{'DATA_DIR'} . '/sfx_data.txt';
$PreviousFile = $Config{'DATA_DIR'} . '/sfx_data.previous.txt';


###
### If the sfx_data.previous.txt file doesn't exist,
### assume this is the first time the script has been run.
###
### The "first time" mode can also be triggered with the --first-time command line argument
###
if ($FirstTime || (!-e $Config{'DATA_DIR'} . '/sfx_data.previous.txt')) {
    $FirstTime = 1;

    ### Make the current and previous SFX export data files the same
    ### and set the maximum lookups to something very large.
    ### This should force resolution of every portfolio URL in the data file
    #$Config{'MAX_LOOKUPS'} = 999999;
    $PreviousFile = $CurrentFile;

    print <<EndOfWarning;
----------------------------------------------------------------------
FIRST TIME RESOLUTION

Resolving a journal level URL for every active title in your
SFX database can take a VERY long time (hours), and potentially put a
strain on your SFX server.  It is probably best to run this during
non-peak hours.
----------------------------------------------------------------------

EndOfWarning

}
else {
    ### backup the previous data files
    if (!copy($Config{'DATA_DIR'} . '/sfx_data.previous.txt', $Config{'DATA_DIR'} . '/sfx_data.backup.txt')) {
        print "Failed to create a backup copy of the previous SFX data file: $!\n";
    }
}


### Read the contents of the previous SFX data export into an associative array.
### It has the most complete info with respect to the date when objects were added,
### when the URLs were last resolved etc.

open(PREVIOUS, $PreviousFile) || die("Unable to open previous SFX data file (" . $PreviousFile . "): $!\n");
print "----------\nReading previous SFX data file ... " if ($Config{'DEBUG_LEVEL'} > 1);
while (<PREVIOUS>) {
    #chomp;
    s#[\r\n\t\s]+$##;

    ### The SFX export file is a TAB delimited file consisting of (at least) 33 fields.
    ### The format is documented in the SFX User Guide Part 1, page 80.
    ###
    ### For now we are ignoring the Institution fields.  If we run across people using them, then we'll deal with that later
    ###
    ### For now we are ignoring the Institution fields (fields 31-33).
    ### If we run across people using them, we'll deal with that later
    my ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded, @INSTITUTE_DATA);

    if ($FirstTime) {
        ### The SFX data file may have institution data in the last fields; ignore for now
        ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, @INSTITUTE_DATA) = split("\t");

        ### I guess since this is the first time, everything is new.  Maybe.  Have to think more about this.
        $DateAdded = $Today;
    }
    else {
        ### The SFX data file should have our added fields (URL, DateResolved, DateAdded) in the last fields
        ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded) = split("\t");
    }

    ### ISSN is no longer required as SFX is now supporting journals without them
    ### Object_ID IS required however.
    if ($OBJECT_ID eq '') {
        #print STDERR "Missing ISSN:\t" . $PORTFOLIO_ID . "\t" . $OBJECT_ID . "\t" . $Target . "\t" . $TITLE . "\n";
        next;
    }

    ### Some data cleanup
    $AVAILABILITY =~ s/^\s+//;
    $AVAILABILITY =~ s/\s+$//;

    $SFX_Previous{$PORTFOLIO_ID} = join("\t", $TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded);
}
close(PREVIOUS);
print "Done.\n" if ($Config{'DEBUG_LEVEL'} > 1);


### Read the contents of the current SFX data export into an associative array
open(CURRENT, $CurrentFile) || die("Unable to open current SFX data file: $!\n");
print "----------\nProcessing current SFX data file (" . $CurrentFile . "...\n" if ($Config{'DEBUG_LEVEL'} > 1);
while (<CURRENT>) {
    #chomp;
    s#[\r\n\t\s]+$##;

    ### The SFX export file is a TAB delimited file consisting of (at least) 33 fields.
    ### The format is documented in the SFX User Guide Part 1, page 80.
    ###
    ### For now we are ignoring the Institution fields (fields 31-33).
    ### If we run across people using them, we'll deal with that later
    my ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded, @INSTITUTE_DATA) = split("\t");


    ### ISSN is no longer required as SFX is now supporting journals without them
    ### Object_ID IS required however, and is used for all OpenURL resolution
    if ($OBJECT_ID eq '') {
        print STDERR "Missing OBJECT_ID:\t" . $PORTFOLIO_ID . "\t" . $TARGET_PUBLIC_NAME . "\t" . $TITLE . "\n" if ($Config{'DEBUG_LEVEL'});
        next;
    }
    ### Some journals don't have a title in SFX.  What's up with that?
    if ($TITLE eq '') {
        print STDERR "Missing title:\t" . $PORTFOLIO_ID . "\t" . $TARGET_PUBLIC_NAME . "\t" . $TITLE . "\n" if ($Config{'DEBUG_LEVEL'});
        next;
    }

    ### Keep track of the valid OBJECT_IDs we see
    $Object_IDs{$OBJECT_ID} = "X" if ($OBJECT_ID ne '');


    ### Some data cleanup
    $AVAILABILITY =~ s/^\s+//;
    $AVAILABILITY =~ s/\s+$//;


    ### The new SFX export file doesn't actually have the URL, DateResolved and DateAdded fields
    ### Those are added by this program; grab the values from the previous (resolved) version of the export file
    my ($URL, $DateResolved, $DateAdded);
    if ($SFX_Previous{$PORTFOLIO_ID} ne '') {
        my (@fields) = split("\t", $SFX_Previous{$PORTFOLIO_ID});
        $URL = $fields[30];
        $DateResolved = $fields[31];
        $DateAdded = $fields[32];
    }

    #print $OBJECT_ID . "\t" . $DateResolved . "\n";

    ###
    my $resolveCount = scalar keys %Resolve;

    ### If this is a new entry in the export file (i.e. an object recently enabled in SFX)
    ##  then set DateAdded to today, and keep track of the OBJECT_ID so we can fetch a URL for it later
    if ($SFX_Previous{$PORTFOLIO_ID} eq '') {
        print "NEW: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
        $DateAdded = $Today;
        $Resolve{$OBJECT_ID} = "X"; # Resolve using Object_ID
    }
    ### Ignore resolution of the URL if this Object or Target is on the IGNORE list as defined in the Config file
    ### Ignore takes precidence over Expire if both are set
    elsif (defined($Config{'IGNORE_ISSN'}{$ISSN}) || defined($Config{'IGNORE_TARGET'}{$TARGET_PUBLIC_NAME}) || defined($Config{'IGNORE_TARGET'}{$TARGET_ID}) || defined($Config{'IGNORE_OBJECT'}{$OBJECT_ID})) {
        print "IGNORE: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
    }
    ### Force resolution of the URL if this Object or Target is on the EXPIRE list as defined in the Config file
    elsif ($Config{'EXPIRE_ISSN'}{$ISSN} || $Config{'EXPIRE_TARGET'}{$TARGET_PUBLIC_NAME} || $Config{'EXPIRE_TARGET'}{$TARGET_ID} || $Config{'EXPIRE_OBJECT'}{$OBJECT_ID}) {
        print "FORCE: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
        $Resolve{$OBJECT_ID} = "X"; # Resolve using Object_ID
    }
    ### Check for unresolved URLs (objects that are not new, not being ignored or expired, but otherwise don't have a URL for some reason)
    elsif ($DateResolved eq '') {
        print "UNRESOLVED: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
        $Resolve{$OBJECT_ID} = "X"; # Resolve using Object_ID
    }
    ### Check if the entry is past the expiration date.
    ### If so, we should be safe and fetch a new URL for it
    elsif (Delta_Days(split("-", $DateResolved, 3), Today()) > $Config{'TTL'}) {
        print "EXPIRED: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
        #$Resolve{$OBJECT_ID}	= "X" if ($resolveCount < $Config{'MAX_LOOKUPS'});	# Resolve using Object_ID
        $Resolve{$OBJECT_ID} = "X"; # Resolve using Object_ID
    }
    ### If the data has changed in some way (coverage, title, whatever), resolve the URL again
    #elsif ( join("\t", (split("\t", $SFX_Previous{$PORTFOLIO_ID}))[0..27]) ne join("\t", $TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION) )
    ### Realistically, we should only need to geta new URL if the Coverage changes; we'll check a few fields for good measure
    elsif (join("\t", (split("\t", $SFX_Previous{$PORTFOLIO_ID}))[3, 4, 5, 7, 10, 18, 19, 23, 24, 28, 29]) ne join("\t", $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $eISSN, $LCCN, $TARGET_ID, $TARGET_SERVICE_ID, $ISBN, $eISBN, $OBJECT_TYPE, $AVAILABILITY)) {
        #print "CHANGED: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
        print "CHANGED: " . join("\t", (split("\t", $SFX_Previous{$PORTFOLIO_ID}))[3, 4, 5, 7, 10, 18, 19, 23, 24, 28, 29]) . "\n" if ($Config{'DEBUG_LEVEL'} > 1);
        print "     --> " . join("\t", $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $eISSN, $LCCN, $TARGET_ID, $TARGET_SERVICE_ID, $ISBN, $eISBN, $OBJECT_TYPE, $AVAILABILITY) . "\n" if ($Config{'DEBUG_LEVEL'} > 1);
        #$Resolve{$OBJECT_ID}	= "X" if ($resolveCount < $Config{'MAX_LOOKUPS'});	# Resolve using Object_ID
        $Resolve{$OBJECT_ID} = "X"; # Resolve using Object_ID
    }
    ### No need to resolve the URL for this object
    else {
        print "OK: $ISSN\t$OBJECT_ID\t$PORTFOLIO_ID\t$TARGET_PUBLIC_NAME\n" if ($Config{'DEBUG_LEVEL'} > 1);
    }

    # Clean up the threshold statement
    $THRESHOLD = FixThreshold($THRESHOLD);

    $SFX_Data{$PORTFOLIO_ID} = join("\t", $TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded);
}
close(CURRENT);
print "Done.\n" if ($Config{'DEBUG_LEVEL'} > 1);


### Before we spend a lot of time resolving URLs, let's see if we can create an output file
open(OUT, '>' . $CurrentFile . '.tmp') || die("Unable to open " . $CurrentFile . ".tmp for output: $!\n");


### OK, time to lookup ALL new, changed, and expired URLs (up to MAX_LOOKUP)
print "----------\nResolving new, changed, and expired URLs\n" if ($Config{'DEBUG_LEVEL'} > 1);
my $fetchResult = '';
my $count = 0;
foreach my $object_id (keys %Resolve) {
    ### Stop when we reach the MAX_LOOKUP value (assuming it is non-Zero)
    last if (($count > $Config{'MAX_LOOKUPS'}) && ($Config{'MAX_LOOKUPS'} > 0));
    $count++;

    print "$count Looking up OBJECT_ID $object_id\n" if ($Config{'DEBUG_LEVEL'} > 1);

    ### fetch a list of the matching targets and URLs for this Object ID
    $Resolve{$object_id} = FetchTargets($object_id);

    ### Pause a bit to give the SFX server a break
    usleep($Config{'SLEEP_TIME'});
}


### Update and spit out the new SFX data; output file should already be open
foreach my $pid (keys %SFX_Data) {
    my ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded) = split("\t", $SFX_Data{$pid});

    ## Not much to do if we are ignoring this target/object
    if (defined($Config{'IGNORE_ISSN'}{$ISSN}) || defined($Config{'IGNORE_TARGET'}{$TARGET_PUBLIC_NAME}) || defined($Config{'IGNORE_TARGET'}{$TARGET_ID}) || defined($Config{'IGNORE_OBJECT'}{$OBJECT_ID})) {
        print "$pid\tIgnored\n" if ($Config{'DEBUG_LEVEL'} > 1);
    }
    ## If a URL was resolved, update the output data
    elsif (defined($Resolve{$OBJECT_ID}) && $Resolve{$OBJECT_ID} ne "X") {
        print join("\t", $pid, $OBJECT_ID, $ISSN, $TARGET_PUBLIC_NAME) . "\n" if ($Config{'DEBUG_LEVEL'} > 1);
        my %URLs = ();
        my $fetchResult = $Resolve{$OBJECT_ID};
        my @targets = split /\x1e/, $fetchResult;
        foreach my $target (@targets) {
            my ($target_name, $url) = split /\x1d/, $target;
            print $target_name, "=", $url, "\n" if ($Config{'DEBUG_LEVEL'} > 2);
            $URLs{$target_name} = $url if ($url ne "");
        }

        my ($TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded) = split("\t", $SFX_Data{$pid});

        # Update DateResolved even if no URL found
        # Update URL even if SFX returns blank URL
        if ($fetchResult eq '') {
            $URL = '';
            print "$pid\tUpdated\n" if ($Config{'DEBUG_LEVEL'} > 1);
        }
        elsif (defined($URLs{$TARGET_PUBLIC_NAME})) {
            $URL = $URLs{$TARGET_PUBLIC_NAME};
            print "$pid\tUpdated\n" if ($Config{'DEBUG_LEVEL'} > 1);
        }
        else {
            print "$pid\tNo change\n" if ($Config{'DEBUG_LEVEL'} > 1);
        }
        $DateResolved = $Today;

        $SFX_Data{$pid} = join("\t", $TITLE_SORTABLE, $TITLE, $TITLE_NON_FILING_CHAR, $ISSN, $OBJECT_ID, $TARGET_PUBLIC_NAME, $THRESHOLD, $eISSN, $TITLE_ABBREV, $TARGET_SERVICE, $LCCN, $PORTFOLIO_ID, $MARC_856_u, $MARC_856_y, $MARC_856_a, $MARC_245_h, $THRESHOLD_LOCAL, $THRESHOLD_GLOBAL, $TARGET_ID, $TARGET_SERVICE_ID, $PORTFOLIO_ID2, $CATEGORIES, $LOCAL, $ISBN, $eISBN, $PUBLISHER, $PLACE_OF_PUBLICATION, $DATE_OF_PUBLICATION, $OBJECT_TYPE, $AVAILABILITY, $URL, $DateResolved, $DateAdded);
    }
    else {
        print "$pid\tNo change\n" if ($Config{'DEBUG_LEVEL'} > 1);
    }

    ### Write the obejct out to the file
    print OUT $SFX_Data{$pid} . "\n";
}
close(OUT);


### We should backup the current export file (copy it to the previous)
### then move the temp output file making it the current version

### copy the temp output file making it the new current file
if (!copy($Config{'DATA_DIR'} . '/sfx_data.txt.tmp', $Config{'DATA_DIR'} . '/sfx_data.txt')) {
    print "Failed to copy temporary output file: $!\n";
}
### Now remove the temporary file, and backup the newly resolved file
else {
    unlink($Config{'DATA_DIR'} . '/sfx_data.txt.tmp');
    copy($Config{'DATA_DIR'} . '/sfx_data.txt', $Config{'DATA_DIR'} . '/sfx_data.previous.txt')
}


# Done.
exit;



sub FetchTargets {
    my ($object_id) = @_;

    my %Hits = ();
    $fetchResult = "";

    ### Create the URL required as input for the SFX API
    my $content = 'url_ver=Z39.88-2004&url_ctx_fmt=infofi/fmt:kev:mtx:ctx&ctx_enc=info:ofi/enc:UTF-8&ctx_ver=Z39.88-2004&rfr_id=info:sid/sfxit.com:azlist&rft.object_id=' . $object_id . '&svc.fulltext=yes&sfx.ignore_date_threshold=1&sfx.response_type=simplexml';

    my $header = new HTTP::Headers(Accept => 'text/plain', UserAgent => 'megaBrowser/1.0');
    my $request = new HTTP::Request('POST', $Config{'SFX_SERVER'}, $header, $content);
    #my $request = new HTTP::Request('GET',$Config{'SFX_SERVER'}, $header, $content);
    my $userAgent = new LWP::UserAgent;
    $userAgent->agent($VERSION . ' (Darryl.Friesen@usask.ca; http://library.usask.ca/sfx-tools/)');
    my $response = $userAgent->request($request);

    if (($response->is_success) && ($response->content =~ m#^[\r\n\s\t]*\<\?xml#)) {
        my $content = $response->content;
        $content =~ s#^\s+##;
        print $content, "\n\n" if ($Config{'DEBUG_LEVEL'} > 2);

        my $parser = new XML::Parser::Expat;
        $parser->setHandlers('Start' => \&sh,
            'End'                    => \&eh,
            'Char'                   => \&ch);

        $parser->parse($content);
        print "Fetched: ", $fetchResult, "\n\n" if ($Config{'DEBUG_LEVEL'} > 1);

    }
    elsif ($Config{'DEBUG_LEVEL'} > 2) {
        print "ERROR: Query failed to return XML\n";
    }
    return $fetchResult;
}


sub sh {
    my ($p, $el, %atts) = @_;
}

sub eh {
    my ($p, $el) = @_;
    $fetchResult .= "\x1d" if ($el eq 'target_public_name');
    $fetchResult .= "\x1e" if ($el eq 'target_url');
}

sub ch {
    my ($p, $data) = @_;
    #   $fetchResult .= $data if ($p->current_element eq 'url');
    #   $fetchResult .= $data if ($p->current_element eq 'target_public_name');
    if ($p->current_element eq 'target_url') {
        print "FOUND url = " . $data . "\n" if ($Config{'DEBUG_LEVEL'} > 2);
        $fetchResult .= $data;
    }
    if ($p->current_element eq 'target_public_name') {
        print "FOUND target_public_name = " . $data . "\n" if ($Config{'DEBUG_LEVEL'} > 2);
        $fetchResult .= $data;
    }
}

sub FixThreshold {
    my ($Availability) = @_;

    $Availability = " " . $Availability;
    $Availability =~ s/Available/Availability:/g;
    $Availability =~ s/volume:/volume/g;
    $Availability =~ s/issue:/issue/g;
    $Availability =~ s/\s+$//;
    $Availability =~ s/\.$//;
    $Availability =~ s/\./<br>/g;
    $Availability =~ s/until/to/g;
    $Availability =~ s/Most/Availability: Most/g;

    $Availability =~ s/([1-9][0-9]) year\(s\)/$1 years/g;
    $Availability =~ s/([2-9]) year\(s\)/$1 years/g;
    $Availability =~ s/1 year\(s\)/1 year/g;
    $Availability =~ s/([1-9][0-9]) month\(s\)/$1 months/g;
    $Availability =~ s/([2-9]) month\(s\)/$1 months/g;
    $Availability =~ s/1 month\(s\)/1 month/g;

    $Availability =~ s/<br> Availability/<br>Availability/g;

    $Availability .= " " if ($Availability =~ m/Most/);

    return $Availability;
}

sub Usage {
    print <<EndOfusage;

Usage: sfx_resolve_urls.pl [--debug] [--config=/path/to/config.file] [--first-time]

       The --debug flag can be given multiple times to increase debugging level

EndOfusage
}
