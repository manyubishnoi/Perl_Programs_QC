#-------------------------------------------------------------------------------#
# Ath6kInstaller.pm   -  API for Ath6k code base				#
# Author              -  SPE (spe@atheros.com)					#
# Created on          -  06/01/2007						#
# Last Modified       -  07/30/2012						#
#-------------------------------------------------------------------------------#

package Sta::Install::Ath6kInstaller;

use vars qw($VERSION);

use strict;
use warnings;

use Cwd;
use Log::Log4perl qw(:easy);
use File::Spec::Functions;
use File::Copy;
use Exporter;
use Data::Dumper;

BEGIN {
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION = 1.1;
	@ISA     = qw(Exporter);
	@EXPORT  = qw(
					loadModules
					unloadModules
					isInstallerRunning
					installDriver
					setFlashMode
					);

	%EXPORT_TAGS = ();  # eg: TAG => [ qw!name1 name2! ]
}

#-------------------------------------------------------------------------------

# Nl80211Installer will be a part of Atheros Station module. So no need to
# create the object of type Sta::Install::Nl80211Installer. If some body
# want to use this module as stand alone. uncomment this block

#-------------------------------------------------------------------------------
# Constructor for Sta::Install::Nl80211Installer Module.
#-------------------------------------------------------------------------------

#sub new {

#  my ($class, %args) = @_;
#  my $self=\%args;

#  my $level= $self->{'DEBUG'}||"DEBUG";

#  bless $self, 'Sta::Install::Nl80211Installer';
#  DEBUG"Created new Sta::Install::Nl80211Installer object";
#  return $self;

# }

#-------------------------------------------------------------------------------
# loadModules - Installs Host modules.
#-------------------------------------------------------------------------------

sub loadModules {
	my ($self, %param) = @_;
	my $reg_domain      = $param{REG_DOMAIN};
	my $workArea        = $self->{WORKAREA};
	my $hw              = $self->{HW};
	my $p2p_dev_if      = "";
	my $p2p_grp_if      = "";
	my $debug_quirks    = "";
	my $reg_load_str    = "";
	my $p2p_support_str = "";

	if (defined $self->{P2P}->{DEVICE_INTERFACE}) {
		$p2p_dev_if = $self->{P2P}->{DEVICE_INTERFACE};
	}

	if (defined $self->{P2P}->{GROUPS}->{GROUP}->{GROUP_INTERFACE}) {
		$p2p_grp_if = $self->{P2P}->{GROUPS}->{GROUP}->{GROUP_INTERFACE};
	}

	if (defined $self->{DEBUG_QUIRKS}) {
		$debug_quirks = "debug_quirks=$self->{DEBUG_QUIRKS}";
	}

	if (defined $param{REG_DOMAIN}) {
		$reg_load_str = "reg_domain=$param{REG_DOMAIN}";
	}

	if (defined $self->{P2P_DRIVER_SUPPORT} && $self->{P2P_DRIVER_SUPPORT}) {
		# if support P2P concurrency
		if ($self->{P2P}->{DEVICE_INTERFACE} ne $self->{INTERFACE_NAME}) {
			# if support P2P MCC
			if (   (defined $self->{P2P}->{OFF_BAND_SUPPORT} && $self->{P2P}->{OFF_BAND_SUPPORT})
				|| (defined $self->{P2P}->{OFF_CHANNEL_SUPPORT} && $self->{P2P}->{OFF_CHANNEL_SUPPORT})) {
				if ($p2p_dev_if eq $p2p_grp_if) {
					# if P2P non-dedicated
					$p2p_support_str = "ath6kl_p2p=0x19";
				} else {
					# if P2P dedicated
					$p2p_support_str = "ath6kl_p2p=0x13";
				}
			} else {
				#if support P2P concurrency but not support MCC
				if ($p2p_dev_if eq $p2p_grp_if) {
					# if P2P non-dedicated
					$p2p_support_str = "ath6kl_p2p=0x9";
				} else {
					# if P2P dedicated
					$p2p_support_str = "ath6kl_p2p=0x3";
				}
			}
		} else {
			# if not support P2P concurrency
			$p2p_support_str = "ath6kl_p2p=0x1";
		}
	}

	#HW tag format: <Platform>-<FormFactor>-<WirelessCard>
	if ($hw =~ /MSM7x27A/i) {
		$self->execFromCmdLine("sudo insmod $workArea/wlan.ko $reg_load_str");
	} elsif ($hw =~ /MSM8960|MSM8974|MSM8626|Prima/i) {

		# Enable Radio to safely load the host driver.
		$self->execFromCmdLine("adb shell svc wifi enable");

		# reload the host driver. Regdomain setting support currently not available.
		if ($hw =~ /MSM8960|Prima/i) {
			$self->execFromCmdLine("sudo insmod $workArea/prima/cfg80211.ko");
			$self->execFromCmdLine("sudo insmod $workArea/prima/prima_wlan.ko");
		}
		if ($hw =~ /MSM8974|MSM8626|Pronto/i) {
			$self->execFromCmdLine("sudo insmod $workArea/Pronto/cfg80211.ko");
			$self->execFromCmdLine("sudo insmod $workArea/Pronto/pronto_wlan.ko");
		}

		# reload the WLAN Driver
		$self->execFromCmdLine("adb shell svc wifi disable");
		$self->execFromCmdLine("adb shell svc wifi enable");

	} elsif ($hw =~ /MPQ8064/i) {
		$self->execFromCmdLine("sudo insmod $workArea/cfg80211.ko");
		$self->execFromCmdLine("sudo insmod $workArea/wlan.ko $p2p_support_str $debug_quirks $reg_load_str");
	} else {
		if ((defined $self->{INTERFACE_TYPE}) && ($self->{INTERFACE_TYPE} =~ /usb/i)) {
			if ($hw =~ /QCA6574|QCA6174/i) {
				$self->execFromCmdLine("sudo modprobe cfg80211");
				$self->execFromCmdLine("sudo insmod $workArea/host/wlan.ko");
			} else {
				$self->execFromCmdLine("sudo insmod $workArea/cfg80211.ko");
				$self->execFromCmdLine("sudo insmod $workArea/ath6kl_usb.ko $p2p_support_str $debug_quirks $reg_load_str");
			}
		} else {
			if ($hw =~ /FPGA/i) {
				# $self->{SCC_STATE} is added when set up the 1st SCC link. When set up the 2nd SCC link, skip loading wlan driver
				# $self->{SCC_STATE} is set undef after SCC test finishes
				if (not defined $self->{SCC_STATE}) {
					if (defined $param{SCC}) {
						INFO "Insert wlan.ko module";
						DEBUG $self->execFromCmdLine("adb wait-for-device root");
						DEBUG $self->execFromCmdLine("insmod /system/lib/modules/wlan.ko");
						sleep 5;
						my $interface = "";
						if (defined $self->{CONCURRENCY_LINKS}->{CONCURRENCY_LINK}->{DEVICE_INTERFACE}) {
							$interface = $self->{CONCURRENCY_LINKS}->{CONCURRENCY_LINK}->{DEVICE_INTERFACE};
						}
						my $phy_intf = $self->getPhyInterface();
						DEBUG $self->execFromCmdLine("iw phy $phy_intf interface add $interface type managed");
						$self->{SCC_STATE} = $param{SCC};
						DEBUG "SCC state is $self->{SCC_STATE}";
					} else {
						INFO "Insert wlan.ko module";
						DEBUG $self->execFromCmdLine("adb wait-for-device root");
						DEBUG $self->execFromCmdLine("insmod /system/lib/modules/wlan.ko");
						sleep 5;
					}
				}
			} else {
				$self->execFromCmdLine("sudo insmod $workArea/cfg80211.ko");
				$self->execFromCmdLine("sudo insmod $workArea/ath6kl_sdio.ko $p2p_support_str $debug_quirks $reg_load_str");
			}
		}
	}

	sleep 5;
	return 1;
}

