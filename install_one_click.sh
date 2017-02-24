#!/bin/bash
# Author:  hyhlfq <hyhlfq@gmail.com>
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack
#
#       Auto Install: nginx,openssl,tomcat-8,mysql-5.7,jdk-1.8,php-7.1,apcu,redis

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear

# get pwd
sed -i "s@^oneinstack_dir.*@oneinstack_dir=`pwd`@" ./options.conf

. ./versions.txt
. ./options.conf
. ./include/color.sh
. ./include/check_os.sh
. ./include/check_dir.sh
. ./include/download.sh
. ./include/get_char.sh
. ./options_one_click.conf

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

mkdir -p $wwwroot_dir/default $wwwlogs_dir
[ -d /data ] && chmod 755 /data

# Use default SSH port 22. If you use another SSH port on your server
if [ -e "/etc/ssh/sshd_config" ]; then
  [ -z "`grep ^Port /etc/ssh/sshd_config`" ] || ssh_port=`grep ^Port /etc/ssh/sshd_config | awk '{print $2}'`
  SSH_PORT=$ssh_port

  if [ -z "`grep ^Port /etc/ssh/sshd_config`" -a "$SSH_PORT" != '22' ]; then
    sed -i "s@^#Port.*@&\nPort $SSH_PORT@" /etc/ssh/sshd_config
  elif [ -n "`grep ^Port /etc/ssh/sshd_config`" ]; then
    sed -i "s@^Port.*@Port $SSH_PORT@" /etc/ssh/sshd_config
  fi
fi

# check if Nginx has been installed
[ "$Nginx_version" != '4' -a -e "$nginx_install_dir/sbin/nginx" ] && { echo "${CWARNING}Nginx already installed! ${CEND}"; Nginx_version=Other; }
[ "$Nginx_version" != '4' -a -e "$tengine_install_dir/sbin/nginx" ] && { echo "${CWARNING}Tengine already installed! ${CEND}"; Nginx_version=Other; }
[ "$Nginx_version" != '4' -a -e "$openresty_install_dir/nginx/sbin/nginx" ] && { echo "${CWARNING}OpenResty already installed! ${CEND}"; Nginx_version=Other; }

# check if Apache has been installed
[ "$Apache_version" != '3' -a -e "$apache_install_dir/conf/httpd.conf" ] && { echo "${CWARNING}Aapche already installed! ${CEND}"; Apache_version=Other; }

# check if Tomcat has been installed
[ "$Tomcat_version" != '3' -a -e "$tomcat_install_dir/conf/server.xml" ] && { echo "${CWARNING}Tomcat already installed! ${CEND}" ; Tomcat_version=Other; }

# check if Database has been installed
[ -d "$db_install_dir/support-files" ] && { echo "${CWARNING}Database already installed! ${CEND}"; DB_yn=Other; }

# check if PHP has been installed
[ -e "$php_install_dir/bin/phpize" ] && { echo "${CWARNING}PHP already installed! ${CEND}"; PHP_yn=Other; }

# check if pureftpd has been installed
[ "$FTP_yn" == 'y' -a -e "$pureftpd_install_dir/sbin/pure-ftpwho" ] && { echo "${CWARNING}Pure-FTPd already installed! ${CEND}"; FTP_yn=Other; }

# check if phpMyAdmin has been installed
[ "$phpMyAdmin_yn" == 'y' -a -d "$wwwroot_dir/default/phpMyAdmin" ] && { echo "${CWARNING}phpMyAdmin already installed! ${CEND}"; phpMyAdmin_yn=Other; }

