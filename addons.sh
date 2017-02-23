#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#                    Install/Uninstall Extensions                     #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"

# get pwd
sed -i "s@^oneinstack_dir.*@oneinstack_dir=$(pwd)@" ./options.conf

. ./versions.txt
. ./options.conf
. ./include/color.sh
. ./include/memory.sh
. ./include/check_os.sh
. ./include/check_download.sh
. ./include/download.sh
. ./include/get_char.sh

. ./include/zendopcache.sh
. ./include/xcache.sh
. ./include/apcu.sh
. ./include/eaccelerator.sh

. ./include/ZendGuardLoader.sh
. ./include/ioncube.sh

. ./include/ImageMagick.sh
. ./include/GraphicsMagick.sh

. ./include/memcached.sh

. ./include/redis.sh

. ./include/python.sh

# Check if user is root
[ $(id -u) != '0' ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

# Check PHP
if [ -e "${php_install_dir}/bin/phpize" ]; then
  phpExtensionDir=$(${php_install_dir}/bin/php-config --extension-dir)
  PHP_detail_version=$(${php_install_dir}/bin/php -r 'echo PHP_VERSION;')
  PHP_main_version=${PHP_detail_version%.*}

  case "${PHP_main_version}" in
    "5.3")
      PHP_version=1
      ;;
    "5.4")
      PHP_version=2
      ;;
    "5.5")
      PHP_version=3
      ;;
    "5.6")
      PHP_version=4
      ;;
    "7.0" | "7.1")
      PHP_version=5
      ;;
    *)
      echo "${CFAILURE}Your PHP version ${PHP_main_version} is not supported! ${CEND}"
      kill -9 $$
      ;;
  esac
fi

# Check PHP Extensions
Check_PHP_Extension() {
  [ -e "${php_install_dir}/etc/php.d/ext-${PHP_extension}.ini" ] && { echo "${CWARNING}PHP ${PHP_extension} module already installed! ${CEND}"; exit 1; }
}

# restart PHP
Restart_PHP() {
  [ -e "${apache_install_dir}/conf/httpd.conf" ] && /etc/init.d/httpd restart || /etc/init.d/php-fpm restart
}

# Check succ
Check_succ() {
  [ -f "${phpExtensionDir}/${PHP_extension}.so" ] && { Restart_PHP; echo;echo "${CSUCCESS}PHP ${PHP_extension} module installed successfully! ${CEND}"; }
}

# Uninstall succ
Uninstall_succ() {
  [ -e "${php_install_dir}/etc/php.d/ext-${PHP_extension}.ini" ] && { rm -rf ${php_install_dir}/etc/php.d/ext-${PHP_extension}.ini; Restart_PHP; echo; echo "${CMSG}PHP ${PHP_extension} module uninstall completed${CEND}"; } || { echo; echo "${CWARNING}${PHP_extension} module does not exist! ${CEND}"; }
}

Install_letsencrypt() {
  [ ! -e "${python_install_dir}/bin/python" ] && Install_Python
  ${python_install_dir}/bin/pip install certbot
  if [ -e "${python_install_dir}/bin/certbot" ]; then
    echo; echo "${CSUCCESS}Let's Encrypt client installed successfully! ${CEND}"
  else
    echo; echo "${CFAILURE}Let's Encrypt client install failed, Please try again! ${CEND}"
  fi
}

Uninstall_letsencrypt() {
  ${python_install_dir}/bin/pip uninstall -y certbot > /dev/null 2>&1
  rm -rf /etc/letsencrypt /var/log/letsencrypt /var/lib/letsencrypt ${python_install_dir}
  [ "${OS}" == "CentOS" ] && Cron_file=/var/spool/cron/root || Cron_file=/var/spool/cron/crontabs/root
  [ -e "$Cron_file" ] && sed -i '/certbot/d' ${Cron_file}
  echo; echo "${CMSG}Let's Encrypt client uninstall completed${CEND}";
}