#-------------------------------------------------------------------------------
# unloadModules - uninstall Host Modules
#-------------------------------------------------------------------------------

sub unloadModules {
	my $self = shift;
	my $hw   = $self->{HW};

	if ($hw =~ /MSM7x27A|MSM8960|MSM8974|MSM8626|Prima|Pronto|MPQ8064/i) {
		$self->execFromCmdLine("sudo rmmod wlan");
		$self->execFromCmdLine("sudo rmmod cfg80211");
	} else {
		if ((defined $self->{INTERFACE_TYPE}) && ($self->{INTERFACE_TYPE} =~ /usb/i)) {
			if ($hw =~ /QCA6574|QCA6174/i) {
				$self->execFromCmdLine("sudo rmmod wlan");
				$self->execFromCmdLine("sudo rmmod cfg80211");
			} else {
				$self->execFromCmdLine("sudo rmmod ath6kl_usb");
				$self->execFromCmdLine("sudo rmmod cfg80211");
			}
		} else {
			if ($hw =~ /FPGA/i) {
				if ((defined $self->{SCC_STATE}) && $self->{SCC_STATE}) {
					DEBUG "SCC state is $self->{SCC_STATE}, not do unloadModules on FPGA STA";
				} else {
					INFO "Stop Wlan Apps";
					_stopWlanApps($self);
					# $self->{SCC_STATE} is internal argument to track SCC state. After SCC test finish, clear SCC state
					if (defined $self->{SCC_STATE}) {
						INFO "Clear SCC state";
						$self->{SCC_STATE} = undef;
					}
					DEBUG $self->execFromCmdLine("rmmod wlan");
				}
			} else {
				$self->execFromCmdLine("sudo rmmod ath6kl_sdio");
				$self->execFromCmdLine("sudo rmmod cfg80211");
			}
		}
	}
	sleep 10;
	return 1;
}

sub _stopWlanApps {
	my $self         = shift;
	my $interface    = $self->{INTERFACE_NAME} || "wlan0";
	# Clean existing SAP and IBSS states
	DEBUG $self->execFromCmdLine("killall hostapd");
	sleep 1;
	DEBUG $self->execFromCmdLine("killall hostapd_cli");
	sleep 1;
	DEBUG $self->execFromCmdLine("killall wpa_supplicant");
	sleep 1;
	DEBUG $self->execFromCmdLine("killall wpa_cli");
	return 1;
}