# check if HHVM has been installed
if [ "$HHVM_yn" == 'y' ]; then
  [ -e "/usr/bin/hhvm" ] && { echo "${CWARNING}HHVM already installed! ${CEND}"; HHVM_yn=Other; break; }
  if [ "$OS" == 'CentOS' -a "$OS_BIT" == '64' ] && [ -n "`grep -E ' 7\.| 6\.[5-9]' /etc/redhat-release`" ]; then
    break
  else
    echo
    echo "${CWARNING}HHVM only support CentOS6.5+ 64bit, CentOS7 64bit! ${CEND}"
    echo "Press Ctrl+c to cancel or Press any key to continue..."
    char=`get_char`
    HHVM_yn=Other
  fi
fi

# get the IP information
IPADDR=`./include/get_ipaddr.py`
PUBLIC_IPADDR=`./include/get_public_ipaddr.py`
IPADDR_COUNTRY_ISP=`./include/get_ipaddr_state.py $PUBLIC_IPADDR`
IPADDR_COUNTRY=`echo $IPADDR_COUNTRY_ISP | awk '{print $1}'`
[ "`echo $IPADDR_COUNTRY_ISP | awk '{print $2}'`"x == '1000323'x ] && IPADDR_ISP=aliyun

# Check binary dependencies packages
. ./include/check_sw.sh
case "${OS}" in
  "CentOS")
    installDepsCentOS 2>&1 | tee ${oneinstack_dir}/install.log
    ;;
  "Debian")
    installDepsDebian 2>&1 | tee ${oneinstack_dir}/install.log
    ;;
  "Ubuntu")
    installDepsUbuntu 2>&1 | tee ${oneinstack_dir}/install.log
    ;;
esac

# init
. ./include/memory.sh
case "${OS}" in
  "CentOS")
    . include/init_CentOS.sh 2>&1 | tee -a ${oneinstack_dir}/install.log
    [ -n "$(gcc --version | head -n1 | grep '4\.1\.')" ] && export CC="gcc44" CXX="g++44"
    ;;
  "Debian")
    . include/init_Debian.sh 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  "Ubuntu")
    . include/init_Ubuntu.sh 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
esac

# Check download source packages
. ./include/check_download.sh
downloadDepsSrc=1
checkDownload 2>&1 | tee -a ${oneinstack_dir}/install.log

# Install dependencies from source package
installDepsBySrc 2>&1 | tee -a ${oneinstack_dir}/install.log

# Jemalloc
if [[ $Nginx_version =~ ^[1-3]$ ]] || [ "$DB_yn" == 'y' -a "$DB_version" != '10' ]; then
  . include/jemalloc.sh
  Install_Jemalloc | tee -a $oneinstack_dir/install.log
fi

# openSSL
. ./include/openssl.sh
if [ "$Debian_version" == '8' -o "$Ubuntu_version" == '16' ] && [ "$PHP_version" == '1' ]; then
  # Problem building php-5.3 with openssl
  Install_openSSL100 | tee -a $oneinstack_dir/install.log
fi
if [[ $Tomcat_version =~ ^[1-3]$ ]] || [ "$DB_yn" == 'y' -a "$Apache_version" == '1' ]; then
  Install_openSSL102 | tee -a $oneinstack_dir/install.log
fi

