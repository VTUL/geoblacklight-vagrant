#!/bin/bash
set -o errexit -o nounset -o xtrace -o pipefail

INSTALL_USER="vagrant"
if [ $# -ge 1 ]; then
  INSTALL_USER="$1"
fi
if [ $# -ge 2 ]; then
  shift;
  echo -n "Ignoring extra arguments: $@"
fi
INSTALL_DIR="/home/$INSTALL_USER"
RUN_AS_INSTALLUSER="sudo -H -u $INSTALL_USER"
SERVER_HOSTNAME="localhost"
APP_ENV="development"
HYDRA_HEAD="geoblacklight"
HYDRA_HEAD_DIR="$INSTALL_DIR/$HYDRA_HEAD"
HYDRA_HEAD_GIT_BRANCH="geoblacklight_1.1.0"
HYDRA_HEAD_GIT_REPO_URL="https://github.com/VTUL/geoblacklight.git"
PASSENGER_REPO="/etc/apt/sources.list.d/passenger.list"
PASSENGER_INSTANCES="1"
NGINX_CONF_DIR="/etc/nginx"
NGINX_CONF_FILE="$NGINX_CONF_DIR/nginx.conf"
NGINX_SITE="$NGINX_CONF_DIR/sites-available/$HYDRA_HEAD.site"
NGINX_MAX_UPLOAD_SIZE="200M"
SSL_CERT_DIR="/etc/ssl/local/certs"
SSL_CERT="$SSL_CERT_DIR/$HYDRA_HEAD-crt.pem"
SSL_KEY_DIR="/etc/ssl/local/private"
SSL_KEY="$SSL_KEY_DIR/$HYDRA_HEAD-key.pem"
# User under which Solr runs.  We adopt the default, "solr"
SOLR_USER="solr"
# Which Solr version we will install
SOLR_VERSION="6.1.0"
SOLR_MIRROR="http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/"
SOLR_DIST="solr-$SOLR_VERSION"
# The directory under which we will install Solr.
SOLR_INSTALL="/opt"
# The directory under which Solr cores and other mutable Solr data live.
SOLR_MUTABLE="/var/solr"
# Where Solr cores live
SOLR_DATA="$SOLR_MUTABLE/data"
# The size at which Solr logs will be rotated
SOLR_LOGSIZE="100MB"
# Name of GeoBlacklight Solr core.  NB: If you change this you should also
# change the Solr URL in config/blacklight.yml accordingly
SOLR_CORE="blacklight-core"
RUN_AS_SOLR_USER="sudo -H -u $SOLR_USER"
SFTP_USER="upload"
SFTP_HOME_DIR="/home/$SFTP_USER"
SFTP_UPLOAD_ROOT="/opt/sftp/geodata"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

# Install Postfix MTA
debconf-set-selections <<< "postfix postfix/mailname string `hostname`"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y postfix
postconf -e inet_interfaces=localhost
service postfix restart

# Create SFTP upload user and area.  The upload user is created with "-U"
# so that an associated group of the same name is created.  This group is
# used to allow the upload user access to the ingest area file hierarchy.
mkdir -p "$SFTP_HOME_DIR"
useradd -d "$SFTP_HOME_DIR" -U -s /usr/lib/openssh/sftp-server $SFTP_USER
# Make upload user's .ssh/authorized_keys file
mkdir "$SFTP_HOME_DIR/.ssh"
chown $SFTP_USER "$SFTP_HOME_DIR/.ssh"
chmod 500 "$SFTP_HOME_DIR/.ssh"
if [ -f /vagrant/files/authorized_keys ]; then
  install -m 444 /vagrant/files/authorized_keys "$SFTP_HOME_DIR/.ssh/authorized_keys"
else
  echo "WARNING: No authorized_keys file!"
  echo "Upload user will not be able to sftp to system until you provide one."
fi
# Create SFTP chroot area with GeoBlacklight user owning most directories (for
# the ingest script to be able to write to them) and the upload user's
# group being the group owner of them.  Root must own the root directory
# of the chroot area and all preceding directories in the path for
# StrictModes to be satisfied.
mkdir -p "$SFTP_UPLOAD_ROOT"
chown root:root "$SFTP_UPLOAD_ROOT"
chmod 755 "$SFTP_UPLOAD_ROOT"
mkdir "${SFTP_UPLOAD_ROOT}/Upload"
chown ${INSTALL_USER}:${SFTP_USER} "${SFTP_UPLOAD_ROOT}/Upload"
chmod 770 "${SFTP_UPLOAD_ROOT}/Upload"
mkdir "${SFTP_UPLOAD_ROOT}/Archive"
mkdir "${SFTP_UPLOAD_ROOT}/Report"
mkdir "${SFTP_UPLOAD_ROOT}/Report/Logs"
mkdir "${SFTP_UPLOAD_ROOT}/Report/Errors"
chown -R ${INSTALL_USER}:${SFTP_USER} "${SFTP_UPLOAD_ROOT}/Report"
chown ${INSTALL_USER}:${SFTP_USER} "${SFTP_UPLOAD_ROOT}/Archive"
chmod -R 750 "${SFTP_UPLOAD_ROOT}/Archive"
chmod -R 750 "${SFTP_UPLOAD_ROOT}/Report"
# Enable chroot SFTP for upload user
cat >> /etc/ssh/sshd_config <<SSHD_CONFIG

Match User $SFTP_USER
  ChrootDirectory "$SFTP_UPLOAD_ROOT"
  AuthenticationMethods publickey
  X11Forwarding no
  AllowTcpForwarding no
  ForceCommand internal-sftp
SSHD_CONFIG
service ssh reload

apt-get install software-properties-common -y
# Install Java 8 and make it the default Java
add-apt-repository -y ppa:webupd8team/java
apt-get update -y
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get install -y oracle-java8-installer
update-java-alternatives -s java-8-oracle
add-apt-repository -y ppa:brightbox/ruby-ng
apt-get update
apt-get install -y ruby2.2 ruby2.2-dev
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
apt-get install -y apt-transport-https ca-certificates
echo "deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main" > /etc/apt/sources.list.d/passenger.list
chown root /etc/apt/sources.list.d/passenger.list
chmod 600 /etc/apt/sources.list.d/passenger.list
apt-get update
apt-get install -y nginx-extras passenger
TMPFILE=`/bin/mktemp`
cat $NGINX_CONF_FILE | \
  sed "s/worker_processes .\+;/worker_processes auto;/" | \
  sed "s@# include /etc/nginx/passenger.conf;@include /etc/nginx/passenger.conf;@" > $TMPFILE
sed "1ienv PATH;" < $TMPFILE > $NGINX_CONF_FILE
chown root: $NGINX_CONF_FILE
chmod 644 $NGINX_CONF_FILE
# Disable the default site
unlink ${NGINX_CONF_DIR}/sites-enabled/default
# Stop Nginx until the application is installed
service nginx stop

# Configure Passenger to serve our site.
# Create the virtual host for our Sufia application
cat > $TMPFILE <<HereDoc
passenger_max_pool_size ${PASSENGER_INSTANCES};
passenger_pre_start http://${SERVER_HOSTNAME};
server {
    listen 80;
    listen 443 ssl;
    client_max_body_size ${NGINX_MAX_UPLOAD_SIZE};
    passenger_min_instances ${PASSENGER_INSTANCES};
    root ${HYDRA_HEAD_DIR}/public;
    passenger_enabled on;
    passenger_app_env ${APP_ENV};
    server_name ${SERVER_HOSTNAME};
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
}
HereDoc
# Install the virtual host config as an available site
install -o root -g root -m 644 $TMPFILE $NGINX_SITE
rm $TMPFILE
# Enable the site just created
link $NGINX_SITE ${NGINX_CONF_DIR}/sites-enabled/${HYDRA_HEAD}.site
# Create the directories for the SSL certificate files
mkdir -p $SSL_CERT_DIR
mkdir -p $SSL_KEY_DIR
# Create an SSL certificate
SUBJECT="/C=US/ST=Virginia/O=Virginia Tech/localityName=Blacksburg/commonName=$SERVER_HOSTNAME/organizationalUnitName=University Libraries"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$SSL_KEY" \
    -out "$SSL_CERT" -subj "$SUBJECT"
chmod 444 "$SSL_CERT"
chown root "$SSL_CERT"
chmod 400 "$SSL_KEY"
chown root "$SSL_KEY"

# Install GeoBlacklight prerequisites and application
apt-get install -y git sqlite3 libsqlite3-dev zlib1g-dev build-essential
# Install a JavaScript runtime to allow the uglifier gem to run
apt-get install -y nodejs
gem install bundler
cd "$INSTALL_DIR"
$RUN_AS_INSTALLUSER git clone --branch "$HYDRA_HEAD_GIT_BRANCH" "$HYDRA_HEAD_GIT_REPO_URL" "$HYDRA_HEAD_DIR"
cd "$HYDRA_HEAD_DIR"
if [ "$APP_ENV" = "production" ]; then
  $RUN_AS_INSTALLUSER bundle install --without development test
else
  $RUN_AS_INSTALLUSER bundle install
fi

# Set up the GeoBlacklight application
if [ ! -f config/secrets.yml ]; then
  cat > config/secrets.yml <<END_OF_SECRETS
${APP_ENV}:
  secret_key_base: $(openssl rand -hex 64)
END_OF_SECRETS
fi
$RUN_AS_INSTALLUSER RAILS_ENV=${APP_ENV} bundle exec rake db:setup

# Application Deployment steps.
if [ "$APP_ENV" = "production" ]; then
    $RUN_AS_INSTALLUSER RAILS_ENV=${APP_ENV} bundle exec rake assets:precompile
fi

# Install Solr
cd "$INSTALL_DIR"
# Fetch the Solr distribution and unpack the install script
wget -q "$SOLR_MIRROR/$SOLR_DIST.tgz"
tar xzf $SOLR_DIST.tgz $SOLR_DIST/bin/install_solr_service.sh --strip-components=2
# Install and start the service using the install script
bash ./install_solr_service.sh $SOLR_DIST.tgz -u $SOLR_USER -d $SOLR_MUTABLE -i $SOLR_INSTALL
# Remove Solr distribution
rm $SOLR_DIST.tgz
rm ./install_solr_service.sh
# Stop Solr until we have created the core
service solr stop

# Create Sufia Solr core
cd $SOLR_DATA
$RUN_AS_SOLR_USER mkdir -p ${SOLR_CORE}/conf
$RUN_AS_SOLR_USER echo "name=$SOLR_CORE" > ${SOLR_CORE}/core.properties
cp -R ${HYDRA_HEAD_DIR}/solr/conf/* "${SOLR_CORE}/conf"
chmod -R u=rwX,go=rX "${SOLR_CORE}/conf"
chown -R $SOLR_USER "${SOLR_CORE}/conf"

# Adjust logging settings
$RUN_AS_SOLR_USER sed -i 's/^log4j.rootLogger=.*$/log4j.rootLogger=WARN, file/' /var/solr/log4j.properties
$RUN_AS_SOLR_USER sed -i "s/file.MaxFileSize=.*$/file.MaxFileSize=${SOLR_LOGSIZE}/" /var/solr/log4j.properties

# Start services
service solr start
service nginx start
