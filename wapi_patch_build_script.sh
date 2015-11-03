#!/bin/sh

# This will fetch the wapi patch from //source/qcom/qct/wconnect/wlan/qnx/svc/external/wapi_patches/ to qnx_ap/src/lib/wpa_supplicant
# Apply the patch before the wapi build for timely builds
# Date Modified : 2/6/2015
# Author : Abhimanyu Bishnoi

DATE=$(date) 
HOST=$(hostname)
PATCH_LABEL=IN_FUTURE_WE_MAY_GO_WITH_A_LABEL
WAPI_PATCH=WAPI_supplicant_changes_on_QNX.patch
WAPI_P4_PATCH=//source/qcom/qct/wconnect/wlan/qnx/svc/external/wapi_patches/${WAPI_PATCH}


echo "INFO: Patch_Synced_Date : $DATE"
echo "INFO: Host : $HOST"

echo "INFO: ===== ENV ====="
env | tee /tmp/env.txt
echo "INFO: ===== ENV ====="

#get into wpa_supplicant folder
pushd qnx_ap/src660/lib/wpa_supplicant 
pwd

echo "FETCHING: $WAPI_P4_PATCH now"
# Retrieve the wapi patch from perforce into the wpa_supplicant folder
p4 -p qctp411:1666 -u pwbldsvc -P A214E6FB80F216DD5A2475C1105DA010 print -o $WAPI_PATCH -q $WAPI_P4_PATCH
if [ $? -eq 0 ]; then
	echo "INFO: Patch retrieved succesfully"
else
	echo "ERROR: Patch could not be retrieved !"
	exit 1
fi

echo "APPLYING: $WAPI_PATCH now"
# Run the patch command
patch -p1< WAPI_supplicant_changes_on_QNX.patch
if [ $? -eq 0 ]; then
	echo "INFO: Patch appiled succesfully"
else
	echo "ERROR: Patch application failed !" 1>&2
	exit 1
fi

# pop back to the CRM root
popd
pwd

# Execute build command
cd qnx_ap
pwd
bash bldqnx.sh
