#!/usr/bin/perl
# --------------------------------------------------------------------------
#
#  sfx-tools.pl - Control program for the individual SFX Tools components
#
#  Darryl Friesen (Darryl.Friesen@usask.ca)
#  University of Saskatchewan Library
#
#  Version 3.22
#
# --------------------------------------------------------------------------

use strict;

use Getopt::Long;
use File::Copy;


my $VERSION = 'SFX-Tools/3.22';


# --------------------------------------------------------------------------
#
# Default config file is 'sfx-tools.conf' located in the same directory as
# this script.
# First, determine the directory where this script lives
#
# --------------------------------------------------------------------------
use FindBin qw($Bin);
use lib "$Bin/../lib";

my $ConfigFile = $Bin . '/sfx-tools.conf';


# --------------------------------------------------------------------------
#
# Get command line options
#
# --------------------------------------------------------------------------
my $DEBUG           = 0;	# Debugging level
my $FetchExportFile = 1;	# Fetch remote SFX export file via HTTP
my $ResolveURLs     = 1;	# Resolve journal level URLs for SFX export
my $ERM_Convert     = 1;	# Convert SFX export into ERM format
my $ERM_Split       = 1;	# Convert SFX export into ERM format
my $EJDB            = 0;	# Convert SFX export into format suitable for an ejournal listing database
my $SendMail        = 1;	# Sends mail for notification of completed conversion

# Allowable command line arguments
my %options = (
    'config'     => \$ConfigFile,
    'fetch'      => \$FetchExportFile,
    'resolve'    => \$ResolveURLs,
    'erm'        => \$ERM_Convert,
    'erm_split'  => \$ERM_Split,
    'ejdb'       => \$EJDB,
    'debug'      => \$DEBUG
  );
GetOptions(\%options, 'config=s', 'fetch!', 'resolve!', 'erm!', 'erm_split!', 'ejdb!', 'debug+');


# --------------------------------------------------------------------------
#
#  Read the config file
#
# --------------------------------------------------------------------------
open(CONFIG, $ConfigFile) || die('Unable to open configuration file ' . $ConfigFile . ': ' . $! . "\n");

my %Config = (
    'DEBUG_LEVEL' => 0,
  );
while (<CONFIG>) {
   chomp;                  # no newline
   s/#.*//;                # no comments
   s/^\s+//;               # no leading white
   s/\s+$//;               # no trailing white
   next unless length;     # anything left?
   my ($var, $value) = split(/\s*=\s*/, $_, 2);
   $Config{uc($var)} = $value;
}
# Command-line DEBUG value should override the one from the config file (if present)
$Config{'DEBUG_LEVEL'} = $DEBUG if ($DEBUG > 0);


print $VERSION . "\n" if ($Config{'DEBUG_LEVEL'});


# --------------------------------------------------------------------------
#
# STEP 1: Get a copy of the SFX export file
#
#   The SFX_EXPORT config value defines how this works.
#   If it is 'MANUAL' we assume the export was done manually and the
#     resultant file (sfx_data.txt) was placed in the DATA_DIR
#   If it is 'GET' we assume the export was done using a cron script on the
#     SFX server, and that we can issue a GET request to get the file
#
# --------------------------------------------------------------------------

if ((uc($Config{'SFX_EXPORT'}) eq 'GET') && $FetchExportFile)
{
  use LWP::UserAgent;
	
  my $ua = LWP::UserAgent->new;
  $ua->agent($VERSION . ' (University of Saskatchewan Library; http://library.usask.ca/sfx-tools/)');

  my $sfx_data_url = $Config{'SFX_SERVER'} . '/cgi/public/get_file.cgi?file=sfx_data.txt';
  $sfx_data_url = $Config{'SFX_DATA_URL'} if ($Config{'SFX_DATA_URL'} ne '');

  my $req = HTTP::Request->new(GET => $sfx_data_url);
  my $res = $ua->request($req);

  print "Attempting to fetch " . $sfx_data_url . "\n" if ($Config{'DEBUG_LEVEL'});

  # The SFX Server returns a "200 OK" message even if the file we requested does not exist
  # (technically the CGI script did in fact run, so a 200 code does make sense -- sort of)
  # We need to do a bit more checking by hand.  If it's OK, save the file locally
  die("The following error occured while attempting to fetch the SFX export file from the remote server:\n   " . $res->content . "\n") if ($res->content =~ /^\s*ERROR/);

  # We're OK.  Save the file
  open(SFX, '>' . $Config{'DATA_DIR'} . '/sfx_data.txt') || die("ERROR: Failed to save the SFX export file: $!\n");
  print SFX $res->content;
  close(SFX);
}


# --------------------------------------------------------------------------
#
# STEP 2: Resolve journal level URLs for all the object portfolios exported
#         from SFX
#
# --------------------------------------------------------------------------

# Check for the existence of the current SFX export file (sfx_data.txt) as
# well as the previous export (sfx_data.previous.txt) which contains the
# previously cached URLs

die("ERROR: SFX export file does not exist: " . $Config{'DATA_DIR'} . "/sfx_data.txt\n") if (! -e $Config{'DATA_DIR'} . '/sfx_data.txt');

