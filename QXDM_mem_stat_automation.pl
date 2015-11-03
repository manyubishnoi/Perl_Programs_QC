# This script extracts memory statistics from each build. 
# First we will find the dynamic memory and then we will print it on an HTML file. 
# Static memory is already displayed by Jenkins using '-z' option and will be printed on the HTML as well.

# Make sure your computer has access to \\wallace\ path.

#Usage: "perl QXDM_automation_wrapper.pl -si_name <Wallace_folder_name_of_your_SI> -build_variant <your_build_variant> -device_id <xxxxx>"
#Default build variant is AR6320_V3

use Getopt::Long;
use File::Slurp;
use Win32::OLE;
use Win32::GUI();
use File::Spec;
use Cwd 'abs_path';
use Win32::OLE::Variant;
use Cwd;
use Term::ReadKey;
use Win32::GuiTest qw(:ALL);

GetOptions(
	"si_name=s"    => \$si_name,
	"build_variant=s" => \$build_variant,
	"device_id=s" => \$device_id,
	);

print "si_name is $si_name \n";
print "build_variant is $build_variant \n";
print "device_id is $device_id \n";

my $dir = "\\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\";
print "$dir \n";
my $file;
my @files = read_dir($dir);
@files = sort {$a le $b} @files;
foreach $file(@files) {
print "$file ,\n";
}
my $latest_su=shift @files;		
print "\nMemstats for SU number: $latest_su :\n";

my $su_name = $latest_su;
chop $su_name;

#Changing directory to C:\\memory_stats\\Automation\\, 
#All testbesd should have the QXDM_mem_stat_automation.pl file in this location for this testcase to run. 

#system("dir");
chdir("C:\\memory_stats\\Automation\\") or die "cannot change: $!\n";
print "Changed working directory is: ";
print(cwd);
#print "\nHere is the list of all the sub directories in this folder: \n";
#system("dir");

print "\nStarting QXDM application and loading memstat_config.dmc configuration file in QXDM \n";
system($^X, "LoadConfiguration.pl");

my @windows = FindWindowLike(0, "^QXDM(.*?)");
die "Can not find the Main QXDM window.\n"
unless @windows;
print "Checking if the main QXDM window is open and print its ID and the name below \n";
print "$windows[0]>\t'", GetWindowText(@windows[0]), "'\n";

my $delay = 2;
my @WLAN_memStat_window = FindWindowLike(0, "^WLAN Memory(.*?)");
die "QXDM should be running before running this event.\n"
unless @WLAN_memStat_window;
print "Checking if the WLAN Memory Stat sub window of QXDM is open and print its ID and name below \n";
print "$WLAN_memStat_window[0]>\t'", GetWindowText($WLAN_memStat_window[0]), "'\n";

push_button("^WLAN");
# SendMouse("{LeftClick}");
# SendKeys ("{TAB}{SPC}");

#Calculating the middle of the QXDM window so that we can click on it and then do other tasks like clicking Browse button etc.
#click_on_the_middle_of_window("@WLAN_memStat_window[0]");
my ( $left, $top, $right, $bottom ) = GetWindowRect(@WLAN_memStat_window[0]);
MouseMoveAbsPix( ( $right + $left ) / 2,  ( $top + $bottom ) / 2);
SendMouse("{LeftClick}");
sleep(1);
SendKeys ("{TAB}{TAB}{TAB}{TAB}{SPC}");
sleep(8);

my @browse_json = FindWindowLike(0, "^Choose(.*?)");
die "Can not open the browse window. \n"
unless @browse_json;
print "QXDM is trying to load the memstats JSON file using the Browse button, \n";
print "$browse_json[0]>\t'", GetWindowText(@browse_json[0]), "'\n\n";
sleep(1);

my $json_wallace_path="\\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\bin\\memstats_map.json";
SendKeys($json_wallace_path);
SendKeys ("{ENTER}");

#provide_network_path_of_json (@upload_json[0]);
sleep(2);

system("adb -s $device_id shell svc wifi enable");
sleep(5);

system("adb -s $device_id shell cnss_diag -q &");
system("adb -s $device_id shell ps |grep cnss_diag");
sleep(2);
system("adb -s $device_id shell iwpriv wlan0 setUnitTestCmd 0 1 0");
sleep(40);

SendKeys("{TAB}{TAB}{SPC}");
sleep(6);

my $su_directory = "C:\\memory_stats\\$latest_su\\";	
unless(-e $su_directory or mkdir $su_directory) {
		die "Unable to create $su_directory \n";
}

my $variant_directory = "C:\\memory_stats\\$latest_su\\$build_variant\\";	
unless(-e $variant_directory or mkdir $variant_directory) {
		die "Unable to create $build_directory \n";
}

chdir ("$variant_directory");
print "Current dir has files: \n";
system(dir);

