#!/bin/bash
echo "[$0] Updating IdM application configuration...";

if [ ! -z "${DOCKER_SKIP_IDM_CONFIGURATION+x}" ]; then
  echo "[$0] The DOCKER_SKIP_IDM_CONFIGURATION is defined, skipping this script.";
  exit;
fi

cd "$CZECHIDM_CONFIG/etc";

cp "$CZECHIDM_BUILDROOT/product/application-docker.TPL.properties" application-docker.properties;

# Take variables that were set and (re)place them in the config file.

# APP CONFIG
if [ -z "${CZECHIDM_APP_INSTANCEID}" ]; then
  echo "[$0] CZECHIDM_APP_INSTANCEID not set, using default from the template.";
else
  sed -i "s/idm.pub.app.instanceId.*/idm.pub.app.instanceId=$CZECHIDM_APP_INSTANCEID/" application-docker.properties;
fi
if [ -z "${CZECHIDM_APP_STAGE}" ]; then
  echo "[$0] CZECHIDM_APP_STAGE not set, using default from the template.";
else
  sed -i "s/idm.pub.app.stage.*/idm.pub.app.stage=$CZECHIDM_APP_STAGE/" application-docker.properties;
fi

# DATABASE CONFIG IdM data
if [ -z "${CZECHIDM_DB_URL}" ]; then
  echo "[$0] CZECHIDM_DB_URL not set, using default from the template - EMPTY!!!.";
else
  sed -i "s#spring.datasource.jdbcUrl.*#spring.datasource.jdbcUrl=$CZECHIDM_DB_URL#" application-docker.properties;
  sed -i "s#spring.logging-datasource.jdbcUrl.*#spring.logging-datasource.jdbcUrl=$CZECHIDM_DB_URL#" application-docker.properties;
fi

if [ -z "${CZECHIDM_DB_USER}" ]; then
  echo "[$0] CZECHIDM_DB_USER not set, using default from the template - EMPTY!!!.";
else
  sed -i "s/spring.datasource.username.*/spring.datasource.username=$CZECHIDM_DB_USER/" application-docker.properties;
  sed -i "s/spring.logging-datasource.username.*/spring.logging-datasource.username=$CZECHIDM_DB_USER/" application-docker.properties;
fi

if [ -z "${CZECHIDM_DB_PASSFILE}" ]; then
  echo "[$0] CZECHIDM_DB_PASSFILE not set, using default from the template - EMPTY!!!.";
else
  if [ -f "${CZECHIDM_DB_PASSFILE}" ]; then
    dbpass=$(cat "$CZECHIDM_DB_PASSFILE");
    sed -i "s#spring.datasource.password.*#spring.datasource.password=$dbpass#" application-docker.properties;
    sed -i "s#spring.logging-datasource.password.*#spring.logging-datasource.password=$dbpass#" application-docker.properties;
  else
    echo "[$0] CZECHIDM_DB_PASSFILE not readable, using default password from the template - EMPTY!!!.";
  fi
fi

if [ -z "${CZECHIDM_DB_DRIVERCLASS}" ]; then
  echo "[$0] CZECHIDM_DB_DRIVERCLASS not set, using default from the template - EMPTY!!!.";
else
  sed -i "s/spring.datasource.driver-class-name.*/spring.datasource.driver-class-name=$CZECHIDM_DB_DRIVERCLASS/" application-docker.properties;
  sed -i "s/spring.logging-datasource.driver-class-name.*/spring.logging-datasource.driver-class-name=$CZECHIDM_DB_DRIVERCLASS/" application-docker.properties;
fi

if [ -z "${CZECHIDM_DB_POOL_SIZE}" ]; then
  echo "[$0] CZECHIDM_DB_POOL_SIZE not set, using default from the template";
else
  db_pool=$(echo "$CZECHIDM_DB_POOL_SIZE * 0.95" | bc -q | cut -f1 -d".")
  lg_pool=$(echo "$CZECHIDM_DB_POOL_SIZE * 0.05" | bc -q | cut -f1 -d".")
  sed -i "s#spring.datasource.maximumPoolSize.*#spring.datasource.maximumPoolSize=$db_pool#" application-docker.properties;
  sed -i "s#spring.logging-datasource.maximumPoolSize.*#spring.logging-datasource.maximumPoolSize=$lg_pool#" application-docker.properties;
fi

# DATABASE CONFIG IdM reports
if [ -z "${CZECHIDM_REPORTS_DB_URL}" ]; then
  echo "[$0] CZECHIDM_REPORTS_DB_URL not set, using default from the template - EMPTY!!!.";
