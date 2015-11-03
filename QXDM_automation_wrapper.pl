# This is a wrapper script which makes sure we have all the QXDM related files in the local terstbed console machine.
# When all the required files are there then this script will call QXDM_mem_stat_automation.pl 
# which in turn will first call LoadConfiguration.pl which will the WLAN em stat related configuration (memstat_config.dmc) on QXDM .
# Then QXDM_mem_stat_automation.pl will call memory_stats_report.pl to create HTML from txt files.

use Cwd 'abs_path';
use File::Basename qw( dirname );
use Getopt::Long;
my $si_name = undef;
my $build_variant = undef;
my $device_id = undef;
GetOptions(
	"si_name=s"    => \$si_name,
	"build_variant=s" => \$build_variant,
	"device_id=s" => \$device_id,
	);

if (!(defined($build_variant))) {
	$build_variant="AR6320_V3";
	}
	
if (!(defined($device_id || $si_name))){
	print "Argument list is wrong, use script like: perl QXDM_automation_wrapper.pl -si_name <Wallace_folder_name_of_your_SI> -build_variant <your_build_variant> -device_id <xxxxx>";
	exit 1;
	}

print "Creating path C:\\memory_stats\\Automation\\ if it doesnt exist \n";
my $memory_stats_directory = "C:\\memory_stats\\";	
unless(-e $memory_stats_directory or mkdir $memory_stats_directory) {
		die "Unable to create $memory_stats_directory \n";
}

my $automation_directory = "C:\\memory_stats\\Automation\\";	
unless(-e $automation_directory or mkdir $automation_directory) {
		die "Unable to create $automation_directory \n";
}

print "Changing direcory to C:\\Users\\Public\\Documents\\Qualcomm\\QXDM\\HTML \n";
chdir("C:\\Users\\Public\\Documents\\Qualcomm\\QXDM\\HTML\\") or die "cannot change: $!\n";
@wlan_window_config_files = qw/WLANMemStats.html WLANMemStats.js/;
foreach (@wlan_window_config_files)
{
    if (-e $_)
    {
        print "File '$_' Exists!\n";
    }
    else
    {
        print "File '$_' does not exist. QXDM will be killed and files will be copyied from wallace server now \n";
		system ("Taskkill /IM QXDM.exe /F");
		system ("cp \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\Memstats\\$_ C:\\Users\\Public\\Documents\\Qualcomm\\QXDM\\HTML\\$_");
    }
}

print "Changing direcory to C:\\memory_stats\\Automation \n";
chdir("C:\\memory_stats\\Automation\\") or die "cannot change: $!\n";

@automation_files = qw/QXDM_mem_stat_automation.pl memory_stats_report.pl LoadConfiguration.pl HelperFunctions.pm memstat_config.dmc/;
foreach (@automation_files)
{
    if (-e $_)
    {
        print "File '$_' Exists!\n";
    }
    else
    {
        print "File '$_' does not exist. Copying it from wallace server now \n";
		system ("cp \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\Memstats\\$_ C:\\memory_stats\\Automation\\$_");
    }
}
	
system("perl QXDM_mem_stat_automation.pl -si_name $si_name -build_variant $build_variant -device_id $device_id");