# Database
if [ "$DB_yn" == 'y' ]; then
  if [ -e "/root/account.log" ] && [ -n "`grep ^dbrootpwd /root/account.log`" ]; then
    dbrootpwd=`cat /root/account.log | grep ^dbrootpwd | awk '{print $3}'`
  else
    dbrootpwd=`head -c 100 /dev/urandom | tr -dc a-z0-9A-Z | head -c 16`
    echo "dbrootpwd = ${dbrootpwd}" >> /root/account.log
    chmod a-r /root/account.log
  fi
  case "${DB_version}" in
    1)
      if [ "${dbInstallMethods}" == "2" ]; then
        . include/boost.sh
        installBoost 2>&1 | tee -a ${oneinstack_dir}/install.log
      fi
      . include/mysql-5.7.sh
      Install_MySQL57 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    2)
      . include/mysql-5.6.sh
      Install_MySQL56 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    3)
      . include/mysql-5.5.sh
      Install_MySQL55 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    4)
      if [ "${dbInstallMethods}" == "2" ]; then
        . include/boost.sh
        installBoost 2>&1 | tee -a ${oneinstack_dir}/install.log
      fi
      . include/mariadb-10.1.sh
      Install_MariaDB101 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    5)
      . include/mariadb-10.0.sh
      Install_MariaDB100 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    6)
      . include/mariadb-5.5.sh
      Install_MariaDB55 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    7)
      if [ "${dbInstallMethods}" == "2" ]; then
        . include/boost.sh
        installBoost 2>&1 | tee -a ${oneinstack_dir}/install.log
      fi
      . include/percona-5.7.sh
      Install_Percona57 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    8)
      . include/percona-5.6.sh
      Install_Percona56 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    9)
      . include/percona-5.5.sh
      Install_Percona55 2>&1 | tee -a ${oneinstack_dir}/install.log
      ;;
    10)
      . include/alisql-5.6.sh
      Install_AliSQL56 2>&1 | tee -a $oneinstack_dir/install.log
      ;;
  esac
fi

# Apache
if [ "$Apache_version" == '1' ]; then
  . include/apache-2.4.sh
  Install_Apache24 2>&1 | tee -a $oneinstack_dir/install.log
elif [ "$Apache_version" == '2' ]; then
  . include/apache-2.2.sh
  Install_Apache22 2>&1 | tee -a $oneinstack_dir/install.log
fi

# PHP
case "${PHP_version}" in
  1)
    . include/php-5.3.sh
    Install_PHP53 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  2)
    . include/php-5.4.sh
    Install_PHP54 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  3)
    . include/php-5.5.sh
    Install_PHP55 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  4)
    . include/php-5.6.sh
    Install_PHP56 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  5)
    . include/php-7.0.sh
    Install_PHP70 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  6)
    . include/php-7.1.sh
    Install_PHP71 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
esac

# ImageMagick or GraphicsMagick
if [ "$Magick" == '1' ]; then
  . include/ImageMagick.sh
  [ ! -d "/usr/local/imagemagick" ] && Install_ImageMagick 2>&1 | tee -a $oneinstack_dir/install.log
  [ ! -e "`$php_install_dir/bin/php-config --extension-dir`/imagick.so" ] && Install_php-imagick 2>&1 | tee -a $oneinstack_dir/install.log
elif [ "$Magick" == '2' ]; then
  . include/GraphicsMagick.sh
  [ ! -d "/usr/local/graphicsmagick" ] && Install_GraphicsMagick 2>&1 | tee -a $oneinstack_dir/install.log
  [ ! -e "`$php_install_dir/bin/php-config --extension-dir`/gmagick.so" ] && Install_php-gmagick 2>&1 | tee -a $oneinstack_dir/install.log
fi

# ionCube
if [ "$ionCube_yn" == 'y' ]; then
  . include/ioncube.sh
  Install_ionCube 2>&1 | tee -a $oneinstack_dir/install.log
fi

# PHP opcode cache
case "${PHP_cache}" in
  1)
    if [[ "${PHP_version}" =~ ^[1,2]$ ]]; then
      . include/zendopcache.sh
      Install_ZendOPcache 2>&1 | tee -a ${oneinstack_dir}/install.log
    fi
    ;;
  2)
    . include/xcache.sh
    Install_XCache 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  3)
    . include/apcu.sh
    Install_APCU 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  4)
    if [[ "${PHP_version}" =~ ^[1,2]$ ]]; then
      . include/eaccelerator.sh
      Install_eAccelerator 2>&1 | tee -a ${oneinstack_dir}/install.log
    fi
    ;;
esac

# ZendGuardLoader (php <= 5.6)
if [ "$ZendGuardLoader_yn" == 'y' ]; then
  . include/ZendGuardLoader.sh
  Install_ZendGuardLoader 2>&1 | tee -a $oneinstack_dir/install.log
