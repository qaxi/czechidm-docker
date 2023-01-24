#!/bin/bash
echo "[$0] Creating Tomcat Java truststore...";

truststorepath="$TOMCAT_TRUSTSTORE/truststore.jks";
cd "$TOMCAT_TRUSTSTORE";

# delete current truststore, we will make a new one
rm -fv "$truststorepath";

echo "[$0] Importing certificates from: $TOMCAT_TRUSTSTORE/certs/ ...";
for f in $(ls "$TOMCAT_TRUSTSTORE/certs/"); do
  echo "[$0] Importing certificate $f";
  # we add UNIX timestamp + milliseconds to the alias because aliases are lowercase only (and are converted to lc automatically by keytool)
  # when importing certificate with filename in uppercase, there could be a conflict resulting in certificate not getting imported
  # so we append millisecond-precise timestamp. just to be sure
  keytool -importcert -file "$TOMCAT_TRUSTSTORE/certs/$f" -alias "$f-$(date +%s.%3N)" -keystore $truststorepath -storepass changeit -noprompt
done

echo "[$0] Truststore generation done.";
