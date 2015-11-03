#!/usr/bin/perl -w

############################################################
# This file takes the CR number from user input
# Then runs the prism API to fetch all the info in the CR.
# Stores the Prism output in a text file (prism_out.txt)
# Then Parses the text file for the relevant CR info.
############################################################
#---------------------------------------------------------
# $Id: //depot/software/swbuild/bin/defect_tracking/CR_Gerrit_relation.pl#24 $
# $DateTime: 2015/08/27 11:38:08 $
# $Author: abishnoi $
#---------------------------------------------------------

use Data::Dumper;
use Term::ReadKey;
use File::Basename;
use Getopt::Long;

my $compare;
my $script = basename($0);
my $dir    = dirname($0);
my $OK     = 0;
my $ERROR  = 1;

my $ReleaseBranch;  # Release Branch name - currently only LA branches
my @crs;            # List of CRs
my $Output;         # Output report generated
my $PrismOut;       # Intermediate prism output file
my $SoftwareImage;  # PL or SI Image name to query for
my $Help;           # Show help
my $Summary;        # Show brief output

my $status = GetOptions(
    "branch=s"       => \$ReleaseBranch,  # ReleaseBranch
    "crs=s"          => \@crs,            # List of CRs to search
    "out=s"          => \$Output,         # Output filename
    "PL_Name=s"      => \$SoftwareImage,  # Software Image/Product Line
    "report=s"       => \$Output,         # Output filename
    "SI_Image=s"     => \$SoftwareImage,  # Software Image/Product Line
    "summary"        => \$Summary,        # Show summary/brief text
    "help"           => \$Help,           # Help Text
);

$SoftwareImage = "LNX.LE.0.0"    unless ($SoftwareImage);
#disabled# $ReleaseBranch = "master"        unless ($ReleaseBranch);
$Output        = "CR_REPORT.TXT" unless ($Output);
$CrInfo        = "CR_INFO.CSV"   unless ($CrInfo);
$PrismOut      = "PRISM_OUT.TXT" unless ($PrismOut);

#678313,LNX.LA.3.6.1,Fix,01.03.06.058,790505;status:NEW;branch:LNX.LA.3.6;project:platform/vendor/qcom-proprietary/wlan;;,
#677730,LNX.LA.3.6.1,Analysis,,Fix,01.03.06.059,790632;status:NEW;branch:LNX.LA.3.6;project:platform/vendor/qcom-proprietary/wlan;;,

# Remove white-space to use new CRs
my @new_crs = ();
foreach my $cr (@crs)
{
   if ($cr =~ /\s+/)
   {
      push(@new_crs, split(/\s+/,$cr));
   }
   else
   {
      push(@new_crs, $cr);
   }
}

@crs = @new_crs;

sub showUsage
{
	print "Usage:\n";
	print " $script \\\n";
	print "    -report report_path_name (default:$Output) \\\n";
	print "    -pl_name product-line-name (default: $SoftwareImage) \\\n";
	print "    -si_name product-line-name (synonym for above) \\\n";
	print "    -crs 'list-of-crs' \\\n";
	print "    -summary show brief output\\\n";
	print "    -branch release-branch (for LA, default: $ReleaseBranch) \\\n";
	print "\n";
	print "Example:\n";
	print "\$ $script -report su57-report.txt -pl LNX.LA.0.0 \\\n";
	print "   -branch master -crs '12345 639092 610919' \\\n";
	exit($OK);
}

if (!@crs)
{
	print "ERROR: List of CRs is not specified\n";
	&showUsage;
	exit($ERROR);
}

print "INFO: Running script : $script\n";
print "INFO: Script Dir     : $dir\n";
print "INFO: CRs to Scan    : @crs\n";

print "\nPlease enter password for the user 'qcabuildsw' user account:\n";
#my $password = '';
ReadMode('noecho');
my $password = ReadLine(0);
chomp $password;
ReadMode(0); # back to normal 

# Here we are cleaning the previous output written in this doc file, so that everytime 
# we run the command, the relevant_output is clean (no appending).
open (OUTFILE, ">$Output") or die "Can not open the relevant_output.doc file, closed before you run the script.\n";
open (CRINFO, ">$CrInfo") or die "Can not open the CR_Info.txt file, Close it before you run the script.\n";

# Here we are allowing multiple CRs to be given as input to this script.
foreach my $arg (@crs){
              #print "arg = ", $arg; 
              print "\n";
              GET_CR_DETAILS($arg, $password);
              print "\n";
              print CRINFO "\n";
             
}

#658130,LNX.LA.3.6.1,Fix,
#https://review-android.quicinc.com/772465,  status: NEW 
#, qcacld-new,  project: platform/vendor/qcom-proprietary/wlan
#,