sub installDriver {
	my ($self, $param) = @_;
	my $hw      = $self->{HW};
	my $release = $self->{RELEASE};
	$hw =~ s/msm//gi;
	my $device_id = $self->{DEVICE_ID};
	my $os        = $self->{OS};
	my $workarea  = $self->{WORKAREA};
	my %recover_hash;
	my $destination_root = "/firmware/image";
	my $return_href;

	$recover_hash{INSTALL_TYPE}     = $self->{INSTALL_TYPE};
	$recover_hash{GOLDEN_BUILD}     = $self->{GOLDEN_BUILD};
	$recover_hash{DEVICE_ID}        = $device_id;
	$recover_hash{META_PATH}        = $recover_hash{GOLDEN_BUILD}{META_BUILD};
	$recover_hash{HOST_PATH}        = $recover_hash{GOLDEN_BUILD}{HOST_BUILD};
	$recover_hash{SOFTWARE_PRODUCT} = $recover_hash{GOLDEN_BUILD}{SOFTWARE_PRODUCT};

	DEBUG Dumper(\%recover_hash);
	my $fw_build_dir = "$ENV{LAB_ROOT}\\Builds\\DUT\\STA\\$release\\$self->{BUILD}";
	DEBUG "Starting META/HOST Recovery...";
	$recover_hash{INSTALL_META} = 1;
	$recover_hash{INSTALL_HOST} = 1;

	_installImage($self, %recover_hash);

	# Load specified firmware, host driver
	my $pwd = Cwd::getcwd();
	chdir($fw_build_dir);
	DEBUG Cwd::getcwd();

	DEBUG "Loading requested build.....";
	# load requested firmware/host driver.
	DEBUG "OS is : ", $self->{OS};
	if ($self->{OS} =~ /Linux/i) {
		DEBUG "INSIDE>>>>>>>>>>>>>OS is : $self->{OS}";
		if (($self->{INTERFACE_TYPE} =~ /usb/i) && ($self->{HW} =~ /QCA6574|QCA6174/i)) {
			# copy firmware files to required location
			# copy host configuration files to required location
			# load wlan module
			$destination_root = "/lib/firmware";

			INFO "current work area is: $self->{WORKAREA}";

			$self->execFromCmdLine("cd $ENV{LAB_ROOT}/Builds/DUT/STA/$release/$self->{BUILD}");
			my $output = $self->execFromCmdLine("pwd");
			INFO "Current dir is: $output";

			INFO "Cretae $self->{WORKAREA} folder";
			$self->execFromCmdLine("mkdir -p $self->{WORKAREA}");

			INFO "copying supplicant,hostapd to $self->{WORKAREA} folder";
			$self->execFromCmdLine("cp ./supplicant/hostapd $self->{WORKAREA}");
			$self->execFromCmdLine("chmod 777 $self->{WORKAREA}/hostapd");
			$self->execFromCmdLine("cp ./supplicant/hostapd_cli $self->{WORKAREA}");
			$self->execFromCmdLine("chmod 777 $self->{WORKAREA}/hostapd_cli");
			$self->execFromCmdLine("cp ./supplicant/wpa_supplicant $self->{WORKAREA}");
			$self->execFromCmdLine("chmod 777 $self->{WORKAREA}/wpa_supplicant");
			$self->execFromCmdLine("cp ./supplicant/wpa_cli $self->{WORKAREA}");
			$self->execFromCmdLine("chmod 777 $self->{WORKAREA}/wpa_cli");

			# copy qca61x4.bin and board data files to destination directory
			DEBUG "copying qca61x4.bin and board data file to $destination_root folder";
			my @firmware_directory_list = $self->execFromCmdLine("ls");
			my $found_firmware_folder   = 0;
			foreach my $file_name (@firmware_directory_list) {
				if ($file_name =~ /firmware/i) {
					$found_firmware_folder = 1;
				}
			}
			if ($found_firmware_folder == 1) {
				$self->execFromCmdLine("cp ./firmware/qca61x4.bin $destination_root");
				$self->execFromCmdLine("cp ./firmware/fakeboar.bin $destination_root/fakeboar.bin");
				$self->execFromCmdLine("cp ./firmware/athwlan.bin $destination_root");
				$self->execFromCmdLine("cp ./firmware/otp.bin $destination_root");
				$self->execFromCmdLine("cp ./firmware/utf.bin $destination_root");
				$self->execFromCmdLine("cp ./firmware/wlansetup.bin $destination_root/athsetup.bin ");
			} else {
				$self->execFromCmdLine("cp ./qca61x4.bin $destination_root");
				$self->execFromCmdLine("cp ./eeprom_*.bin $destination_root/fakeboar.bin");
				$self->execFromCmdLine("cp ./athwlan.bin $destination_root");
				$self->execFromCmdLine("cp ./otp.bin $destination_root");
				$self->execFromCmdLine("cp ./utf.bin $destination_root");
				$self->execFromCmdLine("cp ./wlansetup.bin $destination_root/athsetup.bin ");
			}
			$self->execFromCmdLine("chmod 777 $destination_root/qca61x4.bin");
			$self->execFromCmdLine("chmod 777 $destination_root/fakeboar.bin");
			$self->execFromCmdLine("chmod 777 $destination_root/athwlan.bin");
			$self->execFromCmdLine("chmod 777 $destination_root/otp.bin");
			$self->execFromCmdLine("chmod 777 $destination_root/utf.bin");
			$self->execFromCmdLine("chmod 777 $destination_root/athsetup.bin");

			# copy host configuration files to /lib/firmware/wlan folder
			# check if wlan folder exists or if we need to create one
			DEBUG "Moving host configuration files to /lib/firmware/wlan directory";
			$self->execFromCmdLine("mkdir -p $destination_root/wlan");
			$self->execFromCmdLine("chmod 777 $destination_root/wlan");

			INFO "copying wlan.ko to $self->{WORKAREA} folder";
			$self->execFromCmdLine("mkdir -p $self->{WORKAREA}");
			$self->execFromCmdLine("mkdir -p $self->{WORKAREA}/host");
			$self->execFromCmdLine("cp ./host/wlan.ko $self->{WORKAREA}/host");
			$self->execFromCmdLine("chmod 777 $self->{WORKAREA}/host/wlan.ko");

			my @directory_list = $self->execFromCmdLine("ls ./host");
			# INFO "Files under = @directory_list";
			my ($found_cfg_dat, $found_cfg_ini, $found_wlan_nv) = 0;
			foreach my $file_name (@directory_list) {
				if ($file_name =~ /cfg.dat/i) {
					$found_cfg_dat = 1;
				}
				if ($file_name =~ /qcom_cfg.ini/i) {
					$found_cfg_ini = 1;
				}
				if ($file_name =~ /qcom_wlan_nv.bin/i) {
					$found_wlan_nv = 1;
				}
			}

			if ($found_cfg_dat == 1) {
				DEBUG "copying host configuration file: cfg.dat";
				$self->execFromCmdLine("cp ./host/cfg.dat $destination_root/wlan/");
				$self->execFromCmdLine("chmod 777 $destination_root/wlan/cfg.dat");
			} else {
				DEBUG "cfg.dat file missing, please provide file";
			}
			if ($found_cfg_ini == 1) {
				DEBUG "copying host configuration file: qcom_cfg.ini";
				$self->execFromCmdLine("cp ./host/qcom_cfg.ini $self->{WORKAREA}/host/");
				$self->execFromCmdLine("chmod 777 $self->{WORKAREA}/host/qcom_cfg.ini");
				$self->execFromCmdLine("cp -f $self->{WORKAREA}/host/qcom_cfg.ini $destination_root/wlan/");
			} else {
				DEBUG "qcom_cfg.ini file missing, please provide file";
			}
			if ($found_wlan_nv == 1) {
				DEBUG "copying host configuration file: qcom_wlan_nv.bin";
				$self->execFromCmdLine("cp ./host/qcom_wlan_nv.bin $destination_root/wlan/");
				$self->execFromCmdLine("chmod 777 $destination_root/wlan/qcom_wlan_nv.bin");
			} else {
				DEBUG "qcom_wlan_nv.bin file missing, please provide file";
			}

		}
	}
	DEBUG(Cwd::getcwd());
	if ($self->{OS} =~ /Android/i) {
		$self->execFromCmdLine("adb root");
		$self->execFromCmdLine("adb root");
		$self->execFromCmdLine("adb root");
		$self->execFromCmdLine("adb shell ls");
		$self->execFromCmdLine("adb shell ls");
		$self->execFromCmdLine("adb shell ls");
		$self->execFromCmdLine("adb shell ls");
		$self->execFromCmdLine("adb shell ls");

		# Firmware Installation.
		if (-e "wcnss.flist") {

			# delete all existing wcnss.bxx files in DUT.
			$self->execFromCmdLine("adb root");
			sleep 5;
			DEBUG $self->execFromCmdLine("adb shell mount -t vfat -o remount,rw /dev/block/mmcblk0p1 /firmware");
			DEBUG $self->execFromCmdLine("adb shell svc wifi disable");
			DEBUG $self->execFromCmdLine("adb shell rm $destination_root/wcnss*");

			# read all the wcnss.bxx files from wcnss.flist file.
			open FH, "wcnss.flist";
			my @contents = <FH>;
			close FH;
			my $contents = "@contents";
			my (@wcnss_files) = $contents =~ m/(wcnss\.b..)/gi;
			push @wcnss_files, "wcnss.mdt";
			push @wcnss_files, "wcnss.flist";
			DEBUG "Requested wcnss files: @wcnss_files";

			# update the new wcnss.xyz files in DUT.
			foreach my $wcnss_file (@wcnss_files) {
				DEBUG $self->execFromCmdLine("adb push $wcnss_file $destination_root");
			}
		}

		# Push WCNSS_qcom_cfg.ini, WCNSS_cfg.dat
		my $ini_path = $self->{WCNSS_INI_PATH};
		if (-e "WCNSS_qcom_cfg.ini") {
			DEBUG $self->execFromCmdLine("adb push WCNSS_qcom_cfg.ini $ini_path");
		}
		if (-e "WCNSS_cfg.dat") {
			DEBUG $self->execFromCmdLine("adb push WCNSS_cfg.dat /data/misc/wifi");
		}

		# Host Driver Installation.
		if (-e "prima") {
			$destination_root = "/system/lib";
			# Host Driver for Prima devices
			DEBUG $self->execFromCmdLine("adb root");
			DEBUG $self->execFromCmdLine("adb remount");
			DEBUG $self->execFromCmdLine("adb shell svc wifi disable");
			DEBUG $self->execFromCmdLine("adb push prima $destination_root/modules/prima");
			DEBUG $self->execFromCmdLine("adb push prima_wlan.ko $destination_root/modules/prima");
			DEBUG $self->execFromCmdLine("adb push proprietary_prima_wlan.ko $destination_root/modules/prima");

		}
		if (-e "pronto") {
			$destination_root = "/system/lib";
			# Host Driver for Pronto Devices
			DEBUG $self->execFromCmdLine("adb root");
			DEBUG $self->execFromCmdLine("adb remount");
			DEBUG $self->execFromCmdLine("adb shell svc wifi disable");
			DEBUG $self->execFromCmdLine("adb push pronto $destination_root/modules/pronto");
			DEBUG $self->execFromCmdLine("adb push pronto_wlan.ko $destination_root/modules/pronto");
			DEBUG $self->execFromCmdLine("adb push proprietary_pronto_wlan.ko $destination_root/modules/pronto");
		}

		# Firmware Installation for CDPs (surf boards)
		if ($hw =~ /8064|8084|9X\d\d|89\d\d/i) {
			DEBUG $self->execFromCmdLine("adb root");
			for (my $i = 0; $i < 5; $i++) {
				my $output = $self->execFromCmdLine("adb remount");
				DEBUG "remount output = $output";
				if ($output !~ /succeeded/i) {
					sleep 5;
					$i++;
				} else {
					last;
				}
			}
			if ($self->{HW} !~ /FPGA/i) {
				DEBUG $self->execFromCmdLine("adb shell svc wifi disable");
			}
			DEBUG $self->execFromCmdLine("adb shell rm -f /etc/firmware/athwlan*.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f /etc/firmware/otp*.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f /etc/firmware/fakeBoardData_AR6004.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f /etc/firmware/fakeboar.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/qwlan*.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/utf*.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/otp*.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/bdwlan*.bin");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/Data.msc");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/modem.*");
			DEBUG $self->execFromCmdLine("adb shell rm -f $destination_root/mba.*");

			DEBUG $self->execFromCmdLine("adb shell mount -o rw,remount /firmware /firmware");
			# For memory status tracking purpose
			DEBUG $self->execFromCmdLine("adb push Data.msc $destination_root/Data.msc");
			my %src_dest;
			if ((defined $self->{HW_VERSION}) && ($self->{HW_VERSION} =~ /^2.*/i)) {
				$src_dest{"athwlan.bin"} = "$destination_root/qwlan20.bin";
				$src_dest{"otp.bin"}     = "$destination_root/otp20.bin";
				$src_dest{"utf.bin"}     = "$destination_root/utf20.bin";
				if ($self->{HW} =~ /ADP8064/i) {
					$src_dest{"eeprom_ar6320_2p1_fccsp_cob.bin"} = "$destination_root/bdwlan20.bin";
				} else {
					if (-e "fakeBoardData_AR6004.bin") {
						$src_dest{"fakeBoardData_AR6004.bin"} = "$destination_root/bdwlan20.bin";
					} else {
						$src_dest{"eeprom_ar6320_2p1_wb294i_olpc.bin"} = "$destination_root/bdwlan20.bin";
					}
				}
			} elsif ((defined $self->{HW_VERSION}) && ($self->{HW_VERSION} =~ /^3.*/i)) {
				if ($self->{HW} =~ /FPGA/i) {
					$src_dest{"image"}       = "$destination_root";
				} else {
					$src_dest{"athwlan.bin"} = "$destination_root/qwlan30.bin";
					$src_dest{"otp.bin"}     = "$destination_root/otp30.bin";
					$src_dest{"utf.bin"}     = "$destination_root/utf30.bin";

					if ($self->{HW} =~ /8064/i) {
						$src_dest{"eeprom_ar6320_3p0_fccsp_cob_SDIO_CLPC_2x2.bin"} = "$destination_root/bdwlan30.bin";
					} else {
						if (-e "fakeBoardData_AR6004.bin") {
							$src_dest{"fakeBoardData_AR6004.bin"} = "$destination_root/bdwlan30.bin";
						} else {
							if ($hw =~ /8996/i) {
								$src_dest{"eeprom_ar6320_3p0_RM4p1_CLPC.bin"} = "$destination_root/bdwlan30.bin";
							} elsif ($hw =~ /89\d\d|9x45/i) {
								$src_dest{"eeprom_ar6320_3p0_Y7275_OLPC.bin"} = "$destination_root/bdwlan30.bin";
							} else {
								$src_dest{"eeprom_ar6320_3p0_wb294i_olpc.bin"} = "$destination_root/bdwlan30.bin";
							}
						}
					}
				}
			} elsif ((defined $self->{HW_VERSION}) && ($self->{HW_VERSION} =~ /^1.3/i)) {
				$src_dest{"athwlan.bin"} = "$destination_root/qwlan13.bin";
				$src_dest{"otp.bin"}     = "$destination_root/otp13.bin";
				$src_dest{"utf.bin"}     = "$destination_root/utf13.bin";
				if (-e "fakeBoardData_AR6004.bin") {
					$src_dest{"fakeBoardData_AR6004.bin"} = "$destination_root/bdwlan13.bin";
				} else {
					$src_dest{"eeprom_ar6320_wb294i_olpc.bin"} = "$destination_root/bdwlan13.bin";
				}
			} else {
				$src_dest{"athwlan.bin"} = "$destination_root/qwlan11.bin";
				$src_dest{"otp.bin"}     = "$destination_root/otp11.bin";
				$src_dest{"utf.bin"}     = "$destination_root/utf11.bin";
				if (-e "fakeBoardData_AR6004.bin") {
					$src_dest{"fakeBoardData_AR6004.bin"} = "$destination_root/bdwlan11.bin";
				} else {
					$src_dest{"eeprom_ar6320_wb294i_olpc.bin"} = "$destination_root/bdwlan11.bin";
				}
			}

			my @push_pass;
			my @push_fail;
			foreach my $key (keys %src_dest) {
				my $parity_check = $self->execFromCmdLine("adb push $key $src_dest{$key}");
				if ($parity_check) {
					DEBUG "$key : was pushed properly";
					push @push_pass, $key;
				} else {
					DEBUG "$key : didn't push properly";
					push @push_fail, $key;
				}
			}
			my $file_names = join(",", @push_pass);
			$return_href->{FW_FILES} = $file_names;
			if (scalar(@push_fail)) {
				$return_href->{FW_RESULT}   = "FAIL";
				$return_href->{FW_COMMENTS} = "One or more files failed to be pushed";
			} else {
				$return_href->{FW_RESULT}   = "PASS";
				$return_href->{FW_COMMENTS} = "All files were pushed successfully";
			}

			if (-e "proprietary_prima_cld_wlan.ko") {
				DEBUG $self->execFromCmdLine("adb push proprietary_prima_cld_wlan.ko /system/lib/modules/prima_cld");
			}
		}

		# Sync and reboot
		DEBUG $self->execFromCmdLine("adb shell sync");
		if (defined $self->{WLAN_SERVICE_PATH}) {
			$self->execFromCmdLine("adb shell $self->{WLAN_SERVICE_PATH}/wlan start");
		} else {
			if ($self->{HW} !~ /FPGA/i) {
				DEBUG $self->execFromCmdLine("adb shell svc wifi enable");
			} else {
				DEBUG $self->execFromCmdLine("adb reboot");
				DEBUG $self->execFromCmdLine("adb wait-for-device root");
				DEBUG $self->execFromCmdLine("adb wait-for-device shell ls");
				INFO "Sleep 60s after reboot on FPGA devices";
				sleep 60;
			}
		}
		$self->unlockDevice();
	}
	$return_href->{FW_PATH} = $destination_root;
	DEBUG "Developer build successfully loaded.....";
	chdir($pwd);
	return $return_href;
}