fi

# Web server
case "${Nginx_version}" in
  1)
    . include/nginx.sh
    Install_Nginx 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  2)
    . include/tengine.sh
    Install_Tengine 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  3)
    . include/openresty.sh
    Install_OpenResty 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
esac

# JDK
case "${JDK_version}" in
  1)
    . include/jdk-1.8.sh
    Install-JDK18 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  2)
    . include/jdk-1.7.sh
    Install-JDK17 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  3)
    . include/jdk-1.6.sh
    Install-JDK16 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
esac

case "${Tomcat_version}" in
  1)
    . include/tomcat-8.sh
    Install_Tomcat8 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  2)
    . include/tomcat-7.sh
    Install_Tomcat7 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  3)
    . include/tomcat-6.sh
    Install_Tomcat6 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
esac

# Pure-FTPd
if [ "${FTP_yn}" == 'y' ]; then
  . include/pureftpd.sh
  Install_PureFTPd 2>&1 | tee -a ${oneinstack_dir}/install.log
fi

# phpMyAdmin
if [ "${phpMyAdmin_yn}" == 'y' ]; then
  . include/phpmyadmin.sh
  Install_phpMyAdmin 2>&1 | tee -a ${oneinstack_dir}/install.log
fi

# redis
if [ "${redis_yn}" == 'y' ]; then
  . include/redis.sh
  [ ! -d "${redis_install_dir}" ] && Install_redis-server 2>&1 | tee -a ${oneinstack_dir}/install.log
  [ -e "${php_install_dir}/bin/phpize" ] && [ ! -e "$(${php_install_dir}/bin/php-config --extension-dir)/redis.so" ] && Install_php-redis 2>&1 | tee -a ${oneinstack_dir}/install.log
fi

# memcached
if [ "${memcached_yn}" == 'y' ]; then
  . include/memcached.sh
  [ ! -d "${memcached_install_dir}/include/memcached" ] && Install_memcached 2>&1 | tee -a ${oneinstack_dir}/install.log
  [ -e "${php_install_dir}/bin/phpize" ] && [ ! -e "$(${php_install_dir}/bin/php-config --extension-dir)/memcache.so" ] && Install_php-memcache 2>&1 | tee -a ${oneinstack_dir}/install.log
  [ -e "${php_install_dir}/bin/phpize" ] && [ ! -e "$(${php_install_dir}/bin/php-config --extension-dir)/memcached.so" ] && Install_php-memcached 2>&1 | tee -a ${oneinstack_dir}/install.log
fi

# index example
if [ ! -e "${wwwroot_dir}/default/index.html" -a "${Web_yn}" == 'y' ]; then
  . include/demo.sh
  DEMO 2>&1 | tee -a ${oneinstack_dir}/install.log
fi

# get web_install_dir and db_install_dir
. include/check_dir.sh

# HHVM
if [ "${HHVM_yn}" == 'y' ]; then
  . include/hhvm_CentOS.sh
  Install_hhvm_CentOS 2>&1 | tee -a ${oneinstack_dir}/install.log
fi

# Starting DB
[ -d "/etc/mysql" ] && /bin/mv /etc/mysql{,_bk}
[ -d "${db_install_dir}/support-files" -a -z "$(ps -ef | grep -v grep | grep mysql)" ] && /etc/init.d/mysqld start

