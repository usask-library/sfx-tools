## Version 3.22 (April 2012)

- Changed `sfx-tools.pl` to use `Mail::Send` instead of `Mail::Sender` (`Mail::Send` is part of `MailTools` and can be
  easily installed via `yum` or `apt` on most Linux machines

## Version 3.21 (released August 22, 2008)
- Added `ENUMCAPTION1` and `ENUMCAPTION2` options to `sfx-tools.conf`.  These options control the label used in the ERM
  output file for Volume and Issue (the defaults are, as you would expect, "Volume" and "Issue")
  Thanks to Carol Ou (Colorado College) for the suggestion.
- Added `SFX_DATA_URL` options to `sfx-tools.conf`.  This option specifies the URL used to fetch the SFX export file,
  and is useful for institutions that export their ERM data to a server other than SFX, or whose SFX export file is
  named something other than `sfx_data.txt`
  Thanks to Bruce Schueneman (Texas A&M University-Kingsville) for the suggestion.

## Version 3.20 (released June 23, 2008)

- Rewrote a good deal of the code for most of the scripts, especially that relating to parsing command line options
  and the `sfx-tools.conf` file.
- Added several new options to the `sfx-tools.conf` config file
    - `EMAIL`, `DOWNLOAD_URL`, `ERM_INCLUDE_TYPE`, `ERM_EXCLUDE_TARGET`, `ERM_EXCLUDE_ISSN`, `ERM_EXCLUDE_OBJECT`,
       `ERM_COMPRESS`
- Added support for email notification when the process completes (`EMAIL`)
- Added an option to ZIP compress the resultant ERM input data (`ERM_COMPRESS`)
- Added support for the exclusion of Targets and individual Objects from the III import file
- Fixed some logic problems related to the determination of which URLs to resolve during subsequent runs of the script,
  improving the speed greatly
- Inclusion of the `sfx2ejdb.pl` script used by University of Saskatchewan to create their e-journal A-Z database.
- Revised the cron scripts for the SFX server which are used to automate the creation of the SFX export file

## Version 3.13 (released January 15, 2007)

- Fixed a bug in the `sfx_resolve_urls.pl` script related to parsing Institution data in the SFX export file
- It seems in some cases (error conditions) the SFX API does not return XML, but HTML.  This was causing problems with
  the XML parsing routines in `sfx_resolve_urls.pl`.  Added some extra checks to fix this situation.

## Version 3.12 (released mid-November 2006)

- Moved the UTF-8 to ISO-8859-1 conversion into the `sfx2erm.pl` script, eliminating the need for Python.
  The conversion is now done using the Perl Encode module, so Perl 5.8 may be required
- Added the `INCLUDE_EBOOKS` configuration option, which controls whether or not to process E-Books exported from the
  SFX server

## Version 3.11 (released early November 2006)

- Significant changes to both the documentation and the scripts themselves
- Configuration settings now reside in an external file (`sfx-tools.conf`) eliminating the need to modify any of the
  scripts
- The format of the cached `sfx_data.txt` file has been changed and now nearly matches that produced by the SFX export
  scripts
- Inclusion of the `upgrade_datafile.pl` script which will add the missing fields to an existing `sfx_data.txt` file
  (alternatively, the existing SFX export files can be removed so that the entire process begins fresh)
- `doSFX`, `doERM` and `doALL` shell scripts have been replaced by the `sfx-tools.pl` script.  Simply running this
  script will trigger the entire process.
- The individual Perl scripts accept command line arguments for things like the config file, debug level etc

## Version 3.10 (not officially released)

- Beginnings of the changes outlined in the version 3.11 above.
- Limited release for testing purposes only

## Version 3.00 (released May 1, 2006)

- Some documentation updates
- Changed version number to 3, keeping it in line with SFX's version number


## Version 2.10 (not released)

- Significant changes to `sfx_resolve_urls.pl` to support URL resolution for journals without ISSNs.  The SFX API is
  now queried (in a simpiler fashion that before) using the SFX Object ID instead of ISSN.

## Version 2.01 (released 2005-09-26)

 - Changed the name of the package to SFX-Tools
 - Minor modifications to the README
 
## Version 2.00 (released 2005-08-16)

- Upgrade to work with SFX V3. 
- Simplied `sfx_resolve_urls.pl`. SFX v2 generated URLs using a default year of 999 if no year was given which created
  broken URLs for a number of targets. SFX v3 no longer does this, so the code for correcting this problem has been
  removed.
- Changed the SFX API request to use `sfx.ignore_date_threshold` and `__service_type`.
- Added a script, `sfx_v3tov2.pl`, which converts data from the SFX V3 export tool into the SFX v2 format (easier than
  rewriting all our scripts to use the new format).
- Fixed bug with URLs not expiring correctly
- Added a `min_lookup` option so we can distribute lookups over the `TTL` period.
- Removed the `Examples/fetch_sfx_data.exp` script for fetching the SFX export data and replaced it with a cron script
  for the SFX server that allows the data available to be fetched via `WGET`.

## Version 1.02 (released 2005-06-28)

- Changed `SID` used in SFX API request from `ALEPH` to `sfx:e_collection` because of problems reported by Rochester
  Institute of Technology (Thanks to Jonathan Jiras and Damian Marinaccio)

## Version 1.01 (released 2005-05-16)

- Fixed typos in the README
- Added missing header to ERM import file produced by `sfx2erm.pl`
- New script `erm_split.pl` used to split ERM import file into smaller parts either by target, or a given number of
  records
- Added a section in README.txt for `erm_split.txt`

## Version 1.00 (released 2005-05-04)

- Initial limited release
