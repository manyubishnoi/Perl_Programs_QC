use strict;
use warnings;

use Getopt::Long;
# Read User Specified Commandline option
# Usage:
# perl memory_stats_report.pl -su_name su90

my $su_name = undef;
my $build_variant = undef;
GetOptions(
	"su_name=s"    => \$su_name,
	"build_variant=s" => \$build_variant,
	);
#my $su_name = $ARGV[0];
my $staticMemSrc = "c:\\memory_stats\\$su_name\\$build_variant\\athwlan_mem_stats_detailed.txt";
my $staticMemReport = "c:\\memory_stats\\$su_name\\$build_variant\\athwlan_mem_stats_detailed.html";

my $dynamicMemSrc = "c:\\memory_stats\\$su_name\\$build_variant\\memstats.txt";
my $dynamicMemReport = "c:\\memory_stats\\$su_name\\$build_variant\\memstats.html";

my $staticMemTitle = "Static Memory Stats Results";
my $dynamicMemTitle = "Dynamic Memory Stats Results";
generateHtmlHeader($staticMemReport, $staticMemTitle);
generateHtmlHeader($dynamicMemReport, $dynamicMemTitle);

generateStaticMemReport($staticMemSrc, $staticMemTitle, $staticMemReport);
generateDynamicMemReport($dynamicMemSrc, $dynamicMemTitle, $dynamicMemReport);

sub generateDynamicMemReport{
	my ($srcFile, $htmlTitle, $htmlReport) = @_;
	open(FH, "<$srcFile") or die $!;
	my @myData = <FH>;
	close FH;

	my @items = ();
	my %myData1 = ();
	my @keys = undef;
	my $headline = undef;
	my $index = 0;

	# Sort mem data based on ID
	foreach my $line (@myData) {
		if ($line =~ /filename/i) {
			$headline = $line;
			next;
		}
		@items = split(/,/, $line);
		# Use IDs as keys. ID by default is address in hex value
		my $key = $items[0];
		# Deal with duplicate IDs as keys
		foreach my $key1 (@keys) {
			if ((defined $key1) && ($key eq $key1)) {
				$key .= "_$index";
				$index++;
				last;
			}
		}
		push (@keys, $key);
		$myData1{$key} = $line;
	}
	$index = 0;
	my @sortedData = ();
	$sortedData[$index++] = $headline;
	foreach my $key2 (sort(keys(%myData1))) {
		$sortedData[$index++] = $myData1{$key2};
	}

	open(INPUT, ">>$htmlReport") or die $!;
	print INPUT "<BODY>\n\t<H1 align=\"center\">$htmlTitle</H1>\n\t<br>\n";
	print INPUT "\t<table border=\"1\" cellspacing=\"1\" cellpadding=\"5\">\n";
	my $count = 0;
	foreach my $line (@sortedData) {
		$count++;
		# Remove blank line
		if ($line =~ /^\s*$/) {
			next;
		}
		chomp($line);
		@items = split(/,/, $line);
		
		print INPUT "\t</tr>\n";
		if ($line =~ /filename/i) {
			foreach my $item (@items) {
				print INPUT "\t\t<th>$item</th>\n";
			}
		} else {
			foreach my $item (@items) {
				print INPUT "\t\t<td>$item</td>\n";
			}
		}
		print INPUT "\t</tr>\n";
	}
	print "Dynamic mem report line counts: $count\n";
	print INPUT "\t\t</table>\n";
	print INPUT "\t</BODY>\n";
	print INPUT "</HTML>\n";
	close INPUT;
}

sub generateStaticMemReport {
	my ($srcFile, $htmlTitle, $htmlReport) = @_;
	open(FH, "<$srcFile") or die $!;
	my @myData = <FH>;
	close FH;

	open(INPUT, ">>$htmlReport") or die $!;
	print INPUT "<BODY>\n\t<H1 align=\"center\">$htmlTitle</H1>\n\t<br>\n";
	my $tableTagCount = 0;
	foreach my $line (@myData) {
		# Remove blank line
		if ($line =~ /^\s*$/) {
			next;
		}
		chomp($line);
		my @items = undef;
		# Match special instance "OVERALL(AllComponents in KB)"
		if ($line =~ /\(.+\s.+\)/) {
			$line =~ s/\s/_/g;
		}
		@items = split(/\s+/, $line);

		my $itemSize = scalar (@items);
		if ($itemSize == 1) {
			if ($tableTagCount > 0) {
				print INPUT "\t</table>\n\t<br>\n";
				$tableTagCount--;
			}
			print INPUT "\t<H2>$items[$#items-1]</H2>\n";
			print INPUT "\t<table border=\"1\" cellspacing=\"1\" cellpadding=\"5\">\n";
			$tableTagCount++;
		} else {
			print INPUT "\t</tr>\n";
			if ($line =~ /sections|filename/i) {
				foreach my $item (@items) {
					print INPUT "\t\t<th>$item</th>\n";
				}
			} else {
				foreach my $item (@items) {
					print INPUT "\t\t<td>$item</td>\n";
				}
				# Deal with a special case for Summary(KB) table
				if (($line =~ /summary/i) && ($tableTagCount > 0)) {
					print INPUT "\t\t</table>\n\t<br>\n";
					$tableTagCount--;
					# A new table start without title
					print INPUT "\t<table border=\"1\" cellspacing=\"1\" cellpadding=\"5\">\n";
					$tableTagCount++;
				}
			}
			print INPUT "\t</tr>\n";
		}
	}
	if ($tableTagCount > 0) {
		print INPUT "\t\t</table>\n\t<br>\n";
		$tableTagCount--;
	}
	print INPUT "\t</BODY>\n";
	print INPUT "</HTML>\n";
	close INPUT;
}

sub generateHtmlHeader {
	my ($html_report, $title) = @_;
	open(INPUT, ">$html_report") or die $!;
	print INPUT "<HTML>\n\t<HEAD>\n";
	print INPUT "\t\t<meta http-equiv=\"Content-Type\" content=\"text/html;charset=utf-8\"/>\n";
	print INPUT "\t\t<TITLE>$title</TITLE>\n";
	print INPUT "\t</HEAD>\n";
	print INPUT "\t<style>\n";
	print INPUT "\t\ttable tr:nth-child(even) {\n";
	print INPUT "\t\t\tbackground-color: #f1f1c1;\n";
	print INPUT "\t\t}\n";
	print INPUT "\t\ttable tr:nth-child(odd) {\n";
	print INPUT "\t\t\tbackground-color: #fff;\n";
	print INPUT "\t\t}\n";
	print INPUT "\t\ttable th {\n";
	print INPUT "\t\t\tbackground-color: black;\n";
	print INPUT "\t\t\tcolor: white;\n";
	print INPUT "\t\t}\n";
	print INPUT "\t</style>\n";
	close INPUT;
}



