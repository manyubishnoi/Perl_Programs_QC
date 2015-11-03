#! /bin/bash
#
# This is generic script to run KW on different project combinations
#
# $Id: //depot/software/swbuild/bin/la_integ/utils/kw_scan.sh#5 $
# $DateTime: 2015/10/27 21:43:51 $
# $Author: abishnoi $

export PATH=$PATH:/prj/qct/asw/StaticAnalysis/Linux/Klocwork/User/bin
kwserver=${kwserver:-"https://kwdbprod07.qualcomm.com:8070"}

function usage
{
   echo "Usage  : $0 -b <build-cmd> -d <kw-scan-dir> -p <kw-project> -s <kw-server>"
   echo "     -b: Build Command for current target"
   echo "     -d: Dir to scan"
   echo "     -h: Show this help"
   echo "     -p: KW Project to run against"
   echo "     -s: KW Server"
   echo ""
   echo "Pre-requities to run on unix cmd line:"
   echo "\$ export PATH=\$PATH:/prj/qct/asw/StaticAnalysis/Linux/Klocwork/User/bin"
   echo "\$ kwauth --url ${kwserver}"
   echo ""

   echo "Examples:"
   echo " * Scan Prima MSM 8974 for opensource"
   echo "   $0 -b msm8974-userdebug -d vendor/qcom/opensource/wlan/prima -p CI_LNX_LA_0_0 -s https://kwdbprod07.qualcomm.com:8070"
   echo " * Scan QCACLD-2.0 MSM 8994 for opensource"
   echo "   $0 -b msm8994-userdebug -d vendor/qcom/opensource/wlan/qcacld-2.0 -p CI_LNX_LA_0_0 -s https://kwdbprod07.qualcomm.com:8070"
   echo " * Scan QCACLD-2.0 APQ 8084 for opensource"
   echo "   $0 -b apq8084-userdebug -d vendor/qcom/opensource/wlan/qcacld-2.0 -p CI_LNX_LA_3_6 -s https://kwdbprod07.qualcomm.com:8070"
   echo " * Scan QCACLD-3.0 MSM 8994 for proprietary"
   echo "   $0 -b msm8994-userdebug -d vendor/qcom-proprietary/wlan-noship/qcacld-new -p CI_LA_BF64_0_3_8X94_1 -s https://kwdbprod18.qualcomm.com:8070"

   exit 0
}

while getopts "b:d:hp:s:" arg; do
  case $arg in
    b)
      buildcmd="$OPTARG"
      echo "INFO: Build Cmd: $buildcmd"
      ;;  
    d)
      kwscandir="$OPTARG"
      echo "INFO: KW Scan Dir: $kwscandir"
      ;;  
    h)  
      usage;
      ;;  
    p)  
      kwproject="$OPTARG"
      echo "INFO: KW Project Name: $kwproject"
      ;;  
    s)  
      kwserver="$OPTARG"
      echo "INFO: KW Server: $kwserver"
      ;;  
    :)
        echo "Option -$OPTARG requires an argument"
        usage
    ;;
  esac
done
shift $((OPTIND-1))

if [ -f "build/envsetup.sh" ]; then
	echo "INFO: source build/envsetup.sh"
	source build/envsetup.sh
else
	echo ""
	echo "ERROR: Missing 'build/envsetup.sh'. Exiting with error"
	echo "ERROR: You need to run this script in AU workspace context"
	echo ""
	exit 1
fi

# Defaults if paths are not specified. All args need to EXACTLY match
buildcmd=${buildcmd:-"lunch msm8994-userdebug"}
kwproject=${kwproject:-"CI_LNX_LA_0_0"}
kwscandir=${kwscandir:-"vendor/qcom/opensource/wlan/qcacld-2.0"}

# must run the following before you run this script:
# kwauth --url ${kwserver}

if [ ! -d .kwlp ]
then
    echo "kwcheck create --url ${kwserver}/${kwproject}"
    kwcheck create --url ${kwserver}/${kwproject}
    echo "kwcheck create exit code: $?"

    echo "kwcheck import /prj/qct/asw/StaticAnalysis/public/${kwproject}/${kwproject}.tpl"
    kwcheck import /prj/qct/asw/StaticAnalysis/public/${kwproject}/${kwproject}.tpl
    echo "kwcheck import exit code: $?"
fi

kwcheck set-var PROJECTROOT=`pwd`
kwcheck set-var MYROOT=`pwd`

echo "kwcheck run $kwscandir"
kwcheck run $kwscandir
echo "kwcheck run exit code: $?"

echo "kwcheck list --local --system -F detailed $kwscandir"
kwcheck list --local --system -F detailed $kwscandir
echo "kwcheck list exit code: $?"