if ($ResolveURLs) {
  my $first_time = 0;
  $first_time = 1 if (! -e $Config{'DATA_DIR'} . '/sfx_data.previous.txt');

  # Call the URL resolution script; make sure it gets the same config file as this script did
  my @args = ($Bin . '/sfx_resolve_urls.pl', '--config=' . $ConfigFile );
  system(@args);
}

 
# --------------------------------------------------------------------------
#
# STEP 3: Convert the newly resolved SFX data into a format suitable for
#         import by ERM
#
# --------------------------------------------------------------------------

if ($ERM_Convert)
{
  # Call the ERM conversion script; make sure it gets the same config file as this script did
  my @args = ($Bin . '/sfx2erm.pl', '--config=' . $ConfigFile );
  system(@args);
}


# --------------------------------------------------------------------------
#
# STEP 4: Split the ERM import file into smaller parts
#
# --------------------------------------------------------------------------

if ($ERM_Split)
{
  # Call the ERM split script; make sure it gets the same config file as this script did
  my @args = ($Bin . '/erm_split.pl', '--config=' . $ConfigFile );
  system(@args);
}


# --------------------------------------------------------------------------
#
# STEP 5: Compress the ERM data files for download
#
# --------------------------------------------------------------------------

if ( (uc($Config{'ERM_COMPRESS'}) eq 'TRUE') || (uc($Config{'ERM_COMPRESS'}) eq 'YES')) {
  use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

  my $zip = Archive::Zip->new();

  # Add the erm_data.txt file to the ZIP
  if (-e $Config{'DATA_DIR'} . '/erm_data.txt') {
    my $file_member = $zip->addFile( $Config{'DATA_DIR'} . '/erm_data.txt', 'erm_data.txt' );
  }

  # If the ERM file was split into smaller files, include the directory containing those
  if ((($Config{'ERM_SPLIT'} eq 'TARGET') || ($Config{'ERM_SPLIT'} eq 'RECORDS')) && (-d $Config{'DATA_DIR'} . '/erm_data')) {
    my $dir_member = $zip->addTree( $Config{'DATA_DIR'} . '/erm_data', 'erm_data' );
  }

  # Save the Zip file
  unless ( $zip->writeToFileNamed($Config{'DATA_DIR'} . '/ERM_ready_file.zip') == AZ_OK ) {
    die 'Failed to create ERM_ready_file.zip';
  }
}


# --------------------------------------------------------------------------
#
# STEP 6: Convert the newly resolved SFX data into a format suitable for
#         import into an ejournal database
#
# --------------------------------------------------------------------------
if ($EJDB)
{
  # Call the EJDB conversion script; make sure it gets the same config file as this script did
  my @args = ($Bin . '/sfx2ejdb.pl', '--config=' . $ConfigFile );
  system(@args);
}


# --------------------------------------------------------------------------
#
# STEP 7: Send out an email notification informing the specified user that
#         the entire process has completed
#
# --------------------------------------------------------------------------
if ($SendMail && ($Config{'EMAIL'} ne '')) {
  require Mail::Send;

  my $msg = new Mail::Send;

  $msg->to($Config{'EMAIL'});
  $msg->add('From', 'SaskScript/SFX-Tools ERM Processor <notification@saskscript.usask.ca>');
  $msg->subject('SFX to ERM conversion process completed');

  # Construct a meaningful message body
  my $body = "The SFX to ERM conversion process has completed.  ";

  if ($Config{'DOWNLOAD_URL'} ne '') {
    $body .= "You can download the complete import file using the URL given below.  ";

    if ( (uc($Config{'ERM_COMPRESS'}) eq 'TRUE') || (uc($Config{'ERM_COMPRESS'}) eq 'YES')) {
      $body .= "The file has been compressed to make the download smaller, and will need to be uncompressed (using your favorite ZIP compression utility) before it can be imported into ERM.\n\n";
      $body .= $Config{'DOWNLOAD_URL'} . "/ERM_ready_file.zip\n\n";
    }
    else {
      $body .= "You may need to use your browsers 'Save As' feature and save the file to your local computer.\n\n";
      $body .= $Config{'DOWNLOAD_URL'} . "/erm_data.txt\n\n";
      if ($ERM_Split && ((uc($Config{'ERM_SPLIT'}) eq 'TARGET') || (uc($Config{'ERM_SPLIT'}) eq 'RECORDS'))) {
        $body .= "The ERM import file has been also split into smaller parts, each of which is available using the URL below:\n\n";
        $body .= $Config{'DOWNLOAD_URL'} . "/erm_data/\n\n";
      }
    }
  }

  $body .= "\nThanks for using Sask::Script.\n\n\n";
  $body .= 'If you have any questions or concerns, please feel free to join the Sask::Script mailing list, or contact the project administrator, Darryl Friesen (Darryl.Friesen@usask.ca) directly.  More information can be found on the Sask::Script website: http://saskscript.usask.ca/' . "\n";

  my $fh = $msg->open;
  print $fh $body;
  $fh->close or die "Couldn't send email message: $!\n";

}
