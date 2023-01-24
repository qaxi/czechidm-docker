# CzechIdM image
Image built atop BCV's Tomcat image with Apache Tomcat 9.0.x version.
You can find our Tomcat Docker image [here](https://github.com/bcvsolutions/tomcat-docker). This image is referenced as a "baseimage" throughout this text.

## Image versioning
This image is versioned by CzechIdM version. The underlying Tomcat version is not mentioned since CzechIdM is distributed as a whole application stack (well, without a database).

Naming scheme is pretty simple: **bcv-czechidm:CZECHIDM_VERSION-rIMAGE_VERSION**.
- Image name is **bcv-czechidm**.
- **CZECHIDM_VERSION** is a version of CzechIdM in the image.
- **IMAGE_VERSION** is an image release version written as a serial number, starting at 0. When images have the same CzechIdM versions but different image versions it means there were some changes in the image itself (setup scripts, etc.) but application itself did not change.

Example
```
bcv-czechidm:9.7.11-r0    // first release of CzechIdM 9.7.11 image
bcv-czechidm:9.7.11-r2    // third release of CzechIdM 9.7.11 image
bcv-czechidm:10.0.1-r0    // first release of CzechIdM 10.0.1 image
bcv-czechidm:latest       // nightly build
```

## Building
To build a new CzechIdM image, set the correct **CZECHIDM_VERSION** in the Dockerfile and put the application WAR archive into **dropin/idm-app-$CZECHIDM_VERSION.war**
Then cd to the directory which contains the Dockerfile and issue `docker build --no-cache -t <image tag here> ./`.

The build process:
1. Pulls **bcv-tomcat:some-version** image.
1. Installs necessary tooling - openssl, xmlstarlet, etc.
1. Secures Tomcat installation, namely:
  1. Disables shutdown port.
  1. Disables directory listings.
  1. Removes all Tomcat management apps.
1. Copies idm.war with given application version into the container. If you need other version of the app, you **have to build a new image**.
1. Sets up IdM build environment - this is used during container start to rebuild the IdM, in case some new IdM modules/libraries were provided.
1. Copies additional runscripts into the container. Those runscripts generate IdM configuration. For explanation of runscripts, see Tomcat baseimage documentation.
1. Creates IdM configuration/backups directory structure **/opt/czechidm/...**.

## Use
Image contains some defaults, but it **cannot** be used without further configuration.
- STDOUT/STDERR logging, logs available with `docker logs CONTAINER`.
- Xms512M
- Xmx1024M - This is not optimal. For recommended sizing of server/container, consult [this page](https://wiki.czechidm.com/faq/prerequisites_and_system_requirements). For presentation purposes, it is possible to run CzechIdM with about 3GB Xmx.

After it is started up, you can navigate to http://yourserver:8080/idm and log into the application as user **admin** with password **admin**.

### Using this image for presentation purposes
CzechIdM in this image can be ran with H2 in-memory store. This can be used for presenting the application. All data will vanish once the Tomcat process is stopped. For using CzechIdM this way just use following compose file, no need to configure anything else. The "skip IdM configuration" variable has to be set for this to work.
```yaml
version: '3.2'

services:
  appserver:
    image: bcv-czechidm:SOMETAG
    container_name: czechidm
    ports:
      - 8009:8009
      - 8080:8080
    hostname: czechidm
    environment:
      - JAVA_XMS=1024M
      - JAVA_XMX=2048M
      - TZ=Europe/Prague
      - DOCKER_SKIP_IDM_CONFIGURATION=yes
```

### Minimal mandatory parameters for deployments
Those parameters have no defaults and when left unset, IdM will not start at all.

Configuration for main DB for IdM data
- **CZECHIDM_DB_URL** - JDBC URL for the database. The database must already exist and be reachable on the network. Example:`jdbc:postgresql://databaseserver:5432/czechidm`.
- **CZECHIDM_DB_USER** - User under which IdM connects to the database. Example:`czechidm`.
- **CZECHIDM_DB_PASSFILE** - Path to a file in the container, where the password for database user is stored. This file has to be mounted from the host into the container. Example:`/run/secrets/db.pwfile`.
- **CZECHIDM_DB_DRIVERCLASS** - JDBC driver class. Example:`org.postgresql.Driver`.
- **CZECHIDM_DB_POOL_SIZE** - Maximum pool size, default values are 50 for main DB and 2 for logging.

Configuration for DB for report module

This is mandatory **only if** you are using czechidm-rpt module. If you do not use czechidm-rpt module, do not set those properties.
For reporting datasource, use a read-only user. Use differrent user than for the main datasource.
- **CZECHIDM_REPORTS_DB_URL** - JDBC URL for the database. The database must already exist and be reachable on the network. Example:`jdbc:postgresql://databaseserver:5432/czechidm`.
- **CZECHIDM_REPORTS_DB_USER** - User under which IdM connects to the database. Example:`czechidm_report`.
- **CZECHIDM_REPORTS_DB_PASSFILE** - Path to a file in the container, where the password for database user is stored. This file has to be mounted from the host into the container. Example:`/run/secrets/db_report.pwfile`.
- **CZECHIDM_REPORTS_DB_DRIVERCLASS** - JDBC driver class. Example:`org.postgresql.Driver`.

## Container startup and hooks
Container start leverages existing hooks infrastructure as provided by the Tomcat baseimage - **run.sh**, **runOnce.sh**, **runEvery.sh**, **startTomcat.sh** and their respective **.d/** directories. For more information about runscripts structure, see Tomcat baseimage doc.

CzechIdM image adds its own scripts there:
- **runEvery.d/001_000-buildIdM.sh** - Checks if some modules were changed. If that happened, it rebuilds and redeploys IdM. Script creates hashes of checked mountpoints in the `/idmbuild/checksums/` directory. By comparing those hashes with current directory contents it determines if it is necessary to rebuild the IdM application WAR. In case the build fails, the old version of the app is started.
  - Checked mountpoints:
    - `/idmbuild/modules/`
    - `/idmbuild/frontend/config/`
    - `/idmbuild/frontend/czechidm-modules/`  

  In some cases FE build is skipped for faster boot
  - If all of this folders are empty:
    - `/idmbuild/modules/`
    - `/idmbuild/frontend/config/`
    - `/idmbuild/frontend/czechidm-modules/`
    - `/idmbuild/frontend/src/`  
- **runEvery.d/001_001-createIdMSecretkey.sh** - Checks if there is confidential storage encryption key present at /run/secrets/secret.key. If there is, it creates a symlink `/opt/czechidm/etc/secret.key -> /run/secrets/secret.key`. If **/opt/czechidm/etc/secret.key** (either symlink or file) is already present, the script does nothing. If none of previous cases is matched, it generates new secret.key.
  - **Beware:** This key is used for securing credentials to end systems the IdM manages. Once lost (i.e. on container recreate), IdM effectively loses all such credentials and they have to be configured anew. We recommend to mount the secret.key from the container host to ensure it is properly persisted across container rebuilds.
- **runEvery.d/001_002-createIdMQuartzconfig.sh** - Creates Quartz scheduler configuration for the IdM. Template file is taken from the current build of CzechIdM inside the container. Creates file /opt/czechidm/etc/quartz-docker.properties.
- **runEvery.d/001_003-createIdMLogbackconfig.sh** - Creates Logback logger configuration for the IdM. Template file is taken from the current build of CzechIdM inside the container and stripped of all profiles except the dev profile. This profile is renamed to "docker". Creates file /opt/czechidm/etc/logback-spring.xml.
  - This script uses two environment variables to adjust logging levels:
    - **CZECHIDM_LOGGING_LEVEL_DB** - Loglevel for messages logged into the application database (browsable through GUI, e.g. "eu.bcvsolutions").
    - **CZECHIDM_LOGGING_LEVEL** - Loglevel for usually-needed log messages (e.g. "org.springframework", "org.hibernate.SQL", etc.).
- **runEvery.d/001_004-createIdMAppconfig.sh** - This file takes a template configuration /idmbuild/product/application-docker.TPL.properties and enriches it from the current environment. Resulting file is /opt/czechidm/etc/application-docker.properties. Variables like CZECHIDM_DB_URL ultimately get stored here as proper Spring configuration properties. There are many env variables in play, please consult chapters below.
- **runEvery.d/001_005-generateIdMTruststore.sh** - This script was superseded by similar baseimage functionality.
- **runEvery.d/001_006-adjustTomcatConfig.sh** - This script adds some parameters to Tomcat's JAVA_OPTS. Those parameters are necessary for IdM to run.
  - The `/runscripts/startTomcat.d/001_006-adjustTomcatConfig.sh` is generated on-the-fly.
  - Script creates `$TOMCAT_BASE/bin/setenv.sh` file, effectively adding `/opt/czechidm/etc/` and other directories to the classpath, so Tomcat is able to properly load the CzechIdM configuration.
- **runEvery.d/001_007-fixupMountedDirsPrivs.sh** - Some mounted directories (namely `/opt/czechidm/{backup,data}`) need to be writable for tomcat user. If you mount them from the host, they may have some other owner or privileges. This script fixes that.

## Container shutdown
See Tomcat baseimage doc. IdM is very swift when shutting down, the default STOP_TIMEOUT should be more than enough.

## Environment variables
You can pass a number of environment variables into the container. All Tomcat baseimage environment variables are supported - see the baseimage doc.

There is also a number of new env variables added in this container.
- **DOCKER_SECURE_SECRETS** - If set (even if empty), runscripts take care of securing `/run/secrets` from inside the container. This is because DockerCE does not implement `secrets` properly - it just converts them to binds. The secrets feature is limited to Docker Swarm. If you mount any secrets, you want this enabled. **Default: disabled**.
- **DOCKER_PERSIST_M2_REPO** - If set (even if empty), the Maven's m2/ downloaded packages directory is not purged at the end of the build. **Default: disabled**.
- **DOCKER_PERSIST_NODEJS_REPO** - If set (even if empty), the downloaded local NodeJS and its config are not purged at the end of the build. **Default: disabled**.
- **DOCKER_SKIP_IDM_CONFIGURATION** - If set (even if empty), IdM configuration scripts will not be executed. You have to (re)populate contents of `/opt/czechidm/etc/` yourself and set JAVA_OPTS for Tomcat to suit the IdM. This option is useful only if you want to mount all configuration from outside of the container. **Default: disabled**.
- **CZECHIDM_LOGGING_LEVEL** - Loglevel of application components. See the runscript for details. Loglevels are written as is customary in Java logging. **Default: INFO**.
- **CZECHIDM_LOGGING_LEVEL_DB** - Loglevel of those application components that are also logged into database. See the runscript for details. Loglevels are written as is customary in Java logging. **Default: ERROR**.
- **CZECHIDM_AUDIT_LOGGING_ENABLED** - If set (even if empty), this property turns on application audit logging which goes to textual application log. Audit logging level is always `INFO`. **Default: not set**.
- **CZECHIDM_APP_INSTANCEID** - IdM application instance id. Used in clustered environments to distinguish IdM instances. When running non-clustered, leave it at default. **Default: idm-primary**.
- **CZECHIDM_APP_STAGE** - Application stage. Used to tell if this instance is production, testing, staging, development, etc. You can basically write here what you want, IdM will display little label in its GUI (top right corner). If this is set to "production", the GUI label is not displayed at all. **Default: docker-container**.
- **CZECHIDM_DB_URL** - JDBC URL to the IdM database. **Default: not set**.
- **CZECHIDM_DB_USER** - Database user for the IdM. **Default: not set**.
- **CZECHIDM_DB_PASSFILE** - Path to a file with password for a database user. This file is `cat`ed to the configuration. **Default: not set**.
- **CZECHIDM_DB_DRIVERCLASS** - JDBC driver class. **Default: not set**.
- **CZECHIDM_DB_POOL_SIZE** - Maximum pool size which will CzechIdM use.If you set this property 95% of connections is used for main DB and the rest 5% is used for logging. When setting this property, bear in mind, that PostgreSQL reserves 3 connections from its `max_connections` to the superuser. **Default: not set (-> 50 for main db, 2 for logging)**
- **CZECHIDM_REPORTS_DB_URL** - JDBC URL for the database. The database must already exist and be reachable on the network. **Default: not set**
- **CZECHIDM_REPORTS_DB_USER** - User under which IdM connects to the database. **Default: not set**
- **CZECHIDM_REPORTS_DB_PASSFILE** - Path to a file in the container, where the password for the reports database user is stored. This file has to be mounted from the host into the container. **Default: not set**
- **CZECHIDM_REPORTS_DB_DRIVERCLASS** - JDBC driver class for the reporting datasource. **Default: not set**
- **CZECHIDM_ALLOWED_ORIGINS** - Allowed origins for the requests coming to the IdM backend. Change it to DNS name the IdM is visible to users. **Default: http://localhost**.
- **CZECHIDM_JWT_TOKEN_PASSFILE** - Path to a file with JWT token. This file is `cat`ed to the configuration. CzechIdM uses JWT tokens for securing its session tokens. You do not need to supply the token, but then every container restart will log users out. **Default: not set**.
- **CZECHIDM_MAIL_ENABLED** - Whether IdM will send mail or not. Set to **true** if you want IdM to send mail. Set to **false** if you do not want to send mail. **Default: false**.
- **CZECHIDM_MAIL_PROTOCOL** - Mail relay protocol. **Default: smtp**.
- **CZECHIDM_MAIL_HOST** - Mail relay address. IdM sends mail to the relay and the relay distributes the mail further. **Default: something.tld**.
- **CZECHIDM_MAIL_PORT** - Destination port of mail relay. **Default: 25**
- **CZECHIDM_MAIL_USER** - Username for logging into mail relay. If relay does not need authentication, leave it at default. **Default: not set, property not added to config**.
- **CZECHIDM_MAIL_PASSFILE** - Password for logging into mail relay. Path to the file where password is stored, it is `cat`ed into the configuration. If relay does not need authentication, leave it at default. **Default: not set, property not added to config**.
- **CZECHIDM_MAIL_SENDER** - The "From" address in the mail. **Default: czechidm@localhost**.
- **CZECHIDM_MAX_UPLOAD_SIZE** - The maximum size of uploaded file the application accepts (e.g. "20MB", "1024KB"). Supported units are **KB** and **MB** (case sensitive!). The default value should be enough for almost everybody. **Default: 100MB**
- **CZECHIDM_CAS_ENABLED** - Enable authentication via CAS. If enabled, all properties **CZECHIDM_CAS_...** become mandatory and must be set for SSO authentication via CAS to work. **Default: false**
- **CZECHIDM_CAS_URL** - Base URL where CAS is accessible. Syntax of this field is `https://hostname-of-CAS/URI`. **Default: empty**
- **CZECHIDM_CAS_LOGIN_SUFFIX** - Suffix which is, in effect, appended to CZECHIDM_CAS_URL. Resulting URL is used for login operation in CAS. It must start with slash (eg. `/login`). **Default: `/login?service=`**
- **CZECHIDM_CAS_LOGOUT_SUFFIX** - Suffix which is appended to CZECHIDM_CAS_URL. Resulting URL is used for single sign-out operation. It must start with slash (eg. `/logout`). **Default: `/logout?service=`**
- **CZECHIDM_CAS_IDM_URL** - URL of CzechIdM (backend). This URL is used for redirect back after logout and also for ticket validation. Syntax of this field is `https://hostname-of-CzechIdM/URI`. **Default: empty**
- **CZECHIDM_CAS_IDM_FRONTEND_URL** - URL of CzechIdM (frontend), used only if frontend is run on a different URL than backend. If left empty, property from CZECHIDM_CAS_IDM_URL is used instead. This URL is used for redirect back after logout and also for ticket validation. Syntax of this field is `https://hostname-of-CzechIdM/URI`. **Default: empty**
- **CZECHIDM_CAS_REQUEST_PARAMETER** - Specifies which parameters are added as a part of HTTP requests. **Default: `ticket`**
- **CZECHIDM_CAS_HEADER_NAME** - Header name in which CAS sends the ticket value. **Default: empty**
- **CZECHIDM_CAS_HEADER_PREFIX** - Path to CzechIdM for the HTTP Referer header used by CAS while redirecting back to application. This value is concatenated with CAS ticket to form Referer header. Syntax of this field is `https://hostname-of-CzechIdM/URI/?ticket=`. **Default: empty**
- **CZECHIDM_CAS_LDAP_PWD_FILE** - Absolute location of the file which contains password to CAS's underlying LDAP. Format of this property needs to be `file:ABSOLUTE_PATH`. For example `file:/run/secrets/ldap.pwfile`. See `Mounted files and volumes` to learn how to bind volume with this file. **Default: empty**
- **CZECHIDM_CAS_LDAP_HOST** - Hostname of CAS's underlying LDAP. **Default: empty**
- **CZECHIDM_CAS_LDAP_PRINCIPAL** - Distinguished name of account used for LDAP management. See `CZECHIDM_CAS_LDAP_PWD_FILE` **Default: empty**
- **CZECHIDM_CAS_LDAP_BASE_CONTEXT** - Base context of CAS's underlying LDAP. IdM will manage users in `ou=users,CZECHIDM_CAS_LDAP_BASE_CONTEXT` **Default: empty**
- **CZECHIDM_CAS_MODULE_ENABLED** - Enables idm-cas module. Note that module needs to be installed (See `CzechIdM modules directories` in the next section). Enabling CAS module at startup is needed for initialization of IdM-CAS integration. **Default: false**

## Mounted files and volumes
- Mandatory
  - Database user password
    - See CZECHIDM_DB_USER, CZECHIDM_DB_PASSFILE environment variables.
    - Without this file mounted, CzechIdM will not connect to the database and therefore will not start.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./idm_db.pwfile
          target: /run/secrets/db.pwfile
          read_only: true
      ```
  - CzechIdM secret.key
    - This key encrypts the IdM confidential storage (a database where end systems credentials are stored). If the key is lost, credentials cannot be decrypted and used by the application -> application cannot manage any end system. For serious deployments, it is mandatory to have this key persisted.
    - Without this file mounted, the **secret.key** will be regenerated when the container is recreated.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./idm_secret.key
          target: /run/secrets/secret.key
          read_only: true
      ```
- Optional
  - JWT token file
    - This key protects user session cookies.
    - Without this file mounted, the JWT token will be regenerated on every container start, effectively logging out all users. Users can log in back again. There is no other effect on them.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./idm_jwt.pwfile
          target: /run/secrets/jwt.pwfile
          read_only: true
      ```
  - Mail relay password file
    - See CZECHIDM_MAIL_PASSFILE environment variables.
    - Without this file mounted, CzechIdM will not be able to authenticate to a mail relay and send mail notification. If the mail relay does not require authentication, you do not need to mount this file.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./idm_mailer.pwfile
          target: /run/secrets/mailer.pwfile
          read_only: true
      ```
  - Trusted certificates directory
    - See 000_002-generateJavaTruststore.sh script documentation in the baseimage doc.
    - Without this directory mounted, CzechIdM will not trust any SSL certificates. This effectively prevents identity manager to securely connect to other systems. Nowadays, it is simply dangerous to run all communication in plaintext, so populating and mounting this directory is highly recommended.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./certs
          target: /opt/tomcat/truststore/certs
          read_only: true
      ```
  - Attachments directory
    - CzechIdM supports attaching files to certain actions in GUI. Those attachments are stored as files on the disk - in this directory (`/opt/czechidm/data` inside the container). If you want to persist attachments (which you 100% want unless you don't use them at all), you want this directory mounted.
    - Without this directory mounted, all attachments the user inserted into CzechIdM will be lost on container rebuild.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./attachments
          target: /opt/czechidm/data
          read_only: false
      ```
  - Groovy scripts backup directory
    - CzechIdM allows you to export a backup of your Groovy scripts (data transforms). They are stored in this directory (`/opt/czechidm/backup/` inside the container).
    - Without this directory mounted, all Groovy script backups will be lost on container rebuild. Current version of Groovy scripts is stored in the CzechIdM database and will persist regardless of this directory being mounted or not.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./groovy-backups
          target: /opt/czechidm/backup
          read_only: false
      ```
  - CzechIdM modules directories
    - CzechIdM allows you to add libraries and modules to the base product. Depending on what you want to add, create a mount under the `/idmbuild/modules`, `/idmbuild/frontend/config` or `/idmbuild/frontend/czechidm-modules` directory in the container.
    - Without this directory mounted, the plain CzechIdM product will be deployed.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./connector-jars
          target: /idmbuild/modules
          read_only: true
      ```
  - Reporting datasource user password
    - See CZECHIDM_REPORTS_DB_USER, CZECHIDM_REPORTS_DB_PASSFILE environment variables.
    - Without this file mounted, CzechIdM will not connect to its reporting datasource. This mount is mandatory only if you are using czechidm-rpt module.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./db_report.pwfile
          target: /run/secrets/db_report.pwfile
          read_only: true
      ```
  - Repository credentials
    - Login and password to [repo.iamappliance.com](repo.iamappliance.com) for Maven and NPM.
    - If the login and password are filled in, the Maven and NPM packages will be downloaded from repo.iamappliance.com. If not, publicly available portals (Maven and NodeJS central) will be used.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: /etc/yum/var/iam_username
          target: /run/secrets/iam_repo_username
          read_only: true
        - type: bind
          source: /etc/yum/var/iam_password
          target: /run/secrets/iam_repo_password
          read_only: true
      ```
  - CAS LDAP password file
    - File containing password to **CZECHIDM_CAS_LDAP_PRINCIPAL**. See **CZECHIDM_CAS_LDAP_PWD_FILE**
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./ldap.pwfile
          target: /run/secrets/ldap.pwfile
          read_only: true
      ```
  - External application properties
    - This is a .d/ directory similar to Linux .d/ directories. All files in this directory which name ends with .properties will be appended to final application.properties configuration file. This is preferred before replacing application.properties file as a whole.
    - Example
      ```yaml
      volumes:
        - type: bind
          source: ./application.properties.d
          target: /idmstart/application.properties.d
          read_only: true
      ```

## Forbidden variables
The same variables as for Tomcat baseimage, and also:
- **CZECHIDM_BUILDROOT** - The build root for the IdM application. Identity manager is built/modified here and once this is done, the final app is deployed into Tomcat.
- **TOMCAT_BASE** - Root directory of the Tomcat installation.
- **CZECHIDM_CONFIG** - Root directory of the CzechIdM configuration directory.

## Hacking away
See Tomcat baseimage doc.
