ARG ERIC_ENM_SLES_BASE_SCRIPTING_IMAGE_NAME=eric-enm-sles-base-scripting
ARG ERIC_ENM_SLES_BASE_SCRIPTING_IMAGE_REPO=armdocker.rnd.ericsson.se/proj-enm
ARG ERIC_ENM_SLES_BASE_SCRIPTING_IMAGE_TAG=1.64.0-33
FROM ${ERIC_ENM_SLES_BASE_SCRIPTING_IMAGE_REPO}/${ERIC_ENM_SLES_BASE_SCRIPTING_IMAGE_NAME}:${ERIC_ENM_SLES_BASE_SCRIPTING_IMAGE_TAG} AS production

ARG BUILD_DATE=unspecified
ARG IMAGE_BUILD_VERSION=unspecified
ARG GIT_COMMIT=unspecified
ARG ISO_VERSION=unspecified
ARG RSTATE=unspecified

ARG JBOSS_HOME=/ericsson/3pp/jboss

LABEL \
com.ericsson.product-number="CXC 174 2128" \
com.ericsson.product-revision=$RSTATE \
enm_iso_version=$ISO_VERSION \
org.label-schema.name="ENM Fileaccount Service Group" \
org.label-schema.build-date=$BUILD_DATE \
org.label-schema.vcs-ref=$GIT_COMMIT \
org.label-schema.vendor="Ericsson" \
org.label-schema.version=$IMAGE_BUILD_VERSION \
org.label-schema.schema-version="1.0.0-rc1"

COPY --chown=jboss_user:jboss image_content/ /var/tmp/

RUN rpm -e --nodeps ERICcredentialmanagercli_CXP9031389 || echo "No ERICcredentialmanagercli_CXP9031389 installed"

RUN zypper install -y \
    ERICmediationengineapi2_CXP9038435 \
    ERICdpsmediationclient2_CXP9038436 \
    ERICdpsruntimeimpl_CXP9030468 \
    ERICpib2_CXP9037459 \
    ERICdpsruntimeapi_CXP9030469 \
    ERICcryptographyservice_CXP9031013 \
    ERICcryptographyserviceapi_CXP9031014 \
    ERICsmrsservice_CXP9030755 \
    ERICpostgresqljdbc_CXP9031176 \
    ERICeciminstantlicenserequesthandler_CXP9037767 \
    ERICnfvoswpackageprovider_CXP9034649 && \
    zypper download ERICenmsgfileaccountservice_CXP9041679 && \
    rpm -ivh --replacefiles /var/cache/zypp/packages/enm_iso_repo/ERICenmsgfileaccountservice_CXP9041679*.rpm --nodeps --noscripts && \
    zypper clean -a

# Old script to enable ipv6 direct routing in pENM (TORF-152795), not needed in CN
RUN rm -f /ericsson/3pp/jboss/bin/pre-start-with-exit/enable_direct_routing.sh

# TD: remove unsupported Ciphers and MACs from SSH config
RUN sed -i.bak "s/blowfish-cbc,// ; s/cast128-cbc,// ; s/hmac-ripemd160,// ; s/hmac-ripemd160@openssh.com,//" /etc/ssh/sshd_config && \
    sed -i.bak "s/blowfish-cbc,// ; s/cast128-cbc,// ; s/hmac-ripemd160,// ; s/hmac-ripemd160@openssh.com,//" /etc/ssh/ssh_config

COPY image_content/createCertificatesLinks.sh /ericsson/3pp/jboss/bin/pre-start/createCertificatesLinks.sh
COPY image_content/updateCertificatesLinks.sh /ericsson/3pp/jboss/bin/pre-start/updateCertificatesLinks.sh

RUN /bin/chown jboss_user:jboss /ericsson/3pp/jboss/bin/pre-start/updateCertificatesLinks.sh && \
    /bin/chmod 755 /ericsson/3pp/jboss/bin/pre-start/updateCertificatesLinks.sh

# TORF-537452 : TEMP to remove when script that restarts mediation PODS in CIS-149159 will be fixed
COPY image_content/credentialmanagercliRestartVM.sh /usr/lib/ocf/resource.d/credentialmanagercliRestartVM.sh
RUN mkdir -p -m 777 /opt/ericsson/ERICcredentialmanagercli && chmod 755 /usr/lib/ocf/resource.d/credentialmanagercliRestartVM.sh

RUN /bin/chown jboss_user:jboss /ericsson/3pp/jboss/bin/pre-start/createCertificatesLinks.sh && \
    /bin/chmod 755 /ericsson/3pp/jboss/bin/pre-start/createCertificatesLinks.sh

# to make createCertificatesLinks.sh script work
RUN /bin/mkdir -p /ericsson/credm/data/certs && \
    /bin/chown -R jboss_user:jboss /ericsson/credm/data/certs && \
    /bin/chmod -R 755 /ericsson/credm/data/certs

RUN chmod 755 /home

COPY --chown=jboss_user:jboss image_content/cron_config.sh $JBOSS_HOME/bin/post-start/

RUN systemctl disable sg-post-startup

ENV ENM_JBOSS_SDK_CLUSTER_ID="fileaccountservice" \
    ENM_JBOSS_BIND_ADDRESS="0.0.0.0" \
    GLOBAL_CONFIG="/gp/global.properties" \
    SG_STARTUP_SCRIPT="/var/tmp/smrsserv_config.sh" \
    JBOSS_CONF="$JBOSS_HOME/app-server.conf" \
    CLOUD_NATIVE_DEPLOYMENT="true"

RUN rm -rf /ericsson/3pp/jboss/bin/post-start/clear_cache.sh && \
    rm -rf /ericsson/3pp/jboss/bin/post-start/clear_cache_config.sh

EXPOSE 1636 4320 4447 7999 8080 8085 8445 9990 9999 12987 2701

## used only for internal development, created
## temporary change for the development
## so all logs of jboss and core services are logged into /var/log/messages

#FROM production AS development
#RUN zypper install -y vim && zypper clean --all && echo "alias ll='ls -laF'" > /root/.bashrc
