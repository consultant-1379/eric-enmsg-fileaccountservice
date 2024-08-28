#!/bin/bash
###########################################################################
# COPYRIGHT Ericsson 2022
#
# The copyright to the computer program(s) herein is the property of
# Ericsson Inc. The programs may be used and/or copied only with written
# permission from Ericsson Inc. or in accordance with the terms and
# conditions stipulated in the agreement/contract under which the
# program(s) have been supplied.
###########################################################################

_me="[smrsserv][smrsserv_config.sh]"

# Variables for certificates handling
_certs_data_dir="/ericsson/cert/data/certs"
_certs_source_dir="/ericsson/enm/jboss/conf"
_certs_dest_dir="/ericsson/credm/data/xmlfiles"
_certs_smrsweb_file="SmrsWeb_CertRequest.xml"

_ECHO=/bin/echo
_SED=/bin/sed

GLOBAL_PROPERTIES_FILE=/ericsson/tor/data/global.properties

# This function replaces the tag <ipaddress> for the SAN field of the certificate. There could be
# an <ipaddress> for IPv4 and one for IPv6. If the IP adress value does not exist (or is empty), the tag <ipaddress>
# is removed from the Cert request file to avoid leaving it emtpy
#
# Function usage:
#     replace_ip_for_smrsweb_cert_req_file [IP_PLACEHOLDER] [IP_VERSION] [IP_ADDRESS]
# Where:
#   IP_PLACEHOLDER: Represents the value in the tag '<ipaddress>cm_VIP</ipaddress>' that will be replaced with an
#                   IP address. I.e. 'cm_VIP' in the preceding example.
#   IP_VERSION: The string 'IPv4' or 'IPv6' identifies which IP version is being processed.
#   IP_ADDRESS: The IP address, if provided for the specified IP_VERSION, that will take the place of the
#               IP_PLACEHOLDER. If an IP_ADDRESS is not provided for the specified IP_VERSION, the
#               '<ipaddress>' tag will be removed from the cert request file.
function replace_ip_for_smrsweb_cert_req_file() {
    ip_placeholder="$1"
    ip_version="$2"
    ip_address="$3"
    if [ ! -z "$ip_address" ]; then
		sed -i -e "s/$ip_placeholder/$ip_address/g" "$_certs_source_dir/$_certs_smrsweb_file"
	        logger -p user.info "[INFO]: Successfully replaced CM $ip_version VIP with value: '$ip_address' in cert request file: \
'$_certs_source_dir/$_certs_smrsweb_file'"
        return 0
    else
		logger -p user.warn "[WARNING]: Failed to replace CM $ip_version VIP. Value seems to be blank. \
Tag '<ipaddress>' for SAN field will be removed from cert request file: '$_certs_source_dir/$_certs_smrsweb_file'"
		sed -i -e "s/<ipaddress>$ip_placeholder<\/ipaddress>//g" "$_certs_source_dir/$_certs_smrsweb_file"
        return 1
    fi
}

# Resolves the CM VIPs for IPv4 and IPv6 from /ericsson/tor/data/global.properties file and replaces them in
# the file SmrsWeb_CertRequest.xml to make subject alternative names available in the certificate request.
#
# The inputs from global.properties are formatted with cut to handle the following scenarios:
# 1) Multiple values in the properties 'svc_CM_vip_ipaddress' and 'svc_CM_vip_ipv6address'. In this case, only
# the first value will be considered significant (multiple values are assumed to be comma-separated and containing
# no blanks)
# 2) IP addresses in CIDR notation to specify the subnet mask
function resolve_cm_vip_and_copy_cert_for_smrsweb() {

    if [ -f $GLOBAL_PROPERTIES_FILE ]
    then
        logger -p user.info "[INFO]: global.properties found. Extracting CM VIP for IPv4 and IPv6 VIP"
            CM_VIP_IPV4=$(grep svc_CM_vip_ipaddress $GLOBAL_PROPERTIES_FILE | cut -d '=' -f2)
            CM_VIP_IPV6=$(grep svc_CM_vip_ipv6address $GLOBAL_PROPERTIES_FILE | cut -d '=' -f2)
            cm_VIP=$(echo ${CM_VIP_IPV4} | cut -d ',' -f1 | cut -d '/' -f1 | xargs echo -n)
            cm_ipv6_VIP=$(echo ${CM_VIP_IPV6} | cut -d ',' -f1 | cut -d '/' -f1 | xargs echo -n)

            replace_ip_for_smrsweb_cert_req_file "cm_VIP" "IPv4" "$cm_VIP"
            ipv4_replacement_result=$?

            replace_ip_for_smrsweb_cert_req_file "cm_ipv6_VIP" "IPv6" "$cm_ipv6_VIP"
            ipv6_replacement_result=$?

            if [ $ipv4_replacement_result == 0 ] || [ $ipv6_replacement_result == 0 ] ; then
                cp $_certs_source_dir/$_certs_smrsweb_file $_certs_dest_dir
                logger -p user.info "[INFO]: Cert request file '$_certs_source_dir/$_certs_smrsweb_file' was copied to destination \
directory '$_certs_dest_dir'"
            else
                logger -p user.err "[ERROR]: Failed to replace at least one CM VIP for cert request. Cert request file \
'$_certs_source_dir/$_certs_smrsweb_file' will not be copied to destination directory '$_certs_dest_dir'"
            fi
    else
        logger -p user.err "[ERROR]: global.properties file not found. Could not replace IPv4 or IPv6 in cert request file \
'$_certs_source_dir/$_certs_smrsweb_file'"
    fi
}

logger "Create directory '$_certs_dest_dir' for storing xml files"
if [ ! -e "$_certs_dest_dir" ]; then
   mkdir -p "$_certs_dest_dir"
fi

logger "Create directory '$_certs_data_dir' for storing certificates"
if [ ! -e "$_certs_data_dir" ]; then
   mkdir -p "$_certs_data_dir"
fi

resolve_cm_vip_and_copy_cert_for_smrsweb

logger "SmrsService config completed"


exit 0
