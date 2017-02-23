#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack

Download_src() {
  [ -s "${src_url##*/}" ] && echo "[${CMSG}${src_url##*/}${CEND}] found" || { wget --tries=6 -c --no-check-certificate $src_url; sleep 1; }
  if [ ! -e "${src_url##*/}" ]; then
    echo "${CFAILURE}${src_url##*/} download failed, Please contact the author! ${CEND}"
    kill -9 $$
  fi
}
