#!/usr/bin/perl
###
###  erm_split.pl - Split the ERM import file into smaller parts
###
###  Early versiosn of ERM had problems importing more than 4,000 or 5,000
###  records at a time.  This script splits the ERM import file into smaller
###  parts, either by SFX target, or by a fixed number of records.
###
###
###  Darryl Friesen (Darryl.Friesen@usask.ca)
###  University of Saskatchewan Library
###
###  Version 3.22
###

use strict;

use Getopt::Long;


my $VERSION = 'SFX-Tools/3.22 ERM File Splitter';


### Default config file is a file named 'sfx-tools.conf' located in the same directory as the scripts.
### We first need to find out what directory the scripts are being run from
use FindBin qw($Bin);
use lib "$Bin/../lib";

my $ConfigFile = $Bin . '/sfx-tools.conf';

###
### Get command line options
###
my $DEBUG  = 0;
my $Target = -1;
my $Count  = -1;

### Allowable command line arguments
my %options = (
    'config'   => \$ConfigFile,
    'target'   => \$Target,
    'count'    => \$Count,
    'debug'    => \$DEBUG
  );
GetOptions(\%options, 'config=s', 'target', 'count:5000', 'debug+');


###
###  Read config file
###
open(CONFIG, $ConfigFile) || die('Unable to open configuration file ' . $ConfigFile . ': ' . $! . "\n");

####
my %Config = (
    'DEBUG_LEVEL'       => 0,
    'ERM_SPLIT'         => 'NONE',
    'ERM_SPLIT_RECORDS' => 5000
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
### Command-line DEBUG value should override the one from the config file
$Config{'DEBUG_LEVEL'} = $DEBUG if ($DEBUG > 0);

print $VERSION . "\n" if ($Config{'DEBUG_LEVEL'});

if ($Target > 0) {
    $Config{'ERM_SPLIT'} = 'TARGET';
}
if ($Count > 0)
{
    $Count = 100 if ($Count < 100);
    $Config{'ERM_SPLIT'}         = 'RECORDS';
    $Config{'ERM_SPLIT_RECORDS'} = $Count;
}


#print '$Config{ERM_SPLIT}         = ' . $Config{'ERM_SPLIT'} . "\n";
#print '$Config{ERM_SPLIT_RECORDS} = ' . $Config{'ERM_SPLIT_RECORDS'} . "\n";

exit if ($Config{'ERM_SPLIT'} eq 'NONE');



### To keep the directory structure clean, we'll put all the split files
### into their own directory, erm_data.

### Make a directory for the data if it doesn't exist
if (! -e $Config{'DATA_DIR'} . '/erm_data')
{
    die("Failed to create the erm_data directory: !$\n") if (! mkdir('erm_data', 0775));
}

### Cleanup any old files
unlink glob($Config{'DATA_DIR'} . '/erm_data/*.txt');


### METHOD 1: Split file based on number of records;
if ($Config{'ERM_SPLIT'} eq 'RECORDS')
{
    my $file_num = 1;
    my $count    = 0;

    ### Open the erm_data.txt file
    open(IN, $Config{'DATA_DIR'} . '/erm_data.txt') || die("Unable to open " . $Config{'DATA_DIR'} . "/erm_data.txt file: $!\n");

    ### Open the first output file
    my $filename = $Config{'DATA_DIR'} . '/erm_data/erm.' . sprintf("%04d", $file_num) . '.txt';
    open(ERM, '>' . $filename) || die("Unable to open output file $filename: $!\n");

    my $first = 1;
    my $Header = '';
    while (<IN>)
    {
        ### Carry forward the header (on the first line) from the original file
        if ($first)
        {
            $first = 0;
            $Header = $_;
            print ERM $Header;
            next;
        }

        chomp;
        next if ($_ eq '');

        ### Increment our line/record counter
        $count++;

        ### If we pass the maximum record limit, close the current file and start a new one
        if ($count > $Config{'ERM_SPLIT_RECORDS'})
        {
            close(ERM);

            $count = 1;
            $file_num++;
            $filename = $Config{'DATA_DIR'} . '/erm_data/erm.' . sprintf("%04d", $file_num) . '.txt';
            open(ERM, '>' . $filename) || die("Unable to open output file $filename: $!\n");
            print ERM $Header;
        }

        ### Write the record to the output file
        print ERM $_ . "\n";
    }
    ### close the 2 open files
    close(ERM);
    close(IN);
}


### METHOD 2: Split file based on SFX target
###
###   This is a slightly more complicated method as the entire input file
###   must be read in, sorted by target, then dumped out.
if ($Config{'ERM_SPLIT'} eq 'TARGET')
{
    my %erm_data;

    ### Open the erm_data.txt file
    open(IN, $Config{'DATA_DIR'} . '/erm_data.txt') || die("Unable to open " . $Config{'DATA_DIR'} . "/erm_data.txt file: $!\n");

    ### Read the entire file into an associative array using target (and record counter) as the key
    my $first = 1;
    my $i = 0;
    my $Header = '';
    while (<IN>)
    {
        ### Carry forward the header (on the first line) from the original file
        if ($first)
        {
            $first = 0;
            $Header = $_;
            next;
        }

        chomp;
        next if ($_ eq '');

        ### split the line
        my(@elements) = split(/\|/);

        ### Increment our line/record counter
        $i++;

        ### add the data to our associative array (SFX target is the 6th element)
        my $key = $elements[5];
        $key =~ s#[\(\)\[\]:'"\.]##g;
        $key =~ s#[\s\@\\\/]#_#g;
        $key .= '::' . sprintf("%05d", $i);

        $erm_data{$key} = $_;
    }
    close(IN);

    ### Sort the data by Target and write each target to a file
    my $target = '';
    my $file_open = 0;
    foreach my $key (sort keys(%erm_data))
    {
        my($t, $i) = split(/::/, $key);

        ### Open a new output file when we encounter a different target
        if ($t ne $target)
        {
            ### Close the previous target's output file first (if it is open)
            if ($file_open)
            {
                close(ERM);
                $file_open = 0;
            }

            $target = $t;
            my $filename = $Config{'DATA_DIR'} . '/erm_data/erm.' . $target . '.txt';
            open(ERM, '>' . $filename) || die("Unable to open output file $filename: $!\n");
            print ERM $Header;
            $file_open = 1;
        }

        ### Write the record to the output file
        print ERM $erm_data{$key} . "\n";
    }
    close(ERM) if ($file_open);
}