Install_fail2ban() {
  [ ! -e "${python_install_dir}/bin/python" ] && Install_Python
  pushd ${oneinstack_dir}/src
  src_url=http://mirrors.linuxeye.com/oneinstack/src/fail2ban-${fail2ban_version}.tar.gz && Download_src
  tar xzf fail2ban-${fail2ban_version}.tar.gz
  pushd fail2ban-${fail2ban_version}
  ${python_install_dir}/bin/python setup.py install
  /bin/cp /etc/fail2ban/jail.{conf,local}
  sed -i 's@^# \[sshd\]@[sshd]@' /etc/fail2ban/jail.local
  sed -i 's@^# enabled = true@enabled = true@' /etc/fail2ban/jail.local
  if [ "${OS}" == "CentOS" ]; then
    sed -i 's@%(sshd_log)s@/var/log/secure@' /etc/fail2ban/jail.local
    /bin/cp files/redhat-initd /etc/init.d/fail2ban 
    sed -i "s@^FAIL2BAN=.*@FAIL2BAN=${python_install_dir}/bin/fail2ban-client@" /etc/init.d/fail2ban
    chmod +x /etc/init.d/fail2ban
    chkconfig --add fail2ban
    chkconfig fail2ban on
  fi
  if [[ "${OS}" =~ ^Ubuntu$|^Debian$ ]]; then
    /bin/cp files/debian-initd /etc/init.d/fail2ban 
    sed -i 's@2 3 4 5@3 4 5@' /etc/init.d/fail2ban
    sed -i "s@^DAEMON=.*@DAEMON=${python_install_dir}/bin/\$NAME-client@" /etc/init.d/fail2ban
    chmod +x /etc/init.d/fail2ban
    update-rc.d fail2ban defaults
  fi
  cat > /etc/logrotate.d/fail2ban << EOF 
/var/log/fail2ban.log {
    missingok
    notifempty
    postrotate
      ${python_install_dir}/bin/fail2ban-client flushlogs >/dev/null || true
    endscript
}
EOF
  kill -9 `ps -ef | grep fail2ban | grep -v grep | awk '{print $2}'`
  /etc/init.d/fail2ban start
  popd
  if [ -e "${python_install_dir}/bin/fail2ban-python" ]; then
    echo; echo "${CSUCCESS}fail2ban installed successfully! ${CEND}"
  else
    echo; echo "${CFAILURE}fail2ban install failed, Please try again! ${CEND}"
  fi
  popd
}

Uninstall_fail2ban() {
  /etc/init.d/fail2ban stop
  ${python_install_dir}/bin/pip uninstall -y fail2ban > /dev/null 2>&1
  rm -rf /etc/init.d/fail2ban /etc/fail2ban /etc/logrotate.d/fail2ban /var/log/fail2ban.* /var/run/fail2ban 
  echo; echo "${CMSG}fail2ban uninstall completed${CEND}";
}

ACTION_FUN() {
  while :; do
    echo
    echo "Please select an action:"
    echo -e "\t${CMSG}1${CEND}. install"
    echo -e "\t${CMSG}2${CEND}. uninstall"
    read -p "Please input a number:(Default 1 press Enter) " ACTION
    [ -z "${ACTION}" ] && ACTION=1
    if [[ ! "${ACTION}" =~ ^[1,2]$ ]]; then
      echo "${CWARNING}input error! Please only input number 1,2${CEND}"
    else
      break
    fi
  done
}

while :;do
  printf "