else
  sed -i "s#spring.reports-datasource.jdbcUrl.*#spring.reports-datasource.jdbcUrl=$CZECHIDM_REPORTS_DB_URL#" application-docker.properties;
fi

if [ -z "${CZECHIDM_REPORTS_DB_USER}" ]; then
  echo "[$0] CZECHIDM_REPORTS_DB_USER not set, using default from the template - EMPTY!!!.";
else
  sed -i "s/spring.reports-datasource.username.*/spring.reports-datasource.username=$CZECHIDM_REPORTS_DB_USER/" application-docker.properties;
fi

if [ -z "${CZECHIDM_REPORTS_DB_PASSFILE}" ]; then
  echo "[$0] CZECHIDM_REPORTS_DB_PASSFILE not set, using default from the template - EMPTY!!!.";
else
  if [ -f "${CZECHIDM_REPORTS_DB_PASSFILE}" ]; then
    dbpass=$(cat "$CZECHIDM_REPORTS_DB_PASSFILE");
    sed -i "s#spring.reports-datasource.password.*#spring.reports-datasource.password=$dbpass#" application-docker.properties;
  else
    echo "[$0] CZECHIDM_REPORTS_DB_PASSFILE not readable, using default password from the template - EMPTY!!!.";
  fi
fi

if [ -z "${CZECHIDM_REPORTS_DB_DRIVERCLASS}" ]; then
  echo "[$0] CZECHIDM_REPORTS_DB_DRIVERCLASS not set, using default from the template - EMPTY!!!.";
else
  sed -i "s/spring.reports-datasource.driver-class-name.*/spring.reports-datasource.driver-class-name=$CZECHIDM_REPORTS_DB_DRIVERCLASS/" application-docker.properties;
fi

# AUDIT logging disabled or enabled; enabled when the variable exists, even if empty
if [ -z "${CZECHIDM_AUDIT_LOGGING_ENABLED+x}" ]; then
  echo "[$0] CZECHIDM_AUDIT_LOGGING_ENABLED not set, using default from the template - not set. Audit logging is DISABLED.";
else
  echo "[$0] Audit logging is ENABLED on log level INFO.";
  sed -i "s/.*idm.sec.core.logger.AUDIT=.*/idm.sec.core.logger.AUDIT=INFO/" application-docker.properties;
fi

# ALLOWED ORIGINS AND JWT
if [ -z "${CZECHIDM_ALLOWED_ORIGINS}" ]; then
  echo "[$0] CZECHIDM_ALLOWED_ORIGINS not set, using default from the template.";
else
  sed -i "s#idm.pub.security.allowed-origins.*#idm.pub.security.allowed-origins=$CZECHIDM_ALLOWED_ORIGINS#" application-docker.properties;
fi
if [ -z "${CZECHIDM_JWT_TOKEN_PASSFILE}" ]; then
  echo "[$0] CZECHIDM_JWT_TOKEN_PASSFILE not set, using default from the template - EMPTY!!!." application-docker.properties;
else
  jwtpass=$(openssl rand -hex 12);
  if [ -f "${CZECHIDM_JWT_TOKEN_PASSFILE}" ]; then
    jwtpass=$(cat "$CZECHIDM_JWT_TOKEN_PASSFILE");
  else
    echo "[$0] CZECHIDM_JWT_TOKEN_PASSFILE not readable, GENERATING RANDOM JWT TOKEN.";
  fi
  sed -i "s/idm.sec.security.jwt.secret.token.*/idm.sec.security.jwt.secret.token=$jwtpass/" application-docker.properties;
fi

# MAILING
if [ -z "${CZECHIDM_MAIL_ENABLED}" ]; then
  echo "[$0] CZECHIDM_MAIL_ENABLED not set, using default from the template.";
else
  testmode="true";
  if [ "${CZECHIDM_MAIL_ENABLED}" == "true" ]; then
    testmode="false";
  fi
  sed -i "s/idm.sec.core.emailer.test.enabled.*/idm.sec.core.emailer.test.enabled=$testmode/" application-docker.properties;
fi
if [ -z "${CZECHIDM_MAIL_PROTOCOL}" ]; then
  echo "[$0] CZECHIDM_MAIL_PROTOCOL not set, using default from the template.";
else
  sed -i "s/idm.sec.core.emailer.protocol.*/idm.sec.core.emailer.protocol=$CZECHIDM_MAIL_PROTOCOL/" application-docker.properties;
fi
if [ -z "${CZECHIDM_MAIL_HOST}" ]; then
  echo "[$0] CZECHIDM_MAIL_HOST not set, using default from the template.";
else
  sed -i "s/idm.sec.core.emailer.host.*/idm.sec.core.emailer.host=$CZECHIDM_MAIL_HOST/" application-docker.properties;