sub _installImage {
	my ($self, %hash) = @_;
	my $install_meta = $hash{INSTALL_META};
	my $install_host = $hash{INSTALL_HOST};

	if (defined $install_meta && $install_meta) {
		DEBUG "Meta Image Installation begins...";
		_flashFastbootImages($self, "Meta", %hash);
		DEBUG "Meta Image loading completed";
	}
	if (defined $install_host && $install_host) {
		DEBUG "Host Image Installation begins...";
		_flashFastbootImages($self, "Host", %hash);
		DEBUG "Host Image loading completed";
	}
}

sub _putInFastboot {
	my ($self, $type, %ffi_hash) = @_;
	#Putting device into fastboot.
	my $total_time = 15;
	my $status     = 0;
	while ($total_time--) {
		$self->execFromCmdLine("adb root");
		$self->execFromCmdLine("adb root");
		$self->execFromCmdLine("adb root");
		$self->execFromCmdLine("adb reboot bootloader");
		$self->execFromCmdLine("adb reboot bootloader");
		$self->execFromCmdLine("adb reboot bootloader");
		DEBUG "Waiting sometime to get into fastboot mode...";
		sleep 2;
		my $output = `fastboot devices`;

		if ($output =~ /fastboot/i) {
			DEBUG "Device Went to Fastboot mode...";
			$status = 1;
			last;
		}
	}
	if (!$status) {
		DEBUG "DUT not getting into Fastboot mode";
		return 0;
	}
}