What Are You Doing?
\t${CMSG}1${CEND}. Install/Uninstall PHP opcode cache
\t${CMSG}2${CEND}. Install/Uninstall ZendGuardLoader/ionCube PHP Extension
\t${CMSG}3${CEND}. Install/Uninstall ImageMagick/GraphicsMagick PHP Extension
\t${CMSG}4${CEND}. Install/Uninstall fileinfo PHP Extension
\t${CMSG}5${CEND}. Install/Uninstall memcached/memcache
\t${CMSG}6${CEND}. Install/Uninstall Redis
\t${CMSG}7${CEND}. Install/Uninstall Let's Encrypt client
\t${CMSG}8${CEND}. Install/Uninstall fail2ban 
\t${CMSG}q${CEND}. Exit
"
  read -p "Please input the correct option: " Number
  if [[ ! "${Number}" =~ ^[1-8,q]$ ]]; then
    echo "${CFAILURE}input error! Please only input 1 ~ 8 and q${CEND}"
  else
    case "${Number}" in
      1)
        ACTION_FUN
        while :; do echo
          echo "Please select a opcode cache of the PHP:"
          echo -e "\t${CMSG}1${CEND}. Zend OPcache"
          echo -e "\t${CMSG}2${CEND}. XCache"
          echo -e "\t${CMSG}3${CEND}. APCU"
          echo -e "\t${CMSG}4${CEND}. eAccelerator"
          read -p "Please input a number:(Default 1 press Enter) " PHP_cache
          [ -z "${PHP_cache}" ] && PHP_cache=1
          if [[ ! "${PHP_cache}" =~ ^[1-4]$ ]]; then
            echo "${CWARNING}input error! Please only input number 1,2,3,4${CEND}"
          else
            case "${PHP_cache}" in
              1)
                PHP_extension=opcache
                ;;
              2)
                PHP_extension=xcache
                ;;
              3)
                PHP_extension=apcu
                ;;
              4)
                PHP_extension=eaccelerator
                ;;
            esac
            break
          fi
        done
        if [ "${ACTION}" = '1' ]; then
          Check_PHP_Extension
          if [ -e ${php_install_dir}/etc/php.d/ext-ZendGuardLoader.ini ]; then
            echo; echo "${CWARNING}You have to install ZendGuardLoader, You need to uninstall it before install ${PHP_extension}! ${CEND}"; echo; exit 1
          else
            case "${PHP_cache}" in
              1)
                pushd ${oneinstack_dir}/src
                if [[ "${PHP_main_version}" =~ ^5.[3-4]$ ]]; then
                  src_url=https://pecl.php.net/get/zendopcache-${zendopcache_version}.tgz && Download_src
                  Install_ZendOPcache
                else
                  src_url=http://www.php.net/distributions/php-${PHP_detail_version}.tar.gz && Download_src
                  Install_ZendOPcache
                fi
                popd
                Check_succ
                ;;
              2)
                if [[ ${PHP_main_version} =~ ^5.[3-6]$ ]]; then
                  while :; do
                    read -p "Please input xcache admin password: " xcache_admin_pass
                    (( ${#xcache_admin_pass} >= 5 )) && { xcache_admin_md5_pass=$(echo -n "${xcache_admin_pass}" | md5sum | awk '{print $1}') ; break ; } || echo "${CFAILURE}xcache admin password least 5 characters! ${CEND}"
                  done
                  checkDownload
                  Install_XCache
                  Check_succ
                else
                  echo "${CWARNING}Your php does not support XCache! ${CEND}"; exit 1
                fi
                ;;
              3)
                if [[ "${PHP_main_version}" =~ ^5.[3-6]$|^7.[0-1]$ ]]; then
                  checkDownload
                  Install_APCU
                  Check_succ
                else
                  echo "${CWARNING}Your php does not support APCU! ${CEND}"; exit 1
                fi
                ;;
              4)
                if [[ "${PHP_main_version}" =~ ^5.[3-4]$ ]]; then
                  checkDownload
                  Install_eAccelerator
                  Check_succ
                else
                  echo "${CWARNING}Your php does not support eAccelerator! ${CEND}"; exit 1
                fi
                ;;
            esac
          fi
        else
          Uninstall_succ
        fi
        ;;
      2)
        ACTION_FUN
        while :; do echo
          echo "Please select ZendGuardLoader/ionCube:"
          echo -e "\t${CMSG}1${CEND}. ZendGuardLoader"
          echo -e "\t${CMSG}2${CEND}. ionCube Loader"
          read -p "Please input a number:(Default 1 press Enter) " Loader
          [ -z "${Loader}" ] && Loader=1
          if [[ ! "${Loader}" =~ ^[1,2]$ ]]; then
            echo "${CWARNING}input error! Please only input number 1,2${CEND}"
          else
            [ "${Loader}" = '1' ] && PHP_extension=ZendGuardLoader
            [ "${Loader}" = '2' ] && PHP_extension=0ioncube
            break
          fi
        done
        if [ "${ACTION}" = '1' ]; then
          Check_PHP_Extension
          if [ "${Loader}" = '1' ]; then
            if [[ "${PHP_main_version}" =~ ^5.[3-6]$ ]] || [ "${armPlatform}" != 'y' ]; then
              if [ -e ${php_install_dir}/etc/php.d/ext-opcache.ini ]; then
                echo; echo "${CWARNING}You have to install OpCache, You need to uninstall it before install ZendGuardLoader! ${CEND}"; echo; exit 1
              else
                ZendGuardLoader_yn='y' && checkDownload
                Install_ZendGuardLoader
                Check_succ
              fi
            else
              echo; echo "${CWARNING}Your php ${PHP_detail_version} or platform ${TARGET_ARCH} does not support ${PHP_extension}! ${CEND}";
            fi
          elif [ "${Loader}" = '2' ]; then
            if [[ "${PHP_main_version}" =~ ^5.[3-6]$|^7.0$ ]] || [ "${TARGET_ARCH}" != "arm64" ]; then
              ionCube_yn='y' && checkDownload
              Install_ionCube
              Restart_PHP; echo "${CSUCCESS}PHP ioncube module installed successfully! ${CEND}";
            else
              echo; echo "${CWARNING}Your php ${PHP_detail_version} or platform ${TARGET_ARCH} does not support ${PHP_extension}! ${CEND}";
            fi
          fi
        else
          Uninstall_succ
        fi
        ;;
      3)
        ACTION_FUN
        while :; do echo
          echo "Please select ImageMagick/GraphicsMagick:"
          echo -e "\t${CMSG}1${CEND}. ImageMagick"
          echo -e "\t${CMSG}2${CEND}. GraphicsMagick"
          read -p "Please input a number:(Default 1 press Enter) " Magick
          [ -z "${Magick}" ] && Magick=1
          if [[ ! "${Magick}" =~ ^[1,2]$ ]]; then
            echo "${CWARNING}input error! Please only input number 1,2${CEND}"
          else
            [ "${Magick}" = '1' ] && PHP_extension=imagick
            [ "${Magick}" = '2' ] && PHP_extension=gmagick
            break
          fi
        done
        if [ "${ACTION}" = '1' ]; then
          Check_PHP_Extension
          Magick_yn=y && checkDownload
          if [ "${Magick}" = '1' ]; then
            [ ! -d "/usr/local/imagemagick" ] && Install_ImageMagick
            Install_php-imagick
            Check_succ
          elif [ "${Magick}" = '2' ]; then
            [ ! -d "/usr/local/graphicsmagick" ] && Install_GraphicsMagick
            Install_php-gmagick
            Check_succ
          fi
        else
          Uninstall_succ
          [ -d "/usr/local/imagemagick" ] && rm -rf /usr/local/imagemagick
          [ -d "/usr/local/graphicsmagick" ] && rm -rf /usr/local/graphicsmagick
        fi
        ;;
      4)
        ACTION_FUN
        PHP_extension=fileinfo
        if [ "${ACTION}" = '1' ]; then
          Check_PHP_Extension
          pushd ${oneinstack_dir}/src
          src_url=http://www.php.net/distributions/php-${PHP_detail_version}.tar.gz && Download_src
          tar xzf php-${PHP_detail_version}.tar.gz
          pushd php-${PHP_detail_version}/ext/fileinfo
          ${php_install_dir}/bin/phpize
          ./configure --with-php-config=${php_install_dir}/bin/php-config
          make -j ${THREAD} && make install
          popd;popd
          rm -rf php-${PHP_detail_version}
          echo "extension=fileinfo.so" > ${php_install_dir}/etc/php.d/ext-fileinfo.ini
          Check_succ
        else
          Uninstall_succ
        fi
        ;;
      5)
        ACTION_FUN
        while :; do echo
          echo "Please select memcache/memcached PHP Extension:"
          echo -e "\t${CMSG}1${CEND}. memcache PHP Extension"
          echo -e "\t${CMSG}2${CEND}. memcached PHP Extension"
          echo -e "\t${CMSG}3${CEND}. memcache/memcached PHP Extension"
          read -p "Please input a number:(Default 1 press Enter) " Memcache
          [ -z "${Memcache}" ] && Memcache=1
          if [[ ! "${Memcache}" =~ ^[1-3]$ ]]; then
            echo "${CWARNING}input error! Please only input number 1,2,3${CEND}"
          else
            [ "${Memcache}" = '1' ] && PHP_extension=memcache
            [ "${Memcache}" = '2' ] && PHP_extension=memcached
            break
          fi
        done
        if [ "${ACTION}" = '1' ]; then
          memcached_yn=y && checkDownload
          case "${Memcache}" in
            1)
              [ ! -d "${memcached_install_dir}/include/memcached" ] && Install_memcached
              Check_PHP_Extension
              Install_php-memcache
              Check_succ
              ;;
            2)
              [ ! -d "${memcached_install_dir}/include/memcached" ] && Install_memcached
              Check_PHP_Extension
              Install_php-memcached
              Check_succ
              ;;
            3)
              [ ! -d "${memcached_install_dir}/include/memcached" ] && Install_memcached
              PHP_extension=memcache && Check_PHP_Extension
              Install_php-memcache
              PHP_extension=memcached && Check_PHP_Extension
              Install_php-memcached
              [ -f "${phpExtensionDir}/memcache.so" -a "${phpExtensionDir}/memcached.so" ] && { Restart_PHP; echo;echo "${CSUCCESS}PHP memcache/memcached module installed successfully! ${CEND}"; }
              ;;
          esac
        else
          PHP_extension=memcache && Uninstall_succ
          PHP_extension=memcached && Uninstall_succ
          [ -e "${memcached_install_dir}" ] && { service memcached stop > /dev/null 2>&1; rm -rf ${memcached_install_dir} /etc/init.d/memcached /usr/bin/memcached; }
        fi
        ;;
      6)
        ACTION_FUN
        PHP_extension=redis
        redis_yn=y && checkDownload
        if [ "${ACTION}" = '1' ]; then
          [ ! -d "${redis_install_dir}" ] && Install_redis-server
          Check_PHP_Extension
          Install_php-redis
        else
          Uninstall_succ
          [ -e "${redis_install_dir}" ] && { service redis-server stop > /dev/null 2>&1; rm -rf ${redis_install_dir} /etc/init.d/redis-server /usr/local/bin/redis-*; }
        fi
        ;;
      7)
        ACTION_FUN
        if [ "${ACTION}" = '1' ]; then
          Install_letsencrypt
        else
          Uninstall_letsencrypt
        fi
        ;;
      8)
        ACTION_FUN
        if [ "${ACTION}" = '1' ]; then
          Install_fail2ban
        else
          Uninstall_fail2ban
        fi
        ;;
      q)
      exit
      ;;
    esac
  fi
done