fi
if [ -z "${CZECHIDM_MAIL_PORT}" ]; then
  echo "[$0] CZECHIDM_MAIL_PORT not set, using default from the template.";
else
  sed -i "s/idm.sec.core.emailer.port.*/idm.sec.core.emailer.port=$CZECHIDM_MAIL_PORT/" application-docker.properties;
fi
if [ -z "${CZECHIDM_MAIL_USER}" ]; then
  echo "[$0] CZECHIDM_MAIL_USER not set, using default from the template - not set.";
else
  sed -i "s/.*idm.sec.core.emailer.username.*/idm.sec.core.emailer.username=$CZECHIDM_MAIL_USER/" application-docker.properties;
fi
if [ -z "${CZECHIDM_MAIL_PASSFILE}" ]; then
  echo "[$0] CZECHIDM_MAIL_PASSFILE not set, using default from the template - not set.";
else
  if [ -f "${CZECHIDM_MAIL_PASSFILE}" ]; then
    mailpass=$(cat "$CZECHIDM_MAIL_PASSFILE");
    sed -i "s#.*idm.sec.core.emailer.password.*#idm.sec.core.emailer.password=$mailpass#" application-docker.properties;
  else
    echo "[$0] CZECHIDM_MAIL_PASSFILE not readable, using default password from the template - NOT SET.";
  fi
fi
if [ -z "${CZECHIDM_MAIL_SENDER}" ]; then
  echo "[$0] CZECHIDM_MAIL_SENDER not set, using default from the template.";
else
  sed -i "s/idm.sec.core.emailer.from.*/idm.sec.core.emailer.from=$CZECHIDM_MAIL_SENDER/" application-docker.properties;
fi

# SPRING file upload permitted size
if [ -z "${CZECHIDM_MAX_UPLOAD_SIZE}" ]; then
  echo "[$0] CZECHIDM_MAX_UPLOAD_SIZE not set, using default from the template.";
else
  sed -i "s/spring.servlet.multipart.max-file-size.*/spring.servlet.multipart.max-file-size=$CZECHIDM_MAX_UPLOAD_SIZE/" application-docker.properties;
  sed -i "s/spring.servlet.multipart.max-request-size.*/spring.servlet.multipart.max-request-size=$CZECHIDM_MAX_UPLOAD_SIZE/" application-docker.properties;
fi

# CAS properties

#SSO enabled
if [ -z "${CZECHIDM_CAS_ENABLED}" ]; then
  echo "[$0] CZECHIDM_CAS_ENABLED not set, using default from the template.";
else
  sed -i "s/idm.pub.core.cas.enabled.*/idm.pub.core.cas.enabled=$CZECHIDM_CAS_ENABLED/" application-docker.properties;
fi

# CAS url
if [ -z "${CZECHIDM_CAS_URL}" ]; then
  echo "[$0] CZECHIDM_CAS_URL not set, using default from the template.";
else
  sed -i "s|idm.sec.core.cas.url.*|idm.sec.core.cas.url=$CZECHIDM_CAS_URL|" application-docker.properties;
fi

# CAS login suffix
if [ -z "${CZECHIDM_CAS_LOGIN_SUFFIX}" ]; then
  echo "[$0] CZECHIDM_CAS_LOGIN_SUFFIX not set, using default from the template.";
else
  sed -i "s|idm.sec.core.cas.login-path.*|idm.sec.core.cas.login-path=$CZECHIDM_CAS_LOGIN_SUFFIX|" application-docker.properties;
fi

# CAS logout suffix
if [ -z "${CZECHIDM_CAS_LOGOUT_SUFFIX}" ]; then
  echo "[$0] CZECHIDM_CAS_LOGOUT_SUFFIX not set, using default from the template.";
else
  sed -i "s|idm.sec.core.cas.logout-path.*|idm.sec.core.cas.logout-path=$CZECHIDM_CAS_LOGOUT_SUFFIX|" application-docker.properties;
fi

# IdM url backend
if [ -z "${CZECHIDM_CAS_IDM_URL}" ]; then
  echo "[$0] CZECHIDM_CAS_IDM_URL not set, using default from the template.";
else
  sed -i "s|idm.pub.app.backend.url.*|idm.pub.app.backend.url=$CZECHIDM_CAS_IDM_URL|" application-docker.properties;
fi