sub _putInAdbMode {
	my ($self, $type, %ffi_hash) = @_;
	DEBUG "Safely putting the device into adb mode by reboot...";
	my $counter = 60;
	while ($counter--) {
		system("fastboot continue");
		sleep 45;
		my $output = `fastboot devices`;
		if ($output !~ /$ffi_hash{DEVICE_ID}/i) {
			DEBUG "DUT went to adb mode";
			last;
		}
	}
	$counter = 300;
	while ($counter--) {
		my $output = `adb devices`;
		DEBUG "counter = $counter $output";
		if ($output =~ /$ffi_hash{DEVICE_ID}/i) {
			$self->execFromCmdLine("adb root");
			$self->execFromCmdLine("adb root");
			$self->execFromCmdLine("adb root");
			my $temp = $self->execFromCmdLine("adb shell ls");
			$temp = $self->execFromCmdLine("adb shell ls");
			if ($temp =~ /root/i) {
				last;
			}
		}
		sleep 1;
	}
}

sub _flashFastbootImages {
	my ($self, $type, %ffi_hash) = @_;
	my $pwd    = Cwd::getcwd();
	my $domain = $ENV{'USERDOMAIN'};
	DEBUG "Domain is: " . $domain;

	if ($type =~ /Meta/i) {
		if ((defined $ffi_hash{META_PATH}) && ($ffi_hash{META_PATH})) {
			my $meta_path = "";
			if ($ffi_hash{META_PATH} =~ /latest$/i) {
				$meta_path = `findbuild -plname=$ffi_hash{SOFTWARE_PRODUCT} -li=1 -ap -si=$domain -info=location`;
				DEBUG Dumper "Meta path found from Findbuild latest is $meta_path";
			} elsif ($ffi_hash{META_PATH} !~ /^$/i) {
				DEBUG "Preferred meta found from Testbed.xml: $ffi_hash{META_PATH}";
				$meta_path = $ffi_hash{META_PATH};
			}

			# Read last loaded meta build details on this system
			my $last_meta             = undef;
			my $last_loaded_meta_file = "$ENV{LAB_ROOT}\\Builds\\DUT\\STA\\last_loaded_meta.txt";
			if (-e $last_loaded_meta_file) {
				open my $fh, "<", $last_loaded_meta_file or die "Could not open file '$last_loaded_meta_file' $!";
				my @lines = <$fh>;
				close $fh;
				$last_meta = "@lines";
				DEBUG "Last installed meta: $last_meta";
			}

			# Comparing the found meta with the last installed meta on DUT
			if (defined $meta_path) {
				$meta_path =~ s/\n//g;
				DEBUG "Latest meta found: $meta_path";
				if ((defined $last_meta) && ($last_meta eq $meta_path)) {
					DEBUG "Same meta, no need to install";
				} else {
					_putInFastboot($self, $type, %ffi_hash);
					# Newer meta found, installing this meta and updating text file
					DEBUG "Flashing Meta Build from : $meta_path";
					my $pushd        = system("pushd $meta_path\\common\\build");
					my $install_meta = system("python $meta_path\\common\\build\\fastboot_complete.py");
					DEBUG "pushd value is : $pushd";
					DEBUG "install_meta value is : $install_meta";
					if ((defined $install_meta) && (!$install_meta)) {
						open my $fw, ">", $last_loaded_meta_file or die "Could not open file '$last_loaded_meta_file' $!";
						print $fw $meta_path;
						close $fw;
					} else {
						DEBUG "Meta loading failed =================================== retrying";
						for (my $i = 0; $i < 2; $i++) {
							DEBUG "Retry count is ", $i + 1;
							my $install_meta_retry = system("python $meta_path\\common\\build\\fastboot_complete.py");
							DEBUG "install_meta_retry is : $install_meta_retry ";
							if ((defined $install_meta_retry) && (!$install_meta_retry)) {
								DEBUG "Meta loading success on retry ", $i + 1;
								open my $fw, ">", $last_loaded_meta_file or die "Could not open file '$last_loaded_meta_file' $!";
								print $fw $meta_path;
								close $fw;
								last;
							} else {
								DEBUG "=============== Failed to load meta after retry ", $i + 1, " =============== ";
							}
						}
					}
					system("popd");
					_putInAdbMode($self, $type, %ffi_hash);
					if (not defined($ffi_hash{HOST_PATH}) || defined($ffi_hash{HOST_PATH}) && ($ffi_hash{HOST_PATH} eq "")) {
						if ($self->{HW} =~ /89\d\d/i) {
							_installTools($self, %ffi_hash);
						}
					}
				}
			}
		} else {
			DEBUG "Not loading meta build as Meta_Build tag is empty or not defined in testbed.xml";
		}
	}
	if ($type =~ /Host/i) {
		if ((defined $ffi_hash{HOST_PATH}) && ($ffi_hash{HOST_PATH})) {
			_putInFastboot($self, $type, %ffi_hash);
			my $mapped_drive = "Z:";
			system("subst $mapped_drive \/D");
			system("net use $mapped_drive \/Delete \/Y");

			my $host_path = $ffi_hash{HOST_PATH};
			if ($host_path =~ /^[a-y]:/i) {
				DEBUG Dumper "Host path is Local Folder $host_path";
				system("subst $mapped_drive $host_path");
			} else {
				DEBUG Dumper "Host path is mapped network drive $host_path";
				system("net use $mapped_drive $host_path");
			}
			chdir("$mapped_drive");
			my (@cmds) = `type Fastboot_load.bat`;
			foreach my $cmd (@cmds) {
				if ($cmd !~ /pause/i) {
					DEBUG "$cmd";
					system($cmd);
				}
			}
			system("net use $mapped_drive \/Delete \/Y");
			system("subst $mapped_drive \/D");
			_putInAdbMode($self, $type, %ffi_hash);
			_installTools($self, %ffi_hash);
		} else {
			DEBUG "Not loading Host build as Host_Build is empty in testbed.xml";
		}
	}
	chdir($pwd);
}

