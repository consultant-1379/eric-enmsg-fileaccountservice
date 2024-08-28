#!/bin/bash

###########################################################################
# COPYRIGHT Ericsson 2023
#
# The copyright to the computer program(s) herein is the property of
# Ericsson Inc. The programs may be used and/or copied only with written
# permission from Ericsson AB. or in accordance with the terms and
# conditions stipulated in the agreement/contract under which the
# program(s) have been supplied.
###########################################################################

BASENAME=/bin/basename
SCRIPT_NAME="${BASENAME} ${0}"
LOG_TAG="Fileaccountservice_Configuration"
RMRF="/bin/rm -rf"

#//////////////////////////////////////////////////////////////
# This function will print an error message to /var/log/messages
# Arguments:
#       $1 - Message
# Return: 0
#//////////////////////////////////////////////////////////////
error() {
    logger -t ${LOG_TAG} -p user.err "ERROR ( ${SCRIPT_NAME} ): $1"
}

#//////////////////////////////////////////////////////////////
# This function will print an info message to /var/log/messages
# Arguments:
#       $1 - Message
# Return: 0
#//////////////////////////////////////////////////////////////
info() {
    logger -t ${LOG_TAG} -p user.notice "INFO ( ${SCRIPT_NAME} ): $1"
}

#//////////////////////////////////////////////////////////////
# remove unwanted cron entries.
#//////////////////////////////////////////////////////////////
__remove_unwanted_cron_entries() {
declare -a arr=("/etc/cron.d/ldap_statuscheck" "/etc/cron.d/tmpcleanup")
for i in ${arr[@]}
do
   if [ -e $i ]; then
     $RMRF $i
     info "Removed $i script from cron"
   else
     info "File $i doesn't exist"
   fi
done
}

#//////////////////////////////////////////////////////////////
# Main program.
#//////////////////////////////////////////////////////////////

__remove_unwanted_cron_entries

exit 0











