#!/usr/bin/env bash

function downloadGeoIPFiles() {

  WriteInfo "Remove temporary download directory ..."
  rm -rf "${xt_geoip_tmp_dir}" || { WriteErr "'rm -rf ${xt_geoip_tmp_dir}' failed"; return 1; }

  WriteInfo "Create new temporary download directory ..."
  mkdir -p -m 755 "${xt_geoip_tmp_dir}" || { WriteErr "'mkdir -p -m 755 ${xt_geoip_tmp_dir}' failed"; return 1; }

  WriteInfo "moving into temporary download directory"
  cd "${xt_geoip_tmp_dir}" || { WriteErr "'cd ${xt_geoip_tmp_dir}' failed"; return 1; }

  WriteInfo "Downloading new country files (in ${PWD})"

  for zipfile in ${geoip_zipfiles}
  do
    echo "Downloading '${zipfile}'"
    wget "${geoip_baseurl}/${zipfile}" || { WriteErr "'wget ${geoip_baseurl}/${zipfile}' failed"; return 1; }
  done

  for zipfile in ${geoip_zipfiles}
  do
    echo "Unzippping '${zipfile}'"
    unzip "${zipfile}" || { WriteErr "'unzip ${zipfile}' failed"; return 1; }
  done

  echo "Downloading '${countryinfo_file}'"
  wget "${countryinfo_baseurl}/${countryinfo_file}" || { WriteErr "'wget ${countryinfo_baseurl}/${countryinfo_file}' failed"; return 1; }

  return 0
}

function buildGeoIPDatabase() {

  WriteInfo "moving into temporary download directory"
  cd "${xt_geoip_tmp_dir}" || { WriteErr "'cd ${xt_geoip_tmp_dir}' failed"; return 1; }

  WriteInfo "Building new geoip database (${PWD}) ..."
  for csv_file in $(find "${xt_geoip_tmp_dir}" -type f -name "GeoLite2-Country-Blocks*.csv")
  do
    # see https://github.com/mschmitt/GeoLite2xtables
    echo "Converting '${csv_file}' into a working format (workaround)"
    cat "${csv_file}" | ${GeoLite2xtables_tool} "${countryinfo_file}" > "${csv_file}.converted" || { WriteErr "'${GeoLite2xtables_tool}' failed"; return 1; }
    echo "Processing '${csv_file}.converted'"
    ${xt_geoip_build_tool} "${csv_file}.converted" || { WriteErr "'${xt_geoip_build_tool} ${csv_file}.converted' failed"; return 1; }
  done

  return 0
}

function replaceGeoIPDatabase() {
  rgid_timestamp=$(date +%d%m%Y-%H%M%S)
  rgid_xt_geoip_backup_dir="${xt_geoip_dir}_${rgid_timestamp}"

  if [ -d "${xt_geoip_dir}" ]; then
    WriteInfo "Backup current database directory ..."
    mv "${xt_geoip_dir}" "${rgid_xt_geoip_backup_dir}" || { WriteErr "' mv ${rgid_xt_geoip_dir} ${rgid_xt_geoip_backup_dir}' failed"; return 1; }
  fi

  WriteInfo "Move new database directory in place ..."
  mv "${xt_geoip_tmp_dir}" "${xt_geoip_dir}" || { WriteErr "'mv ${rgid_xt_geoip_tmp_dir} ${rgid_xt_geoip_dir}' failed"; return 1; }

  if [ -d "${rgid_xt_geoip_backup_dir}" ]; then
    WriteInfo "Purge old database directory"
    rm -r "${rgid_xt_geoip_backup_dir}" || { WriteErr "'rm -r ${rgid_xt_geoip_backup_dir}' failed"; return 1; }
  fi

  return 0
}

function WriteInfo() {
  wi_timestamp=$(date +%d/%m/%Y-%H:%M:%S)
  echo "${wi_timestamp}|INFO: ${1}"
}

function WriteWarn() {
  ww_timestamp=$(date +%d/%m/%Y-%H:%M:%S)
  echo "${ww_timestamp}|WARNING: ${1}"
}

function WriteErr() {
  we_timestamp=$(date +%d/%m/%Y-%H:%M:%S)
  echo "${we_timestamp}|ERROR: ${1}"
}

function ExitScript() {
  es_exit_status=${1:=0}
  es_exit_text="${2}"
  [ -z "${es_exit_text}" ] && es_exit_text="Exit with status '${es_exit_status}'"
  if [ ${es_exit_status} -eq 0 ]; then
    WriteInfo "${es_exit_text}"
  else
    WriteErr "${es_exit_text}"
  fi
  exit "${es_exit_status}"
}

# main()

export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

#geoip_zipfiles="GeoLite2-City-CSV.zip
geoip_zipfiles="GeoLite2-Country-CSV.zip"
geoip_baseurl="https://geolite.maxmind.com/download/geoip/database"
countryinfo_baseurl="https://download.geonames.org/export/dump"
countryinfo_file="countryInfo.txt"
GeoLite2xtables_tool="/usr/local/bin/GeoLite2xtables.pl"
xt_geoip_download_tool="/usr/lib/xtables-addons/xt_geoip_dl"
xt_geoip_build_tool="/usr/lib/xtables-addons/xt_geoip_build"
xt_geoip_dir="/usr/share/xt_geoip"
xt_geoip_tmp_dir="/usr/share/xt_geoip_new"

downloadGeoIPFiles || ExitScript 1 "Failed downloading new geoip files"

buildGeoIPDatabase || ExitScript 1 "Failed building new geoip database"

replaceGeoIPDatabase || ExitScript 1 "Failed replacing old geoip database"

ExitScript 0 "Completed geoip database update"
