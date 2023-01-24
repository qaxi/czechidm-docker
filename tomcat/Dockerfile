# mirrored standard centos:7 image
# FROM repo.iamappliance.com:8443/centos:7
FROM centos:centos7

ENV TOMCAT_MAJOR 9
ENV TOMCAT_VERSION 9.0.62
# https://downloads.apache.org/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.sha512
ENV TOMCAT_SHA512 179af1d50a7d330d0842d3f1cae086bbc1b20e8f6752d66500663f3ac71d80f50113bbd29931e21c8e2eccd982f9f872e193364311316fdd67349130d440c83f
# https://downloads.apache.org/tomcat/tomcat-9/KEYS
ENV TOMCAT_GPG_KEYS DCFD35E0BF8CA7344752DE8B6FB21E8933C60243 A9C5DF4D22E99998D9875A5110C01C5A2F6059E7 48F8E69F6390C9F25CFEDCD268248959359E722B

ENV RUNSCRIPTS_PATH /runscripts
ENV TOMCAT_HOME /opt/tomcat
ENV TOMCAT_TRUSTSTORE /opt/tomcat/truststore

# to correct "POSIX" locales to "en_US.UTF-8" globally
ENV LANG en_US.UTF-8

RUN yum install -y epel-release && \
		yum install -y deltarpm && \
		yum update -y && \
		yum install -y wget psmisc sudo java-11-openjdk-headless java-11-openjdk-devel xmlstarlet openssl && \
		yum clean all

# The ddist() function is copied from
# https://github.com/docker-library/tomcat/blob/807a2b4f219d70f5ba6f4773d4ee4ee155850b0d/8.5/jdk8/openjdk/Dockerfile
# and stripped off PGP check. The ddist() code is under Apache License 2.0.
RUN mkdir -v /opt/tomcat && \
		ddist() { \
		local f="$1"; shift; \
		local distFile="$1"; shift; \
		local success=; \
		local distUrl=; \
		for distUrl in \
			https://dlcdn.apache.org/ \
			https://www.apache.org/dist/ \
			https://archive.apache.org/dist/ \
		; do \
				if wget -O "$f" "$distUrl$distFile" && [ -s "$f" ]; then \
					success=1; \
					break; \
				fi; \
			done; \
			[ -n "$success" ]; \
		}; \
		\
		# download tomcat and check the sha-512
		# this also servers as a replacement for PGP checking becuase PGPs are currently broken on the Tomcat side
		ddist "$TOMCAT_HOME/apache-tomcat-$TOMCAT_VERSION.tar.gz" "tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"; \
		echo "$TOMCAT_SHA512 $TOMCAT_HOME/apache-tomcat-$TOMCAT_VERSION.tar.gz" | sha512sum --strict --check -; \
		\
		# download asc file and check signatures - presently, this is broken on Tomcat side, so we fall back
		# to manual check of downloaded tomcat and adjusting the sha-512 check
		#ddist "$TOMCAT_HOME/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc" "tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc"; \
		#export GNUPGHOME="$(mktemp -d)"; \
		#for key in $TOMCAT_GPG_KEYS; do \
		#	gpg --batch --keyserver pgpkeys.mit.edu --recv-keys "$key"; \
		#done; \
		#gpg --batch --verify "$TOMCAT_HOME/apache-tomcat-$TOMCAT_VERSION.tar.gz.asc" "$TOMCAT_HOME/apache-tomcat-$TOMCAT_VERSION.tar.gz"; \
		#command -v gpgconf && gpgconf --kill all || :; \
		#rm -rf "$GNUPGHOME"; \
		\
		cd /opt/tomcat && \
		tar xzvf "apache-tomcat-$TOMCAT_VERSION.tar.gz" && \
		ln -sv "apache-tomcat-$TOMCAT_VERSION" current && \
		rm "apache-tomcat-$TOMCAT_VERSION.tar.gz"

# Adjust Tomcat settings that should not be changeable through container configuration.
RUN xmlstarlet ed -L \
			# add RemoteIpValve so Tomcat correctly works behind a proxy
			-s 'Server/Service/Engine' -t elem -n 'Valve' -v 'valvetobeconfigured' \
			-a "//Valve[text()='valvetobeconfigured']" -t attr -n 'className' -v 'org.apache.catalina.valves.RemoteIpValve' \
			-a "//Valve[text()='valvetobeconfigured']" -t attr -n 'remoteIpHeader' -v 'X-Forwarded-For' \
			-a "//Valve[text()='valvetobeconfigured']" -t attr -n 'protocolHeader' -v 'X-Forwarded-Proto' \
			-a "//Valve[text()='valvetobeconfigured']" -t attr -n 'hostHeader' -v 'X-Forwarded-Host' \
			# finally, delete the placeholder
			-u "//Valve[text()='valvetobeconfigured']" -v "" \
			"$TOMCAT_HOME/current/conf/server.xml"

RUN groupadd -r -g 998 tomcat && \
		useradd -r -u 999 -s /sbin/nologin -g tomcat -d /opt/tomcat tomcat && \
		getent passwd tomcat && \
		\
		chown -R root:root /opt/tomcat && \
		chown root:tomcat /opt/tomcat && \
		chmod 750 /opt/tomcat && \
		cd /opt/tomcat/current && \
		chmod o+rX -R ./ && \
		chgrp -R tomcat conf/ bin/ lib/ && \
		chmod g+rwx conf && \
		chmod g+r conf/* && \
		chown -R tomcat webapps/ work/ temp/ logs/ && \
		\
		mkdir -pv "$RUNSCRIPTS_PATH" \
		mkdir -pv "$TOMCAT_TRUSTSTORE/certs"

COPY runscripts "$RUNSCRIPTS_PATH/"
RUN find "$RUNSCRIPTS_PATH/" -name "*.sh" -exec chmod -v u+x {} \;

COPY dropin/tomcat-stdout-accesslog*.jar /opt/tomcat/current/lib/

CMD ["/bin/bash","-c","$RUNSCRIPTS_PATH/run.sh"]

EXPOSE 8009/tcp
EXPOSE 8080/tcp

# This is for documentation purposes only and intentionally commented-out.
# If enabled, it effectively disallows downstream Dockerfiles to modify contents
# of those directories during image build phase.
#VOLUME ["/opt/tomcat/current/webapps"]
#VOLUME ["/opt/tomcat/current/logs"]