sub _installTools {
	my ($self, %it_hash) = @_;
	my $device_id    = $it_hash{DEVICE_ID};
	my $tools_path   = "$ENV{LAB_ROOT}\\utilities\\generic\\android\\bin";
	my $tools_path_L = "$ENV{LAB_ROOT}\\utilities\\generic\\android\\bin\\Google-L-RedBox";

	# Goto Android tools location.
	my $pwd = Cwd::getcwd();
	chdir("$tools_path");

	# Bring the device to stable state.
	my $wait_time = 180;
	while ($wait_time--) {
		my $temp = $self->execFromCmdLine("adb shell ls");
		if (($temp !~ /error: device not found/i) && ($temp)) {
			# workaround:  adb -s $device_id shell is stable only after executing few commands in root mode.
			my $counter = 30;
			while ($counter--) {
				$self->execFromCmdLine("adb root");
				$self->execFromCmdLine("adb shell ls");
				sleep 3;
			}
			last;
		}
		DEBUG ".";
		sleep 1;
	}

	# Install Android Packages.
	DEBUG $self->execFromCmdLine("adb root");
	DEBUG $self->execFromCmdLine("adb install -r com.shazam.android-1.apk");
	DEBUG $self->execFromCmdLine("adb install -r com.skype.raider-1.apk");
	DEBUG $self->execFromCmdLine("adb install -r org.swiftp-1.apk");
	DEBUG $self->execFromCmdLine("adb install -r org.zwanoo.android.speedtest-1.apk");
	DEBUG $self->execFromCmdLine("adb install -r phoneSettings.apk");
	DEBUG $self->execFromCmdLine("adb install -r SettingsTest.apk");
	DEBUG $self->execFromCmdLine("adb install -r Settings_Wifi.apk");
	DEBUG $self->execFromCmdLine("adb install -r SuspendTest.apk");
	DEBUG $self->execFromCmdLine("adb install -r WifiStation.apk");
	DEBUG $self->execFromCmdLine("adb install -r sap.apk");
	DEBUG $self->execFromCmdLine("adb install -r WifiDirectApp.apk");
	DEBUG $self->execFromCmdLine("adb install -r com.wlan.wlanservice_jb.apk");

	# Push the binary files.
	DEBUG $self->execFromCmdLine("adb root");
	DEBUG $self->execFromCmdLine("adb remount");
	DEBUG $self->execFromCmdLine("adb shell mount -o remount,rw /system/bin /system");
	DEBUG $self->execFromCmdLine("adb push iperf /system/bin");
	DEBUG $self->execFromCmdLine("adb push iw /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwconfig /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwlist /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwpriv /system/bin");
	DEBUG $self->execFromCmdLine("adb push libnl.so /system/lib");
	DEBUG $self->execFromCmdLine("adb push busybox /system/bin");
	DEBUG $self->execFromCmdLine("adb push athdiag /system/bin");
	DEBUG $self->execFromCmdLine("adb push dyna_mem_info /system/bin");
	DEBUG $self->execFromCmdLine("adb push lspci /system/bin");
	DEBUG $self->execFromCmdLine("adb push pktlogconf /system/bin");
	DEBUG $self->execFromCmdLine("adb push Endpoint /system/bin");
	DEBUG $self->execFromCmdLine("adb push WlanUiAutomator.jar /data/local/tmp");
	DEBUG $self->execFromCmdLine("adb push wlantool /system/bin");
	DEBUG $self->execFromCmdLine("adb push permissions.sh /data/");
	DEBUG $self->execFromCmdLine("adb shell chmod 777 /data/permissions.sh");
	DEBUG $self->execFromCmdLine("adb shell sh /data/permissions.sh");

	# Assign Administrator Privileges to executables.
	DEBUG $self->execFromCmdLine("adb shell chmod -R 4777 /system/bin");

	# unlock the device.
	DEBUG $self->execFromCmdLine("adb shell input keyevent 82");

	# Enable Services.
	DEBUG $self->execFromCmdLine("adb shell svc wifi enable");

	# set screenTimeout to 30 minutes.
	DEBUG $self->execFromCmdLine("adb shell am start -a android.intent.action.MAIN -n com.android.phonesettings/.PhonesettingsActivity -e lcd 1");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 82");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 3");
	DEBUG $self->execFromCmdLine("adb shell am start -n com.android.settings/.DisplaySettings");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 19");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 19");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 19");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	DEBUG "Starting 89** L tools download...";
	DEBUG $self->execFromCmdLine("adb install -r com.wlan.wlanservice_jb.apk");
	DEBUG $self->execFromCmdLine("adb install -r com.wlan.wapiservice_jb.apk");

	#Now installing L host specific tools.
	chdir("$tools_path_L");
	DEBUG $self->execFromCmdLine("adb push iperf3 /system/bin");
	DEBUG $self->execFromCmdLine("adb push iw /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwconfig /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwevent /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwgetid /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwlist /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwpriv /system/bin");
	DEBUG $self->execFromCmdLine("adb push iwspy /system/bin");
	DEBUG $self->execFromCmdLine("adb push busybox /system/bin");
	DEBUG $self->execFromCmdLine("adb shell sync");
	DEBUG $self->execFromCmdLine("adb shell chmod -R 777 /system/bin");
	DEBUG $self->execFromCmdLine("adb -s %1%  install -r com.wlan.wlanservice_jb.apk");

	# unlock the device.
	DEBUG $self->execFromCmdLine("adb shell input keyevent 82");
	# Enable Services.
	DEBUG $self->execFromCmdLine("adb shell svc wifi enable");
	DEBUG $self->execFromCmdLine("adb shell am start -a android.intent.action.MAIN -n com.android.phonesettings/.PhonesettingsActivity -e lcd 1");
	#DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 82");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	sleep 3;
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 20");
	DEBUG $self->execFromCmdLine("adb shell input keyevent 66");

	# go back to pwd.
	chdir($pwd);
	return 1;
}