if (-e "$variant_directory\\memstats.txt") {
    print "File $variant_directory\\memstats.txt exists, this will be renamed as memstats_old.txt and the new one will be created here.\n";
	unlink ("memstats_old.txt");
	rename ("memstats.txt", "memstats_old.txt");
	unlink ("memstats.txt");
}
else {
        print "File '$_' does not exist, it will be created now by QXDM. \n";
    }

#my $export_to_csv="C:\\memory_stats\\$latest_su\\$build_variant";

SendKeys($variant_directory);
SendKeys("{ENTER}{TAB}{ENTER}");
sleep(1);
#Confirming to save in case the same file already exists.
# SendKeys("{TAB}");
# sleep(1);
# SendKeys("{ENTER}");
sleep(5);

print "Please wait for few seconds, copying all the relevant files to C:\\memory_stats\\$latest_su\\$build_variant \n";
#system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\memstats.txt C:\\memory_stats\\$latest_su\\memstats.txt");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\bin\\memstats_map.json C:\\memory_stats\\$latest_su\\$build_variant\\memstats_map.json");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\image\\athwlan_mem_stats_detailed.txt C:\\memory_stats\\$latest_su\\$build_variant\\athwlan_mem_stats_detailed.txt");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\image\\athwlan_mem_stats_summary.txt C:\\memory_stats\\$latest_su\\$build_variant\\athwlan_mem_stats_summary.txt");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\Memstats\\memory_stats_report.pl C:\\memory_stats\\Automation\\memory_stats_report.pl");

chdir ("C:\\memory_stats\\Automation\\") or die "cannot change: $!\n";
system("perl memory_stats_report.pl -su_name $latest_su -build_variant $build_variant");
print "Please wait for few seconds, copying all the relevant files to \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\ \n";

system("mkdir \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\");
system("cp -r C:\\memory_stats\\Automation\\memory_stats_report.pl \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\memory_stats_report.pl");
system("cp -r C:\\memory_stats\\$latest_su\\$build_variant\\athwlan_mem_stats_detailed.html \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\athwlan_mem_stats_detailed.html");
system("cp -r C:\\memory_stats\\$latest_su\\$build_variant\\memstats.html \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\memstats.html");
system("cp -r C:\\memory_stats\\$latest_su\\$build_variant\\memstats.txt \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\memstats.txt");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\bin\\memstats_map.json \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\memstats_map.json");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\image\\athwlan_mem_stats_detailed.txt \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\athwlan_mem_stats_detailed.txt");
system("cp -r \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\image\\athwlan_mem_stats_summary.txt \\\\wallace\\wlanblds\\sw_build\\release_builds\\SoCFW\\$si_name\\$latest_su\\$build_variant\\Firmware\\AR6320\\hw3\\Memstats\\athwlan_mem_stats_summary.txt");
		
# sub click_on_the_middle_of_window {

    # # the window handle of the window we will click on
    # my $window = shift;

    # # print "* Moving the mouse over the window id: $window\n";

    # # get the coordinates of the window
    # my ( $left, $top, $right, $bottom ) = GetWindowRect(@WLAN_memStat_window[0]);
	# print "$left, $top, $right, $bottom \n";

	# #MouseMoveAbsPix( ( $right + $left ) / 2,  ( $top + $bottom ) / 2);
    # # ;-)
    # sleep(2);

    # # send LEFT CLICK event
    # # print "* Left Clicking on the window id: $window \n";
    # SendMouse("{LeftClick}");
	# SendKeys ("{TAB}");
	# SendKeys ("{TAB}");
	# SendKeys ("{TAB}");
	# SendKeys ("{TAB}");
	# SendKeys("{SPC}");
    # sleep(2);
# }
		
		
sub push_button {
    my $parent_window_title = shift;
    my @button;
    my @window;

    sleep 1;

    # find the button's parent window 
    @window = FindWindowLike( undef, $parent_window_title, "" );

    # bring it to front
    if ( !bring_window_to_front( $window[0] ) ) {
        print "* Could not bring to front $window[0]\n";
    }
    # search for _the_ button
    #@button = FindWindowLike( undef, "", "","" );
	
    sleep 1;

    #print "* Trying to push button id: $button[0]\n";
    #PushChildButton( $window[0], "^Export(.*?)", 0.25 );
    sleep 1;

}

sub bring_window_to_front {
    my $window  = shift;
    my $success = 1;

    if ( SetActiveWindow($window) ) {
        print
"* Successfuly set the window id: $window active\n";
    }
    else {
        print
          "* Could not set the window id: $window active\n";
        $success = 0;
    }
    if ( SetForegroundWindow($window) ) {
        print
          "* Window id: $window brought to foreground\n";
    }
    else {
        print
"* Window id: $window could not be brought to foreground\n";
        $success = 0;
    }

    return $success;
}