############################################
sub GET_CR_DETAILS{
       
       my $cr = shift;
       my $password = shift;

       ##print "CRS = $cr pwd = $password";
       #print $cr, $password;

       # Here we are passing the CR number and the password to the API  
       if ( -s "${dir}/prism_api.pl" )
       {
           `perl ${dir}/prism_api.pl $cr $password > $PrismOut 2>&1`;
       }
       else
       {
           print "\nERROR: Required script ${dir}/prism_api.pl is missing\n";
           exit($ERROR);
       }
     
       my $Title;
       my $Status;
       my $SubSystem;
       my $Area;
       my $SoftwareImageName;
       my $ComponentToChange;
       my $OverallCrPriority;
       my $CodeChangeUrl;
       my $loi;
       my $gerrit_text = '';
       my @gerrit;
       my $RCACode;
       my $ReleaseNotesStatus;
       my $IsDevelopmentComplete;
       
       # local $/ = undef to read the whole file as a single string variable. 
       local $/ = undef;
       
       # Here the script is reading the dump logs so that it can parse it.
       open (MYFILE, "<${PrismOut}") or die "Can not open the input file $!\n";
       
       # Here creating a filehandle so that we can write the relevant output in a external file.
       open (OUTFILE, ">>$Output") or die "Can not open the relevant_output.doc file, please make sure it is closed before you run the script. \n";
       

       print "-----------------------------------------------\n";
       print "** CR $cr; SI - $SoftwareImage\n";
       print OUTFILE "-----------------------------------------------\n";
       print OUTFILE "** CR $cr; SI - $SoftwareImage\n";
       print CRINFO "$cr,$SoftwareImage,";

       # Here we are reading the whole file as a variable string.       
       my $line = <MYFILE>;
       #print $line;
       # 401 - Unauthorized: Access is denied due to invalid credentials
       if ($line =~ /Access\s+is\s+denied\s+due\s+to\s+invalid\s+credentials/)
       {
          print "ERROR: Prism access is denied.\n";
          print "ERROR: Please check credentials or perl version\n";
          exit($ERROR);
       }
       
       if (!$Summary)
       {
          if($line =~ /<a:Title>(.*?)<\/a:Title>.*<a:Title>(.*?)<\/a:Title>/si)
          {
             $Title = $2;                            # $2 is the second title. $1 is for the first title.
             print OUTFILE "Title: $Title \n";
             print "Title: $Title \n";
          }
       
          if($line =~ /<a:OverallCrPriority>(.*?)<\/a:OverallCrPriority>/sig)
          {
             $OverallCrPriority = $1;
             print OUTFILE "CR Priority: $OverallCrPriority \n";
             print "CR Priority: $OverallCrPriority \n";
          }
       
          if($line =~ /<a:ReleaseNotesStatus>(.*?)<\/a:ReleaseNotesStatus>/sig){
              $ReleaseNotesStatus = $1;
                     if ($ReleaseNotesStatus eq 'Update')
                            {
                            print "Release Notes Status: ERROR - This CR cant be moved to Ready. Release Notes Status should not be 'UPDATE' \n";
                            }
                     else   {
                            print OUTFILE "Release Notes Status: $ReleaseNotesStatus \n";
                            print "Release Notes Status: $ReleaseNotesStatus \n";
                            }
              }
          if($line =~ /<a:RCACode>(.*?)<\/a:RCACode>/sig)
          {
              $RCACode = $1;
              print OUTFILE "RCA Code: $RCACode \n";
              print "RCA Code: $RCACode \n";
          }
          
          if($line =~ /<a:Area>(.*?)<\/a:Area>/sig)
          {
             $Area = $1;
             print OUTFILE "Area: $Area \n";
             print "Area: $Area \n";
          }
       
          if($line =~ /<a:SubSystem>(.*?)<\/a:SubSystem>/sig)
          {
             $SubSystem = $1;
             print OUTFILE "Subsystem: $SubSystem \n";
             print "Subsystem: $SubSystem \n";
          }
       } # Summary
       
       # This parses the text file for the line which has Software Image APSS.LA.0.0
       while ($line =~ /<a:SoftwareImageName>$SoftwareImage<\/a:SoftwareImageName>(.*?)<a:TargetName>/sg) {
              $gerrit_text = $1;

              if($gerrit_text =~ /<a:IsDevelopmentComplete>(.*?)<\/a:IsDevelopmentComplete>/sig){
                     $IsDevelopmentComplete = $1;
                     if ($IsDevelopmentComplete eq 'False') {
                            print " Dev Complete Status: ERROR - The Dev Complete Status is FALSE, needs to be true"
                     }
                     else {
                     print OUTFILE "Dev Complete: $IsDevelopmentComplete \n";
                     print "Dev Complete: $IsDevelopmentComplete \n";
                     }
              }
              
              if ($gerrit_text =~ /<a:Status>(.*)<\/a:Status>/sg)
              {
                     if ($1 eq 'NotApplicable') {
                            next;
                     }
                     else
                     {
                            print OUTFILE "Status of Image $SoftwareImage = $1 \n\n";
                            print CRINFO "$1,";
                            print "Status of Image $SoftwareImage = $1 \n\n";
                     }
              }
              
              my @ccus = split("<a:CodeChangeUrl>", $gerrit_text);  # This splits the gerrit_text output for all gerrits.
              my %gerrits=();
              foreach my $ccu (@ccus)
              {
       
                     $ccu =~ s/<\/a:CodeChangeUrl>.*//sg;
                     if ($ccu =~ /https/i)
                     {
                           print  "Gerrit = $ccu\n";
                     }
                     if($ccu =~  /review-android.quicinc(.*?)\/(\d{6,10})/sg)
                     {
                            my $gerrit = $2;
                            my $status = qx(ssh -p 29418 review-android.quicinc.com gerrit query $gerrit | egrep \"status:\");
                            my $branch = qx(ssh -p 29418 review-android.quicinc.com gerrit query $gerrit | egrep \"branch:\");
                            chomp($status);
                            chomp($branch);
                            $branch =~ s/\s+//g;
                            $status =~ s/\s+//g;
                            $gerrits{$gerrit}{branch} = $branch;
                            $gerrits{$gerrit}{status} = $status;

                            if ($ReleaseBranch) {
                                   next unless ($branch=~/branch.*$ReleaseBranch/);
                            }
                            print " Gerrit: $ccu $status ";
                            print OUTFILE " Gerrit = $ccu $status ";
                            
                            my $Host_Type = "ssh -p 29418 review-android.quicinc.com gerrit query $gerrit --files --current-patch-set --commit-message";
                            my @host_output = `$Host_Type`; chomp(@host_output);
                            foreach my $host (@host_output)
                            {
                                   if ($host =~ /COMMIT_MSG(.*?)file:(.*?)\//s)
                                   {
                                          print "LA Host Type: $2       ";
                                          print OUTFILE "LA Host type: $2      ";
                            		  $gerrits{$gerrit}{host_type} = $2;
                                   } # ending if statement
                                   
                            } # ending upper foreach loop
                            my $lastUpdated= qx(ssh -p 29418 review-android.quicinc.com gerrit query $gerrit | egrep \"lastUpdated:\");
                            chomp($lastUpdated);
                            print " $lastUpdated ";
                            print OUTFILE " $lastUpdated ";
                                
                            my $project= qx(ssh -p 29418 review-android.quicinc.com gerrit query $gerrit | egrep \"project:\");
                            chomp($project);
                            $project =~ s/\s+//g;
                            $gerrits{$gerrit}{project} = $project;
                            print "$project \n";
                            print OUTFILE "$project \n";

                            my ($sunumber,$suprogress,$sureleased) = ();
                            my (@suReleaseInfo) = ();
                            my $suRelease= "ssh -p 29418 review-android.quicinc.com gerrit query $gerrit --comments | egrep \"SU_BUILD\"";
                            my ($suReleaseInfo) = qx($suRelease);

                            chomp($suReleaseInfo);

                            (@suReleaseInfo) = split(/\s+|\;/,$suReleaseInfo);

                            foreach my $suinfo (@suReleaseInfo)
                            {
                                next unless ($suinfo =~ /SU_WCONNECT|SU_BUILD|\d{1,2}\.\d{1,2}\.\d{1,2}\.\d{1,3}/);

                                if ($suinfo =~ /(SU_BUILD_IN_PROGRESS)/)
                                {
                                   $key = "SU_BUILD_IN_PROGRESS"; next;
                                }
                                if ($suinfo =~ /(INCLUDED_IN_SU_BUILD)/)
                                {
                                   $key = "INCLUDED_IN_SU_BUILD"; next;
                                }
                                if ($suinfo =~ /(\d{1,2}\.\d{1,2}\.\d{1,2}\.\d{1,3})/)
                                {
                                   $sunumber = $1;
                                   print " $key: $sunumber \n";
                                   print OUTFILE " $key: $sunumber \n";
                                   $gerrits{$gerrit}{suinfo} = $sunumber;
                                   print "CRINFO $key : $sunumber\n";
                                   print CRINFO "$sunumber,";
                                }

                            } # end of @suReleaseInfo
                            
                     }  # end of codechangeurl condition
              }   # end of gerrits
              foreach my $gerrit (keys %gerrits)
              {
                   my $tmp;

                   print CRINFO "$gerrit;";

                   $tmp = "$gerrits{$gerrit}{status};";
                   $tmp =~ s/status://g;
                   print CRINFO "$tmp;";

                   $tmp = "$gerrits{$gerrit}{branch};";
                   $tmp =~ s/branch://g;
                   print CRINFO "$tmp;";

                   $tmp = "$gerrits{$gerrit}{project};";
                   $tmp =~ s/project://g;
                   print CRINFO "$tmp;";

                   print CRINFO "$gerrits{$gerrit}{sunumber};";
              }
              print CRINFO ",";
       }  # ending the while loop

       print "\n";
       print OUTFILE "\n";
       close (MYFILE); 
       close (OUTFILE);
};  # ending the function definition