sub isInstallerRunning {
	my ($self, %param) = @_;
	return -128;
}

sub setFlashMode {
	return -128;
}

1;

__END__

=head1 NAME

  Sta::Install::Nl80211Installer  - API for Atheros Client Installation Program Automation


=head1 SYNOPSIS

  use Sta;

  my $sta =  Sta -> new ( VENDOR       =>    "Atheros",
			  CONTROL_IP   =>    "10.10.7.10",
			  DEVICE_IP    =>    "10.10.8.50",
			  SUPPLICANT   =>    "ACU"
			);

  $sta -> installAppDriver( BUILD_PATH => "C:\\DUT\\Setup.exe",
			    INSTALL_FOLDER => "C:\\Program Files\\Atheros",
			    NOGINA => 1,
			  );

=head1 DESCRIPTION

  This module provides API to install client utilties and driver for Atheros Wireless LAN adapters.

=head1 DEPENDENCY

  This module internally uses

      Perl Win32-GuiTest (1.50.3 - ad and above)
      AthGuiTest (Wrapper around Perl GUI Test)
      Log4perl   (Perl logging framework)


=head1 API

  The API of Sta::Install::Nl80211Installer itself is extremely simple to allow
  you to get going almost immediately.


=head2 new()

=over

=item * CONTROL_IP (Required)

  Control interface IP Address on the remote station

