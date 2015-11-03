#!/bin/bash

######################################################################
#
# This is a standalone script wlan driver module build script
# intended to be launched when a pre-built AU kernel dir is
# present. This builds wlan.ko for $TARGET using $MY_AU_DIR AU
#
# CONTACT: QCA.SW.CBI.TEAM|Abhimanyu|Prakash
# Wiki: http://qwiki.qualcomm.com/qca_wcnss/QCA-CBI/Build_LA_Kernel_Module
#
# $Id: //depot/software/swbuild/bin/la_integ/utils/mybuild_msm8994.sh#2 $
# $DateTime: 2014/09/18 01:15:26 $
# $Author: abishnoi $
#
# Usage:
# $0 [<make-arguments>]
#
# NOTE: MY_AU_DIR or MY_KERNELROOT or MY_MAKE_ARGS or MY_MODNAME
# NOTE: MY_MAKEFILE_MODULE override default settings below if given
#
# NOTE: This works both in US and QIPL Sites where AU's exist
#
######################################################################

TARGET="msm8994"
CURRENT_AU=${MY_AU:-"AU_LINUX_ANDROID_REDFOX64.04.04.02.160.135"}

#!!!!!!!!!!!!!!!!  DON'T modify anything after this line !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#

















START_TIME="$(date '+%D %T')"
PRECO_WIKI="http://qwiki.qualcomm.com/qca_wcnss/QCA-CBI/Build_LA_Kernel_Module"
# Use predefined AU workspace dirs. If none can be found at standard paths
# User can override by setting MY_AU_DIR to AU Root dir or set MY_KERNELROOT
AU_DIR_US="/prj/qca/swcbi/santaclara/dev02/sw_build/Engineering/workspace/PreCommit/AU/${TARGET}"
AU_DIR_INDIA="/prj/qct/wcnss_builds/CBI/PreCommit/AU/${TARGET}"
AU_CONF_DIR="/prj/qca/swcbi/santaclara/dev02/sw_build/Engineering/workspace/PreCommit/AU/config/${TARGET}"
AU_LOGS_DIR="/prj/qca/swcbi/santaclara/dev02/sw_build/Engineering/workspace/PreCommit/AU/logs/session"
MAKEFILE_LOCATION="${AU_CONF_DIR}/Makefile_module"

NULL=${MY_NULL:-/dev/null}
MY_MAKE_ARGS=${MY_MAKE_ARGS:-$*}

if [ -d "$AU_DIR_US" ]; then
        AU_DIR_FOUND=${AU_DIR_US}
elif [ -d "$AU_DIR_INDIA" ]; then
        AU_DIR_FOUND=${AU_DIR_INDIA}
else
        echo "INFO: AU_DIR_US=$AU_DIR_US"
        echo "INFO: AU_DIR_INDIA=$AU_DIR_INDIA"
        echo "ERROR: No Pre-Requisite AU directory found from $HOSTNAME. Exiting"
        exit 1
fi

export AU_DIR=${MY_AU_DIR:-${AU_DIR_FOUND}}
export KERNELROOT=${MY_KERNELROOT:-${AU_DIR}/${CURRENT_AU}}

AU_NUMBER=$(basename $KERNELROOT)
export SESSION_LOG="${AU_LOGS_DIR}/mybuild_session_${TARGET}_L.log"

if [ -s "Makefile_module" ]
then

        MAKEFILE_LOCATION="Makefile_module"
        echo "INFO: Using local $MAKEFILE_LOCATION"

elif [ -s "$MAKEFILE_LOCATION" ];
then

        echo "INFO: Using remote $MAKEFILE_LOCATION"

else

        echo "ERROR: Custom Makefile_module is not accessible on $HOSTNAME"
        echo "ERROR: Please contact me <ksoni@qca.qualcomm.com>"
        exit 1

fi
MAKEFILE_MODULE=${MY_MAKEFILE_MODULE:-$MAKEFILE_LOCATION}

cd $KERNELROOT
echo "[$START_TIME] Starting Driver Build"
echo "CMD: source build/envsetup.sh && lunch ${TARGET}-eng"
source build/envsetup.sh && lunch ${TARGET}-eng

if [ "$TARGET_PRODUCT" == "" ]; then
        echo "ERROR:"
        echo "ERROR: source build/envsetup.sh FAILED on $HOSTNAME. Empty TARGET_PRODUCT value"
        echo "ERROR: Exiting"
        echo "ERROR:"
        exit 1
fi

cd -
echo "-------------------------------------------------"
echo make -j16 -f $MAKEFILE_MODULE \
        TARGET_OS=Android \
        KERNEL_DIR=$KERNELROOT/kernel \
        KERNEL_OUT=$KERNELROOT/out/target/product/$TARGET_PRODUCT/obj/KERNEL_OBJ \
        WLAN_ROOT=$PWD \
        MODNAME=${MY_MODNAME:-wlan} \
        WLAN_CHIPSET=qca_cld \
        WLAN_SELECT=m \
        CONFIG_QCA_CLD_WLAN=m \
        CONFIG_QCA_WIFI_ISOC=0 \
        CONFIG_QCA_WIFI_2_0=1 \
        ${MY_MAKE_ARGS}
echo "-------------------------------------------------"

make -j16 -f $MAKEFILE_MODULE \
        TARGET_OS=Android \
        KERNEL_DIR=$KERNELROOT/kernel \
        KERNEL_OUT=$KERNELROOT/out/target/product/$TARGET_PRODUCT/obj/KERNEL_OBJ \
        WLAN_ROOT=$PWD \
        MODNAME=${MY_MODNAME:-wlan} \
        WLAN_CHIPSET=qca_cld \
        WLAN_SELECT=m \
        CONFIG_QCA_CLD_WLAN=m \
        CONFIG_QCA_WIFI_ISOC=0 \
        CONFIG_QCA_WIFI_2_0=1 \
        ${MY_MAKE_ARGS}

make_exit_code=$?
END_TIME="$(date '+%D %T')"

if [ "$make_exit_code" != "0" ]; then
	MPFX="ERROR:"
else
	MPFX="INFO:"
fi

echo "[$END_TIME] Completed Driver Build"

echo "==============================================================="
echo "[$END_TIME] $MPFX: TARGET: $TARGET; USER: $USER@$HOSTNAME"
echo "[$END_TIME] $MPFX: AU: $AU_NUMBER; Exit Code '$make_exit_code'"
echo "[$END_TIME] $MPFX: USER_DIR: $PWD;"
echo "==============================================================="

echo "==============================================================="   >> $SESSION_LOG 2> $NULL
echo "[$END_TIME] $MPFX: TARGET: $TARGET; USER: $USER@$HOSTNAME"         >> $SESSION_LOG 2> $NULL
echo "[$END_TIME] $MPFX: AU: $AU_NUMBER; Exit Code '$make_exit_code'"    >> $SESSION_LOG 2> $NULL
echo "[$END_TIME] $MPFX: USER_DIR: $PWD;"                                >> $SESSION_LOG 2> $NULL
echo "==============================================================="   >> $SESSION_LOG 2> $NULL
chmod ugo+w $SESSION_LOG 2> $NULL

exit $make_exit_code

