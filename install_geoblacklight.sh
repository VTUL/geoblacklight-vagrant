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

apt-get update
apt-get dist-upgrade -y

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
  sed "s/# passenger_root/passenger_root/" | \
  sed "s/# passenger_ruby/passenger_ruby/" > $TMPFILE
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
apt-get install -y git sqlite3 libsqlite3-dev zlib1g-dev build-essential
# Install a JavaScript runtime to allow the uglifier gem to run
apt-get install -y nodejs
gem install rails -v "~> 4.2.5" -N
$RUN_AS_INSTALLUSER rails new $HYDRA_HEAD -m https://raw.githubusercontent.com/geoblacklight/geoblacklight/master/template.rb
cd $HYDRA_HEAD
$RUN_AS_INSTALLUSER bundle exec rake jetty:download
$RUN_AS_INSTALLUSER bundle exec rake jetty:unzip
$RUN_AS_INSTALLUSER bundle exec rake geoblacklight:configure_jetty
cat > /etc/init.d/hydra-jetty <<END_OF_INIT_SCRIPT
#!/bin/sh
# Init script to start up hydra-jetty services
# Warning: This script is auto-generated.

### BEGIN INIT INFO
# Provides: hydra-jetty
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Controls Hydra-Jetty Services
### END INIT INFO

# verify the specified run as user exists
runas_uid=\$(id -u $INSTALL_USER)
if [ \$? -ne 0 ]; then
  echo "User $INSTALL_USER not found! Please create the $INSTALL_USER user before running this script."
  exit 1
fi
. /lib/lsb/init-functions

start() {
  cd "${HYDRA_HEAD_DIR}"
  sudo -H -u $INSTALL_USER RAILS_ENV=${APP_ENV} bundle exec rake jetty:start
}

stop() {
  cd "${HYDRA_HEAD_DIR}"
  sudo -H -u $INSTALL_USER RAILS_ENV=${APP_ENV} bundle exec rake jetty:stop
}

status() {
  cd "${HYDRA_HEAD_DIR}"
  sudo -H -u $INSTALL_USER RAILS_ENV=${APP_ENV} bundle exec rake jetty:status
}

case "\$1" in
  start)   start ;;
  stop)    stop ;;
  restart) stop
           sleep 1
           start
           ;;
  status)  status ;;
  *)
    echo "Usage: \$0 {start|stop|restart|status}"
    exit
esac
END_OF_INIT_SCRIPT
chmod 755 /etc/init.d/hydra-jetty
chown root:root /etc/init.d/hydra-jetty
update-rc.d hydra-jetty defaults
# Start services
service hydra-jetty start
service nginx start