# IdM url frontend
if [ -z "${CZECHIDM_CAS_IDM_FRONTEND_URL}" ]; then
  echo "[$0] CZECHIDM_CAS_IDM_FRONTEND_URL not set, using CZECHIDM_CAS_IDM_URL.";
  if [ -z "${CZECHIDM_CAS_IDM_URL}" ]; then
    echo "[$0] CZECHIDM_CAS_IDM_URL not set, using default from the template.";
  else
    sed -i "s|idm.pub.app.frontend.url.*|idm.pub.app.frontend.url=$CZECHIDM_CAS_IDM_URL|" application-docker.properties;
  fi
else
  sed -i "s|idm.pub.app.frontend.url.*|idm.pub.app.frontend.url=$CZECHIDM_CAS_IDM_FRONTEND_URL|" application-docker.properties;
fi

# Request parameter
if [ -z "${CZECHIDM_CAS_REQUEST_PARAMETER}" ]; then
  echo "[$0] CZECHIDM_CAS_REQUEST_PARAMETER not set, using default from the template.";
else
  sed -i "s/idm.sec.core.cas.parameter-name.*/idm.sec.core.cas.parameter-name=$CZECHIDM_CAS_REQUEST_PARAMETER/" application-docker.properties;
fi

# SSO header name
if [ -z "${CZECHIDM_CAS_HEADER_NAME}" ]; then
  echo "[$0] CZECHIDM_CAS_HEADER_NAME not set, using default from the template.";
else
  sed -i "s/idm.sec.core.cas.header-name.*/idm.sec.core.cas.header-name=$CZECHIDM_CAS_HEADER_NAME/" application-docker.properties;
fi

# SSO header prefix
if [ -z "${CZECHIDM_CAS_HEADER_PREFIX}" ]; then
  echo "[$0] CZECHIDM_CAS_HEADER_PREFIX not set, using default from the template.";
else
  sed -i "s|idm.sec.core.cas.header-prefix.*|idm.sec.core.cas.header-prefix=$CZECHIDM_CAS_HEADER_PREFIX|" application-docker.properties;
fi

# File with LDAP password
if [ -z "${CZECHIDM_CAS_LDAP_PWD_FILE}" ]; then
  echo "[$0] CZECHIDM_CAS_LDAP_PWD_FILE not set, using default from the template.";
else
  sed -i "s|idm.sec.cas.pwd-file-location.*|idm.sec.cas.pwd-file-location=$CZECHIDM_CAS_LDAP_PWD_FILE|" application-docker.properties;
fi

# LDAP host fo CAS integration
if [ -z "${CZECHIDM_CAS_LDAP_HOST}" ]; then
  echo "[$0] CZECHIDM_CAS_LDAP_HOST not set, using default from the template.";
else
  sed -i "s|idm.sec.cas.ldap.host.*|idm.sec.cas.ldap.host=$CZECHIDM_CAS_LDAP_HOST|" application-docker.properties;
fi

# Principal which IdM uses to connect to to LDAP
if [ -z "${CZECHIDM_CAS_LDAP_PRINCIPAL}" ]; then
  echo "[$0] CZECHIDM_CAS_LDAP_PRINCIPAL not set, using default from the template.";
else
  sed -i "s|idm.sec.cas.ldap.principal.*|idm.sec.cas.ldap.principal=$CZECHIDM_CAS_LDAP_PRINCIPAL|" application-docker.properties;
fi

# Base context for CAS LDAP
if [ -z "${CZECHIDM_CAS_LDAP_BASE_CONTEXT}" ]; then
  echo "[$0] CZECHIDM_CAS_LDAP_BASE_CONTEXT not set, using default from the template.";
else
  sed -i "s|idm.sec.cas.ldap.base-contexts.*|idm.sec.cas.ldap.base-contexts=$CZECHIDM_CAS_LDAP_BASE_CONTEXT|" application-docker.properties;
fi

# Enable cas module
if [ -z "${CZECHIDM_CAS_MODULE_ENABLED}" ]; then
  echo "[$0] CZECHIDM_CAS_MODULE_ENABLED not set, using default from the template.";
else
  sed -i "s|idm.pub.cas.enabled.*|idm.pub.cas.enabled=$CZECHIDM_CAS_MODULE_ENABLED|" application-docker.properties;
fi

# Append external properties
if [ -d "$CZECHIDM_START/application.properties.d" ] && [ "$(ls -A $CZECHIDM_START/application.properties.d)" ]; then
  echo "[$0] Appending properties to IdM configuration...";
  echo "" >> application-docker.properties;
  echo "# Following lines were appended by $0" >> application-docker.properties;
  echo "" >> application-docker.properties;
  for f in $(ls "$CZECHIDM_START"/application.properties.d/*.properties); do
    echo "[$0] Appending file $f";
    cat "$f" >> application-docker.properties;
  done
else
  echo "[$0] Cannot read $CZECHIDM_START/application.properties.d directory, no extra properties appended.";
fi