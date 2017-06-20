#!/exlibris/sfx_ver/sfx4_1/app/perl/bin/perl
###
###  sfx_export.pl - Export active SFX journal data
###
###  Darryl Friesen (Darryl.Friesen@usask.ca)
###  University of Saskatchewan Library
###
###  Version 3.22
###

use strict;
use File::Basename;
use File::Copy;

my $base_dir     = $ENV{SFXCTRL_HOME};
my $script_dir   = $ENV{SFXCTRL_HOME} . '/admin/kbtools';
my $export_dir   = $ENV{SFXCTRL_HOME} . '/export';

my $params = "@ARGV";
   $params =~ s/'/\\'/g;


$params = '--mode=manual --format=TXT --service=getFullTxt --object_type JOURNAL --object_type BOOK --filename=' . $export_dir . '/sfx_data.txt';

unlink($export_dir . '/sfx_data.txt');
system("tcsh -c 'source $base_dir/home/.cshrc; $script_dir/export.pl $params'");