echo "####################Congratulations########################"
[ "${Web_yn}" == 'y' -a "${Nginx_version}" != '4' -a "${Apache_version}" == '3' ] && echo -e "\n$(printf "%-32s" "Nginx install dir":)${CMSG}${web_install_dir}${CEND}"
[ "${Web_yn}" == 'y' -a "${Nginx_version}" != '4' -a "${Apache_version}" != '3' ] && echo -e "\n$(printf "%-32s" "Nginx install dir":)${CMSG}${web_install_dir}${CEND}\n$(printf "%-32s" "Apache install  dir":)${CMSG}${apache_install_dir}${CEND}"
[ "${Web_yn}" == 'y' -a "${Nginx_version}" == '4' -a "${Apache_version}" != '3' ] && echo -e "\n$(printf "%-32s" "Apache install dir":)${CMSG}${apache_install_dir}${CEND}"
[[ "${Tomcat_version}" =~ ^[1,2]$ ]] && echo -e "\n$(printf "%-32s" "Tomcat install dir":)${CMSG}${tomcat_install_dir}${CEND}"
[ "${DB_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "Database install dir:")${CMSG}${db_install_dir}${CEND}"
[ "${DB_yn}" == 'y' ] && echo "$(printf "%-32s" "Database data dir:")${CMSG}${db_data_dir}${CEND}"
[ "${DB_yn}" == 'y' ] && echo "$(printf "%-32s" "Database user:")${CMSG}root${CEND}"
[ "${DB_yn}" == 'y' ] && echo "$(printf "%-32s" "Database password:")${CMSG}${dbrootpwd}${CEND}"
[ "${PHP_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "PHP install dir:")${CMSG}${php_install_dir}${CEND}"
[ "${PHP_cache}" == '1' ] && echo "$(printf "%-32s" "Opcache Control Panel url:")${CMSG}http://${IPADDR}/ocp.php${CEND}"
[ "${PHP_cache}" == '2' ] && echo "$(printf "%-32s" "xcache Control Panel url:")${CMSG}http://${IPADDR}/xcache${CEND}"
[ "${PHP_cache}" == '2' ] && echo "$(printf "%-32s" "xcache user:")${CMSG}admin${CEND}"
[ "${PHP_cache}" == '2' ] && echo "$(printf "%-32s" "xcache password:")${CMSG}${xcache_admin_pass}${CEND}"
[ "${PHP_cache}" == '3' ] && echo "$(printf "%-32s" "APC Control Panel url:")${CMSG}http://${IPADDR}/apc.php${CEND}"
[ "${PHP_cache}" == '4' ] && echo "$(printf "%-32s" "eAccelerator Control Panel url:")${CMSG}http://${IPADDR}/control.php${CEND}"
[ "${PHP_cache}" == '4' ] && echo "$(printf "%-32s" "eAccelerator user:")${CMSG}admin${CEND}"
[ "${PHP_cache}" == '4' ] && echo "$(printf "%-32s" "eAccelerator password:")${CMSG}eAccelerator${CEND}"
[ "${FTP_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "Pure-FTPd install dir:")${CMSG}${pureftpd_install_dir}${CEND}"
[ "${FTP_yn}" == 'y' ] && echo "$(printf "%-32s" "Create FTP virtual script:")${CMSG}./pureftpd_vhost.sh${CEND}"
[ "${phpMyAdmin_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "phpMyAdmin dir:")${CMSG}${wwwroot_dir}/default/phpMyAdmin${CEND}"
[ "${phpMyAdmin_yn}" == 'y' ] && echo "$(printf "%-32s" "phpMyAdmin Control Panel url:")${CMSG}http://${IPADDR}/phpMyAdmin${CEND}"
[ "${redis_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "redis install dir:")${CMSG}${redis_install_dir}${CEND}"
[ "${memcached_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "memcached install dir:")${CMSG}${memcached_install_dir}${CEND}"
[ "${Web_yn}" == 'y' ] && echo -e "\n$(printf "%-32s" "index url:")${CMSG}http://${IPADDR}/${CEND}"
while :; do echo
  echo "${CMSG}Please restart the server and see if the services start up fine.${CEND}"
  read -p "Do you want to restart OS ? [y/n]: " restart_yn
  if [[ ! "${restart_yn}" =~ ^[y,n]$ ]]; then
    echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
  else
    break
  fi
done
[ "${restart_yn}" == 'y' ] && reboot
