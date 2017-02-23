#!/bin/bash
# Author:  Alpha Eva <kaneawk AT gmail.com>
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack

installDepsDebian() {
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  pkgList="apache2 apache2-data apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-mpm-worker mysql-client mysql-server mysql-common libmysqlclient18 php5 php5-common php5-cgi php5-mysql php5-curl php5-gd libmysql* mysql-*"
  for Package in ${pkgList};do
      apt-get -y remove --purge ${Package}
  done
  dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P

  apt-get -y update
  echo "${CMSG}Installing dependencies packages...${CEND}"
  # critical security updates
  grep security /etc/apt/sources.list > /tmp/security.sources.list
  apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

  apt-get autoremove

  # Install needed packages
  case "${Debian_version}" in
    [6,7])
      pkgList="gcc g++ make cmake autoconf libjpeg8 libjpeg8-dev libjpeg-dev libpng12-0 libpng12-dev libpng3 libfreetype6 libfreetype6-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3 libcurl4-openssl-dev libcurl4-gnutls-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl libssl-dev libtool libevent-dev bison re2c libsasl2-dev libxslt1-dev libicu-dev locales libcloog-ppl0 patch vim zip unzip tmux htop bc dc expect rsync git lsof lrzsz iptables rsyslog cron logrotate ntpdate libsqlite3-dev psmisc wget"
      ;;
    8)
      pkgList="gcc g++ make cmake autoconf libjpeg8 libjpeg62-turbo-dev libjpeg-dev libpng12-0 libpng12-dev libpng3 libfreetype6 libfreetype6-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3 libcurl4-openssl-dev libcurl4-gnutls-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl libssl-dev libtool libevent-dev bison re2c libsasl2-dev libxslt1-dev libicu-dev locales libcloog-ppl0 patch vim zip unzip tmux htop bc dc expect rsync git lsof lrzsz iptables rsyslog cron logrotate ntpdate libsqlite3-dev psmisc wget"
      ;;
    *)
      echo "${CFAILURE}Your system Debian ${Debian_version} are not supported!${CEND}"
      kill -9 $$
      ;;
  esac

  for Package in ${pkgList}; do
    apt-get -y install ${Package}
  done
}

installDepsCentOS() {
  sed -i 's@^exclude@#exclude@' /etc/yum.conf
  yum clean all

  yum makecache
  # Uninstall the conflicting packages
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${CentOS_RHEL_version}" == '7' ]; then
    yum -y groupremove "Basic Web Server" "MySQL Database server" "MySQL Database client" "File and Print Server"
    yum -y install iptables-services
    systemctl mask firewalld.service
    systemctl enable iptables.service
  elif [ "${CentOS_RHEL_version}" == '6' ]; then
    yum -y groupremove "FTP Server" "PostgreSQL Database client" "PostgreSQL Database server" "MySQL Database server" "MySQL Database client" "Web Server" "Office Suite and Productivity" "E-mail server" "Ruby Support" "Printing client"
  elif [ "${CentOS_RHEL_version}" == '5' ]; then
    yum -y groupremove "FTP Server" "Windows File Server" "PostgreSQL Database" "News Server" "MySQL Database" "DNS Name Server" "Web Server" "Dialup Networking Support" "Mail Server" "Ruby" "Office/Productivity" "Sound and Video" "Printing Support" "OpenFabrics Enterprise Distribution"
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  yum check-update
  # Install needed packages
  pkgList="deltarpm gcc gcc-c++ make cmake autoconf libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel glibc glibc-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel libaio numactl-libs readline-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel libxslt-devel libicu-devel libevent-devel libtool libtool-ltdl bison gd-devel vim-enhanced pcre-devel zip unzip ntpdate sqlite-devel sysstat patch bc expect rsync rsyslog git lsof lrzsz wget"
  for Package in ${pkgList}; do
    yum -y install ${Package}
  done

  yum -y update bash openssl glibc

  # use gcc-4.4
  if [ -n "$(gcc --version | head -n1 | grep '4\.1\.')" ]; then
    yum -y install gcc44 gcc44-c++ libstdc++44-devel
    export CC="gcc44" CXX="g++44"
  fi
}

installDepsUbuntu() {
  # Uninstall the conflicting software
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  pkgList="apache2 apache2-data apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-mpm-worker mysql-client mysql-server mysql-common libmysqlclient18 php5 php5-common php5-cgi php5-mysql php5-curl php5-gd libmysql* mysql-*"
  for Package in ${pkgList}; do
    apt-get -y remove --purge ${Package}
  done
  dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P

  apt-get autoremove

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  # critical security updates
  grep security /etc/apt/sources.list > /tmp/security.sources.list
  apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

  # Install needed packages
  pkgList="gcc g++ make cmake autoconf libjpeg8 libjpeg8-dev libpng12-0 libpng12-dev libpng3 libfreetype6 libfreetype6-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3 libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev patch vim zip unzip tmux htop bc dc expect iptables rsyslog rsync git lsof lrzsz ntpdate wget"
  for Package in ${pkgList}; do
    apt-get -y install ${Package} --force-yes
  done

  if [[ "${Ubuntu_version}" =~ ^14$|^15$ ]]; then
    apt-get -y install libcloog-ppl1
    apt-get -y remove bison
    ln -sf /usr/include/freetype2 /usr/include/freetype2/freetype
  elif [ "${Ubuntu_version}" == "13" ]; then
    apt-get -y install bison libcloog-ppl1
  elif [ "${Ubuntu_version}" == "12" ]; then
    apt-get -y install bison libcloog-ppl0
  else
    apt-get -y install bison libcloog-ppl1
  fi
}

installDepsBySrc() {
  pushd ${oneinstack_dir}/src

  if [ "${OS}" == "Ubuntu" ]; then
    if [[ "${Ubuntu_version}" =~ ^14$|^15$ ]]; then
      # Install bison on ubt 14.x 15.x
      tar xzf bison-${bison_version}.tar.gz
      pushd bison-${bison_version}
      ./configure
      make -j ${THREAD} && make install
      popd
      rm -rf bison-${bison_version}
    fi
  elif [ "${OS}" == "CentOS" ]; then
    # Install tmux
    if [ ! -e "$(which tmux)" ]; then
      # Install libevent first
      tar xzf libevent-${libevent_version}.tar.gz
      pushd libevent-${libevent_version}
      ./configure
      make -j ${THREAD} && make install
      popd
      rm -rf libevent-${libevent_version}

      tar xzf tmux-${tmux_version}.tar.gz
      pushd tmux-${tmux_version}
      CFLAGS="-I/usr/local/include" LDFLAGS="-L//usr/local/lib" ./configure
      make -j ${THREAD} && make install
      unset LDFLAGS
      popd
      rm -rf tmux-${tmux_version}

      if [ "${OS_BIT}" == "64" ]; then
        ln -s /usr/local/lib/libevent-2.0.so.5 /usr/lib64/libevent-2.0.so.5
      else
        ln -s /usr/local/lib/libevent-2.0.so.5 /usr/lib/libevent-2.0.so.5
      fi
    fi

    # install htop
    if [ ! -e "$(which htop)" ]; then
      tar xzf htop-${htop_version}.tar.gz
      pushd htop-${htop_version}
      ./configure
      make -j ${THREAD} && make install
      popd
      rm -rf htop-${htop_version}
    fi
  else
    echo "No need to install software from source packages."
  fi
  popd
}