=item * VENDOR (Required)

  Vendor of the wireless card plugged into the remote station

=item * SUPPLICANT (Required)

  Supplicant (installed on the remote side) to use when configuring the remote station.
  This is only required when you have to use any Supplicant's APIs.

=item Usage:

  my $sta =  Sta -> new ( VENDOR       =>    "Atheros",
			  CONTROL_IP   =>    "10.10.7.10",
			  DEVICE_IP    =>    "10.10.8.50",
			  SUPPLICANT   =>    "ACU"
			);

=back

=head2 installAppDriver()

  This will perform complete Atheros Client Utiltiy and Driver installation.
  Parameters you can use are:

  BUILD_PATH,
  INSTALL_FOLDER,
  STARTMENU,
  ENABLE_ASTU,
  NOGINA,

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed then it will look for setup.exe in the current working
  directory. It is very much recommended that you specify the BUILD_PATH.

=item * INSTALL_FOLDER

  INSTALL_FOLDER option allows you to specify the location where you want to install the
  Atheros Client Utilities. This is optional.

=item * STARTMENU

  STARTMENU option allows you to specify the windows start menu name. This is
  optional.

=item * NOGINA

  NOGINA option allows you choose the 'AthGina' installation. It accepts boolean values.
  if it is set to '1', the installer will not install 'AthGina'.


=item Usage:

	       $sta->installAppDriver(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		      INSTALL_FOLDER => "C:\\Program Files\\Atheros",
		      STARTMENU => "Atheros",
		      NOGINA => 1,
		  );

=back

=head2 installZeroConfig()

  This will perform complete Atheros Client Utilties and Driver installation
  and selects Wireless Zero Configuration as the configuration tool.

  Parameters you can use are:

  BUILD_PATH,
  INSTALL_FOLDER,
  STARTMENU,
  ENABLE_ASTU,

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed then it will look for setup.exe in the current working
  directory. It is very much recommended that you specify the BUILD_PATH.

=item * INSTALL_FOLDER

  INSTALL_FOLDER option allows you to specify the location where you want to install the
  Atheros Client Utilities. This is optional.

=item * STARTMENU

  STARTMENU option allows you to specify the windows start menu name. This is
  optional.

=item * ENABLE_ASTU

  ENABLE_ASTU option allows you to enable or disable Atheros System Tray Utility during
  the zeroConfigInstall. It accepts boolean values. 1- enable ASTU, 0- Disable ASTU
  ASTU will not be selected by default in the zeroConfigInstall.

=item Usage:

	       $sta->installZeroConfig(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		      INSTALL_FOLDER => "C:\\Program Files\\Atheros",
		      STARTMENU => "Atheros",
		      ENABLE_ASTU => 1,
		  );

=back

=head2 installDriver()

  This will perform driver only install from Atheros Client Installation Program.
  Parameters you can use are:

  BUILD_PATH,

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed then it will look for setup.exe in the current working
  directory. It is very much recommended that you specify the BUILD_PATH.


=item Usage:

	       $sta->installDriver(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		  );

=back

=head2 makeDisk()

  This will creates Atheros driver installation diskette in the given location.

  Parameters you can use are:

  BUILD_PATH,
  INSTALL_FOLDER

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed then it will look for setup.exe in the current working
  directory. It is very much recommended that you specify the BUILD_PATH.

=item * INSTALL_FOLDER

  INSTALL_FOLDER option allows you to specify the location where you want to create
  the Atheros driver diskette(s).

=item Usage:

	       $sta->makeDisk(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		      INSTALL_FOLDER => "C:\\AthDriver",
		  );

=back


=head2 updateInstall()

  This will update the previous Atheros Client Installation.
  Parameters you can use are:

  BUILD_PATH,

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed, this will get the BUILD_PATH from add/remove programs
  automatically.

=item Usage:

	       $sta->updateInstall(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		  );

=back


=head2 uninstallAppDriver()

  This will completely (both application and driver) remove the application
  and driver files.

  Parameters you can use are:

  BUILD_PATH,

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed, this will get the BUILD_PATH from add/remove programs
  automatically.

=item Usage:

	       $sta->uninstallAppDriver(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		  );

=back

=head2 uninstallAppOnly()

  This will remove the application files only and keeps the driver files.

  Parameters you can use are:

  BUILD_PATH,

=over

=item * BUILD_PATH

  The BUILD_PATH option allows you to pass location where the setup.exe located.
  If this is not passed, this will get the BUILD_PATH from add/remove programs
  automatically.

=item Usage:

	       $sta->uninstallAppOnly(
		      BUILD_PATH => "C:\\DUT\\Setup.exe",
		  );

=back

=head2 getUninstallerPath()

  This will return the uninstaller location (setup.exe) if there is a previous
  installation is detected.

=over

=item * Usage:

 	my $uninstaller_path = $sta->getUninstallerPath();

=back


=head1 AUTHORS

Nagarajan Murugesan <F<nagarajan@atheros.com>>

=head1 COPYRIGHT

Copyright (C) 2005 Atheros Communications, Inc. All rights reserved.

=cut

