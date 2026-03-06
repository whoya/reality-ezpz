#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -e
declare -A defaults
declare -A config_file
declare -A args
declare -A config
declare -A users
declare -A path
declare -A service
declare -A md5
declare -A regex
declare -A image

config_path="/opt/reality-ezpz"
compose_project='reality-ezpz'
tgbot_project='tgbot'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P || true)"
BACKTITLE=RealityEZPZ
MENU="Select an option:"
HEIGHT=30
WIDTH=60
CHOICE_HEIGHT=20

image[xray]="ghcr.io/xtls/xray-core:26.2.6@sha256:c6daec5244a2110490ec2049d4c6588cbef544a8bcb4b32c5e4da16e15b7f98e"
image[nginx]="nginx:1.27-alpine@sha256:62223d644fa234c3a1cc785ee14242ec47a77364226f1c811d2f669f96dc2ac8"
image[certbot]="certbot/certbot:latest@sha256:850f4e7e1cb2ddb3db57f24fc70480c3787d85a6453917916651c893e0035f3f"
image[haproxy]="haproxy:3.1-alpine@sha256:14cf88b4e53e7cf2c1c87a5468151ee886199d8d68a876d68349d50325720403"
image[wgcf]="virb3/wgcf:latest@sha256:725d294dc1048b4345ca4ca106ccad0c2ffbd4abd04ecdfb74910cc48be9c293"
image[golang]="golang:1.25-alpine@sha256:724e212d86d79b45b7ace725b44ff3b6c2684bfd3131c43d5d60441de151d98e"
image[alpine]="alpine:3.21@sha256:22e0ec13c0db6b3e1ba3280e831fc50ba7bffe58e81f31670a64b1afede247bc"

defaults[transport]=tcp
defaults[domain]=rbc.ru
defaults[fingerprint]=random
defaults[xhttp_mode]=stream-up
defaults[fragment]=OFF
defaults[port]=443
defaults[safenet]=OFF
defaults[warp]=OFF
defaults[warp_license]=""
defaults[warp_private_key]=""
defaults[warp_token]=""
defaults[warp_id]=""
defaults[warp_client_id]=""
defaults[warp_interface_ipv4]=""
defaults[warp_interface_ipv6]=""
defaults[security]=reality
defaults[server]=$(curl -fsSL -m 10 --ipv4 https://cloudflare.com/cdn-cgi/trace | grep ip | cut -d '=' -f2)
defaults[tgbot]=OFF
defaults[tgbot_token]=""
defaults[tgbot_admin_ids]=""
defaults[api_token]=""
defaults[helper_token]=""
defaults[short_ids]=""
defaults[xray_version_min]="26.2.6"
defaults[reality_limit_fallback_upload_after_bytes]="1048576"
defaults[reality_limit_fallback_upload_bytes_per_sec]="32768"
defaults[reality_limit_fallback_upload_burst_bytes_per_sec]="65536"
defaults[reality_limit_fallback_download_after_bytes]="1048576"
defaults[reality_limit_fallback_download_bytes_per_sec]="131072"
defaults[reality_limit_fallback_download_burst_bytes_per_sec]="262144"
defaults[xray_experimental]=OFF
defaults[experimental_user]=""
defaults[experimental_test_seed]=""
defaults[reality_mldsa65_seed]=""
defaults[subscriptions]=OFF
defaults[subscription_path]=sub

config_items=(
  "security"
  "service_path"
  "public_key"
  "private_key"
  "short_id"
  "short_ids"
  "transport"
  "domain"
  "server"
  "port"
  "safenet"
  "warp"
  "warp_license"
  "warp_private_key"
  "warp_token"
  "warp_id"
  "warp_client_id"
  "warp_interface_ipv4"
  "warp_interface_ipv6"
  "tgbot"
  "tgbot_token"
  "tgbot_admin_ids"
  "api_token"
  "helper_token"
  "xray_version_min"
  "reality_limit_fallback_upload_after_bytes"
  "reality_limit_fallback_upload_bytes_per_sec"
  "reality_limit_fallback_upload_burst_bytes_per_sec"
  "reality_limit_fallback_download_after_bytes"
  "reality_limit_fallback_download_bytes_per_sec"
  "reality_limit_fallback_download_burst_bytes_per_sec"
  "xray_experimental"
  "experimental_user"
  "experimental_test_seed"
  "reality_mldsa65_seed"
  "fingerprint"
  "xhttp_mode"
  "fragment"
  "subscriptions"
  "subscription_path"
)

regex[domain]="^[a-zA-Z0-9]+([-.][a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$"
regex[port]="^[1-9][0-9]*$"
regex[warp_license]="^[a-zA-Z0-9]{8}-[a-zA-Z0-9]{8}-[a-zA-Z0-9]{8}$"
regex[username]="^[a-zA-Z0-9]+$"
regex[ip]="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
regex[tgbot_token]="^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$"
regex[tgbot_admin_ids]="^[0-9]+(,[0-9]+)*$"
regex[short_ids]="^[0-9a-fA-F,]+$"
regex[xray_version]="^[0-9]+\\.[0-9]+\\.[0-9]+$"
regex[number]="^[0-9]+$"
regex[test_seed]="^[a-zA-Z0-9._:-]{1,128}$"
regex[mldsa65_seed]="^[a-zA-Z0-9+/=:_-]+$"
regex[fingerprint]="^(chrome|firefox|safari|ios|android|edge|360|qq|random)$"
regex[xhttp_mode]="^(stream-up|packet-up)$"
regex[domain_port]="^[a-zA-Z0-9]+([-.][a-zA-Z0-9]+)*\.[a-zA-Z]{2,}(:[1-9][0-9]*)?$"
regex[file_path]="^[a-zA-Z0-9_/.-]+$"
regex[url]="^(http|https)://([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|[0-9]{1,3}(\.[0-9]{1,3}){3})(:[0-9]{1,5})?(/.*)?$"

function show_help {
  echo ""
  echo "Usage: reality-ezpz.sh [-t|--transport=tcp|http|grpc|ws|xhttp] [-d|--domain=<domain>] [--server=<server>] [--regenerate] [--default]
  [-r|--restart] [--enable-safenet=true|false] [--port=<port>] [--enable-warp=true|false]
  [--warp-license=<license>] [--security=reality|letsencrypt|selfsigned] [-m|--menu] [--show-server-config] [--add-user=<username>] [--list-users]
  [--show-user=<username>] [--delete-user=<username>] [--backup] [--backup-upload-temp] [--restore=<url|file>] [--backup-password=<password>] [-u|--uninstall]"
  echo ""
  echo "  -t, --transport <tcp|http|grpc|ws|xhttp> Transport protocol (default: ${defaults[transport]}; grpc recommended when tcp is blocked)"
  echo "  -d, --domain <domain>     Domain to use as SNI (default: ${defaults[domain]})"
  echo "      --fingerprint <fp>    TLS fingerprint: chrome|firefox|safari|ios|android|edge|360|qq|random (default: ${defaults[fingerprint]})"
  echo "      --xhttp-mode <mode>   XHTTP transport mode: stream-up|packet-up (default: ${defaults[xhttp_mode]})"
  echo "      --fragment <ON|OFF>   Enable TLS ClientHello fragmentation on outbound (default: ${defaults[fragment]})"
  echo "      --server <server>     IP address or domain name of server (Must be a valid domain if using letsencrypt security)"
  echo "      --regenerate          Regenerate public and private keys"
  echo "      --default             Restore default configuration"
  echo "  -r  --restart             Restart services"
  echo "  -u, --uninstall           Uninstall reality"
  echo "      --enable-safenet <true|false> Enable or disable safenet (blocking malware and adult content)"
  echo "      --port <port>         Server port (default: ${defaults[port]})"
  echo "      --enable-warp <true|false> Enable or disable Cloudflare warp"
  echo "      --warp-license <warp-license> Add Cloudflare warp+ license"
  echo "      --core <xray>         Xray-only mode (for backward compatibility)"
  echo "      --security <reality|letsencrypt|selfsigned> Select type of TLS encryption (reality, letsencrypt, selfsigned, default: ${defaults[security]})" 
  echo "  -m  --menu                Show menu"
  echo "      --enable-tgbot <true|false> Enable Telegram bot for user management"
  echo "      --tgbot-token <token> Token of Telegram bot"
  echo "      --tgbot-admin-ids <id[,id...]> Telegram user IDs allowed to manage the bot"
  echo "      --short-ids <id[,id...]> REALITY short IDs for rotation (hex, even length, max 16 chars each)"
  echo "      --xray-version-min <x.y.z> Set version.min in generated Xray config"
  echo "      --xray-experimental <true|false> Enable or disable experimental Xray features"
  echo "      --experimental-user <username> Username to receive experimental VLESS seed"
  echo "      --experimental-test-seed <seed> Experimental test seed for selected user"
  echo "      --reality-mldsa65-seed <seed> Enable REALITY ML-DSA-65 signature seed"
  echo "      --show-server-config  Print server configuration"
  echo "      --add-user <username> Add new user"
  echo "      --list-users          List all users"
  echo "      --show-user <username> Shows the config and QR code of the user"
  echo "      --delete-user <username> Delete the user"
  echo "      --enable-subscriptions <true|false> Enable subscription links (letsencrypt/selfsigned only)"
  echo "      --show-subscription <username> Print subscription URL for user"
  echo "      --rotate-subscription <username> Generate new subscription token for user"
  echo "      --backup              Create encrypted local backup (.tar.gpg)"
  echo "      --backup-upload-temp  Upload encrypted backup to temp.sh (explicit opt-in)"
  echo "      --restore <url|file>  Restore backup from URL or file"
  echo "      --backup-password <password> Password for backup encryption/decryption"
  echo "  -h, --help                Display this help message"
  return 1
}

function parse_args {
  local opts
  opts=$(getopt -o t:d:ruc:mh --long transport:,domain:,server:,regenerate,default,restart,uninstall,enable-safenet:,port:,warp-license:,enable-warp:,core:,security:,menu,show-server-config,add-user:,list-users,show-user:,delete-user:,backup,backup-upload-temp,restore:,backup-password:,enable-tgbot:,tgbot-token:,tgbot-admin-ids:,tgbot-admins:,short-ids:,xray-version-min:,xray-experimental:,experimental-user:,experimental-test-seed:,reality-mldsa65-seed:,fingerprint:,xhttp-mode:,fragment:,enable-subscriptions:,show-subscription:,rotate-subscription:,help -- "$@")
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  eval set -- "$opts"
  while true; do
    case $1 in
      -t|--transport)
        args[transport]="$2"
        case ${args[transport]} in
          tcp|http|grpc|ws|xhttp)
            shift 2
            ;;
          *)
            echo "Invalid transport protocol: ${args[transport]}"
            return 1
            ;;
        esac
        ;;
      --fingerprint)
        args[fingerprint]="$2"
        if ! [[ ${args[fingerprint]} =~ ${regex[fingerprint]} ]]; then
          echo "Invalid fingerprint: ${args[fingerprint]}. Valid values: chrome|firefox|safari|ios|android|edge|360|qq|random"
          return 1
        fi
        shift 2
        ;;
      --xhttp-mode)
        args[xhttp_mode]="$2"
        if ! [[ ${args[xhttp_mode]} =~ ${regex[xhttp_mode]} ]]; then
          echo "Invalid xhttp-mode: ${args[xhttp_mode]}. Valid values: stream-up|packet-up"
          return 1
        fi
        shift 2
        ;;
      --fragment)
        $2 && args[fragment]=ON || args[fragment]=OFF
        shift 2
        ;;
      -d|--domain)
        args[domain]="$2"
        if ! [[ ${args[domain]} =~ ${regex[domain_port]} ]]; then
          echo "Invalid domain: ${args[domain]}"
          return 1
        fi
        shift 2
        ;;
      --server)
        args[server]="$2"
        if ! [[ ${args[server]} =~ ${regex[domain]} || ${args[server]} =~ ${regex[ip]} ]]; then
          echo "Invalid server: ${args[server]}"
          return 1
        fi
        shift 2
        ;;
      --regenerate)
        args[regenerate]=true
        shift
        ;;
      --default)
        args[default]=true
        shift
        ;;
      -r|--restart)
        args[restart]=true
        shift
        ;;
      -u|--uninstall)
        args[uninstall]=true
        shift
        ;;
      --enable-safenet)
        case "$2" in
          true|false)
            $2 && args[safenet]=ON || args[safenet]=OFF
            shift 2
            ;;
          *)
            echo "Invalid safenet option: $2"
            return 1
            ;;
        esac
        ;;
      --enable-warp)
        case "$2" in
          true|false)
            $2 && args[warp]=ON || args[warp]=OFF
            shift 2
            ;;
          *)
            echo "Invalid warp option: $2"
            return 1
            ;;
        esac
        ;;
      --port)
        args[port]="$2"
        if ! [[ ${args[port]} =~ ${regex[port]} ]]; then
          echo "Invalid port number: ${args[port]}"
          return 1
        elif ((args[port] < 1 || args[port] > 65535)); then
          echo "Port number out of range: ${args[port]}"
          return 1
        fi
        shift 2
        ;;
      --warp-license)
        args[warp_license]="$2"
        if ! [[ ${args[warp_license]} =~ ${regex[warp_license]} ]]; then
          echo "Invalid warp license: ${args[warp_license]}"
          return 1
        fi
        shift 2
        ;;
      -c|--core)
        args[core]="$2"
        case ${args[core]} in
          xray)
            shift 2
            ;;
          *)
            echo "Invalid core: ${args[core]}. This script supports xray only."
            return 1
            ;;
        esac
        ;;
      --security)
        args[security]="$2"
        case ${args[security]} in
          reality|letsencrypt|selfsigned)
            shift 2
            ;;
          *)
            echo "Invalid TLS security option: ${args[security]}"
            return 1
            ;;
        esac
        ;;
      -m|--menu)
        args[menu]=true
        shift
        ;;
      --enable-tgbot)
        case "$2" in
          true|false)
            $2 && args[tgbot]=ON || args[tgbot]=OFF
            shift 2
            ;;
          *)
            echo "Invalid enable-tgbot option: $2"
            return 1
            ;;
        esac
        ;;
      --tgbot-token)
        args[tgbot_token]="$2"
        if [[ ! ${args[tgbot_token]} =~ ${regex[tgbot_token]} ]]; then
          echo "Invalid Telegram Bot Token: ${args[tgbot_token]}"
          return 1
        fi 
        if ! curl -sSfL -m 3 "https://api.telegram.org/bot${args[tgbot_token]}/getMe" >/dev/null 2>&1; then
          echo "Invalid Telegram Bot Token: Telegram Bot Token is incorrect. Check it again."
          return 1
        fi
        shift 2
        ;;
      --tgbot-admin-ids|--tgbot-admins)
        args[tgbot_admin_ids]="$2"
        if [[ ! ${args[tgbot_admin_ids]} =~ ${regex[tgbot_admin_ids]} ]]; then
          echo "Invalid Telegram Bot Admin IDs: ${args[tgbot_admin_ids]}"
          return 1
        fi
        shift 2
        ;;
      --short-ids)
        args[short_ids]="$2"
        if [[ ! ${args[short_ids]} =~ ${regex[short_ids]} ]]; then
          echo "Invalid short IDs list: ${args[short_ids]}"
          return 1
        fi
        shift 2
        ;;
      --xray-version-min)
        args[xray_version_min]="$2"
        if [[ ! ${args[xray_version_min]} =~ ${regex[xray_version]} ]]; then
          echo "Invalid xray version.min: ${args[xray_version_min]}"
          return 1
        fi
        shift 2
        ;;
      --xray-experimental)
        case "$2" in
          true|false)
            $2 && args[xray_experimental]=ON || args[xray_experimental]=OFF
            shift 2
            ;;
          *)
            echo "Invalid xray-experimental option: $2"
            return 1
            ;;
        esac
        ;;
      --experimental-user)
        args[experimental_user]="$2"
        if ! [[ ${args[experimental_user]} =~ ${regex[username]} ]]; then
          echo "Invalid experimental username: ${args[experimental_user]}"
          return 1
        fi
        shift 2
        ;;
      --experimental-test-seed)
        args[experimental_test_seed]="$2"
        if [[ ! ${args[experimental_test_seed]} =~ ${regex[test_seed]} ]]; then
          echo "Invalid experimental test seed: ${args[experimental_test_seed]}"
          return 1
        fi
        shift 2
        ;;
      --reality-mldsa65-seed)
        args[reality_mldsa65_seed]="$2"
        if [[ ! ${args[reality_mldsa65_seed]} =~ ${regex[mldsa65_seed]} ]]; then
          echo "Invalid mldsa65 seed"
          return 1
        fi
        shift 2
        ;;
      --show-server-config)
        args[server-config]=true
        shift
        ;;
      --add-user)
        args[add_user]="$2"
        if ! [[ ${args[add_user]} =~ ${regex[username]} ]]; then
          printf 'Invalid username: %s\nUsername can only contain A-Z, a-z and 0-9\n' "${args[add_user]}"
          return 1
        fi
        shift 2
        ;;
      --list-users)
        args[list_users]=true
        shift
        ;;
      --show-user)
        args[show_config]="$2"
        shift 2
        ;;
      --delete-user)
        args[delete_user]="$2"
        shift 2
        ;;
      --enable-subscriptions)
        case "$2" in
          true|false)
            $2 && args[subscriptions]=ON || args[subscriptions]=OFF
            shift 2
            ;;
          *)
            echo "Invalid enable-subscriptions option: $2"
            return 1
            ;;
        esac
        ;;
      --show-subscription)
        args[show_subscription]="$2"
        if ! [[ ${args[show_subscription]} =~ ${regex[username]} ]]; then
          printf 'Invalid username: %s\n' "${args[show_subscription]}"
          return 1
        fi
        shift 2
        ;;
      --rotate-subscription)
        args[rotate_subscription]="$2"
        if ! [[ ${args[rotate_subscription]} =~ ${regex[username]} ]]; then
          printf 'Invalid username: %s\n' "${args[rotate_subscription]}"
          return 1
        fi
        shift 2
        ;;
      --backup)
        args[backup]=true
        shift
        ;;
      --backup-upload-temp)
        args[backup_upload_temp]=true
        shift
        ;;
      --restore)
        args[restore]="$2"
        if [[ ! ${args[restore]} =~ ${regex[file_path]} ]] && [[ ! ${args[restore]} =~ ${regex[url]} ]]; then
          echo "Invalid: Backup file path or URL is not valid."
          return 1
        fi
        shift 2
        ;;
      --backup-password)
        args[backup_password]="$2"
        shift 2
        ;;
      -h|--help)
        return 1
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [[ ${args[uninstall]} == true ]]; then
    uninstall
  fi

  if [[ -n ${args[warp_license]} ]]; then
    args[warp]=ON
  fi
}

function backup {
  local backup_name
  local backup_file
  local backup_password="$1"
  local upload_temp="${2:-false}"
  local backup_file_url
  if [[ -z "${backup_password}" ]]; then
    echo "Backup password is required." >&2
    return 1
  fi

  backup_name="reality-ezpz-backup-$(date +%Y-%m-%d_%H-%M-%S).tar.gpg"
  backup_file="/tmp/${backup_name}"
  if ! tar -C "${config_path}" -cpf - . | \
    gpg --batch --yes --pinentry-mode loopback \
      --passphrase "${backup_password}" \
      --symmetric --cipher-algo AES256 \
      --output "${backup_file}"; then
    rm -f "${backup_file}"
    echo "Error in creating encrypted backup file" >&2
    return 1
  fi
  chmod 600 "${backup_file}" 2>/dev/null || true

  if [[ "${upload_temp}" == true ]]; then
    if ! backup_file_url=$(curl -fsS -m 30 -F "file=@${backup_file}" "https://temp.sh/upload"); then
      rm -f "${backup_file}"
      echo "Error in uploading backup file" >&2
      return 1
    fi
    rm -f "${backup_file}"
    echo "${backup_file_url}"
    return 0
  fi

  echo "${backup_file}"
  return 0
}

function restore {
  local backup_file="$1"
  local backup_password="$2"
  local encrypted_file
  local temp_file
  local temp_tar
  local temp_extract
  local tar_output
  local backup_existing=""
  local backup_dir=""
  local restore_target
  local tar_entries
  if [[ -z "${backup_password}" ]]; then
    echo "Backup password is required." >&2
    return 1
  fi

  if [[ ! -r ${backup_file} ]]; then
    temp_file=$(mktemp)
    if ! curl -fSsL -m 30 "${backup_file}" -o "${temp_file}"; then
      rm -f "${temp_file}"
      echo "Cannot download or find backup file" >&2
      return 1
    fi
    encrypted_file="${temp_file}"
  else
    encrypted_file="${backup_file}"
  fi

  temp_tar=$(mktemp)
  temp_extract=$(mktemp -d)
  if ! gpg --batch --yes --pinentry-mode loopback \
    --passphrase "${backup_password}" \
    --decrypt --output "${temp_tar}" "${encrypted_file}" >/dev/null 2>&1; then
    if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
    rm -f "${temp_tar}"
    rm -rf "${temp_extract}"
    echo "Cannot decrypt backup file. Check password and file integrity." >&2
    return 1
  fi

  if ! tar_entries=$(tar -tf "${temp_tar}" 2>/dev/null); then
    if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
    rm -f "${temp_tar}"
    rm -rf "${temp_extract}"
    echo "Backup archive is corrupted." >&2
    return 1
  fi
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    if [[ "${entry}" == /* || "${entry}" == *"../"* || "${entry}" == ".."* ]]; then
      if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
      rm -f "${temp_tar}"
      rm -rf "${temp_extract}"
      echo "Backup archive contains unsafe paths." >&2
      return 1
    fi
  done <<< "${tar_entries}"

  if ! tar_output=$(tar -xf "${temp_tar}" -C "${temp_extract}" 2>&1); then
    if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
    rm -f "${temp_tar}"
    rm -rf "${temp_extract}"
    echo "Error in backup restore: ${tar_output}" >&2
    return 1
  fi
  if [[ ! -r "${temp_extract}/config" || ! -r "${temp_extract}/users" || ! -r "${temp_extract}/engine.conf" ]]; then
    if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
    rm -f "${temp_tar}"
    rm -rf "${temp_extract}"
    echo "The provided file is not a reality-ezpz backup file." >&2
    return 1
  fi

  restore_target="${config_path}.restore.$$.$(date +%s)"
  if ! mv "${temp_extract}" "${restore_target}"; then
    if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
    rm -f "${temp_tar}"
    rm -rf "${temp_extract}"
    echo "Error in backup restore: cannot stage restored files." >&2
    return 1
  fi
  if [[ -d "${config_path}" ]]; then
    backup_dir=$(mktemp -d)
    backup_existing="${backup_dir}/config"
    if ! mv "${config_path}" "${backup_existing}"; then
      rm -rf "${restore_target}" "${backup_dir}"
      if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
      rm -f "${temp_tar}"
      echo "Error in backup restore: cannot move existing config out of the way." >&2
      return 1
    fi
  fi
  if ! mv "${restore_target}" "${config_path}"; then
    rm -rf "${restore_target}"
    if [[ -n "${backup_existing}" && -d "${backup_existing}" ]]; then
      mv "${backup_existing}" "${config_path}"
    fi
    rm -rf "${backup_dir}"
    if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
    rm -f "${temp_tar}"
    echo "Error in backup restore: failed to move restored config into place." >&2
    return 1
  fi
  rm -rf "${backup_existing}" "${backup_dir}"
  if [[ -n "${temp_file}" ]]; then rm -f "${temp_file}"; fi
  rm -f "${temp_tar}"
  secure_file_permissions
  return 0
}

function dict_expander {
  local -n dict=$1
  for key in "${!dict[@]}"; do
    echo "${key} ${dict[$key]}"
  done
}

function normalize_short_ids_csv {
  local raw="$1"
  local sid
  local clean
  local -a normalized=()
  local i
  IFS=',' read -r -a short_ids_array <<< "${raw}"
  for sid in "${short_ids_array[@]}"; do
    clean=$(echo "${sid}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [[ -z "${clean}" ]]; then
      continue
    fi
    if [[ ! "${clean}" =~ ^[0-9a-f]{2,16}$ ]]; then
      return 1
    fi
    if (( ${#clean} % 2 != 0 )); then
      return 1
    fi
    normalized+=("${clean}")
  done
  if [[ ${#normalized[@]} -eq 0 ]]; then
    return 1
  fi
  printf '%s' "${normalized[0]}"
  for ((i=1; i<${#normalized[@]}; i++)); do
    printf ',%s' "${normalized[$i]}"
  done
}

function parse_config_file {
  if [[ ! -r "${path[config]}" ]]; then
    generate_keys
    return 0
  fi
  while IFS= read -r line; do
    if [[ "${line}" =~ ^\s*# ]] || [[ "${line}" =~ ^\s*$ ]]; then
      continue
    fi
    key=$(echo "$line" | cut -d "=" -f 1)
    value=$(echo "$line" | cut -d "=" -f 2-)
    if [[ "${key}" == "tgbot_admins" ]]; then
      key="tgbot_admin_ids"
    fi
    config_file["${key}"]="${value}"
  done < "${path[config]}"
  if [[ -z "${config_file[public_key]}" || \
        -z "${config_file[private_key]}" || \
        -z "${config_file[short_id]}" || \
        -z "${config_file[service_path]}" ]]; then
    generate_keys
  fi
  if [[ -z "${config_file[short_ids]}" ]]; then
    config_file[short_ids]="${config_file[short_id]}"
  fi
  return 0
}

function parse_users_file {
  mkdir -p "$config_path"
  touch "${path[users]}"
  while IFS= read -r line; do
    if [[ "${line}" =~ ^\s*# ]] || [[ "${line}" =~ ^\s*$ ]]; then
      continue
    fi
    IFS="=" read -r key value <<< "${line}"
    users["${key}"]="${value}"
  done < "${path[users]}"
  if [[ -n ${args[add_user]} ]]; then
    if [[ -z "${users["${args[add_user]}"]}" ]]; then
      users["${args[add_user]}"]=$(cat /proc/sys/kernel/random/uuid)
    else
      echo 'User "'"${args[add_user]}"'" already exists.'
    fi
  fi
  if [[ -n ${args[delete_user]} ]]; then
    if [[ -n "${users["${args[delete_user]}"]}" ]]; then
      if [[ ${#users[@]} -eq 1 ]]; then
        echo -e "You cannot delete the only user.\nAt least one user is needed.\nCreate a new user, then delete this one."
        exit 1
      fi
      unset "users[${args[delete_user]}]"
    else
      echo "User \"${args[delete_user]}\" does not exist."
      exit 1
    fi
  fi
  if [[ ${#users[@]} -eq 0 ]]; then
    users[RealityEZPZ]=$(cat /proc/sys/kernel/random/uuid)
    echo "RealityEZPZ=${users[RealityEZPZ]}" >> "${path[users]}"
    return 0
  fi
  return 0
}

function restore_defaults {
  local defaults_items=("${!defaults[@]}")
  local keep=false
  local exclude_list=(
    "warp_license"
    "tgbot_token"
    "tgbot_admin_ids"
  )
  if [[ -n ${config[warp_id]} && -n ${config[warp_token]} ]]; then
    warp_delete_account "${config[warp_id]}" "${config[warp_token]}"
  fi
  for item in "${defaults_items[@]}"; do
    keep=false
    for i in "${exclude_list[@]}"; do
      if [[ "${i}" == "${item}" ]]; then
        keep=true
        break
      fi
    done
    if [[ ${keep} == true ]]; then
      continue
    fi
    config["${item}"]="${defaults[${item}]}"
  done
}

function build_config {
  local free_80=true
  local normalized_short_ids
  local limit_key
  if [[ ${args[regenerate]} == true ]]; then
    generate_keys
  fi
  for item in "${config_items[@]}"; do
    if [[ -n ${args["${item}"]} ]]; then
      config["${item}"]="${args[${item}]}"
    elif [[ -n ${config_file["${item}"]} ]]; then
      config["${item}"]="${config_file[${item}]}"
    else
      config["${item}"]="${defaults[${item}]}"
    fi
  done
  if [[ -z "${config[short_ids]}" ]]; then
    config[short_ids]="${config[short_id]}"
  fi
  if ! normalized_short_ids=$(normalize_short_ids_csv "${config[short_ids]}"); then
    echo "Invalid short_ids list. Expected comma separated even-length hex IDs (2..16 chars each)."
    exit 1
  fi
  config[short_ids]="${normalized_short_ids}"
  if [[ ",${config[short_ids]}," != *",$(echo "${config[short_id]}" | tr '[:upper:]' '[:lower:]'),"* ]]; then
    config[short_ids]="${config[short_id]},${config[short_ids]}"
  fi
  config[short_ids]=$(normalize_short_ids_csv "${config[short_ids]}") || {
    echo "Invalid merged short_ids list"
    exit 1
  }
  IFS=',' read -r config[short_id] _ <<< "${config[short_ids]}"
  if [[ ! ${config[xray_version_min]} =~ ${regex[xray_version]} ]]; then
    echo "Invalid xray_version_min: ${config[xray_version_min]}"
    exit 1
  fi
  for limit_key in \
    reality_limit_fallback_upload_after_bytes \
    reality_limit_fallback_upload_bytes_per_sec \
    reality_limit_fallback_upload_burst_bytes_per_sec \
    reality_limit_fallback_download_after_bytes \
    reality_limit_fallback_download_bytes_per_sec \
    reality_limit_fallback_download_burst_bytes_per_sec; do
    if [[ ! ${config[${limit_key}]} =~ ${regex[number]} ]]; then
      echo "Invalid numeric value for ${limit_key}: ${config[${limit_key}]}"
      exit 1
    fi
  done
  if [[ ${config[xray_experimental]} != 'ON' && ${config[xray_experimental]} != 'OFF' ]]; then
    echo "Invalid xray_experimental value: ${config[xray_experimental]}"
    exit 1
  fi
  if [[ -n ${config[experimental_user]} && ! ${config[experimental_user]} =~ ${regex[username]} ]]; then
    echo "Invalid experimental_user: ${config[experimental_user]}"
    exit 1
  fi
  if [[ -n ${config[experimental_test_seed]} && ! ${config[experimental_test_seed]} =~ ${regex[test_seed]} ]]; then
    echo "Invalid experimental_test_seed"
    exit 1
  fi
  if [[ -n ${config[reality_mldsa65_seed]} && ! ${config[reality_mldsa65_seed]} =~ ${regex[mldsa65_seed]} ]]; then
    echo "Invalid reality_mldsa65_seed"
    exit 1
  fi
  config[core]='xray'
  if [[ ${args[default]} == true ]]; then
    restore_defaults
    return 0
  fi
  if [[ ${config[tgbot]} == 'ON' && -z ${config[tgbot_token]} ]]; then
    echo 'To enable Telegram bot, you have to give the token of bot with --tgbot-token option.'
    exit 1
  fi
  if [[ ${config[tgbot]} == 'ON' && -z ${config[tgbot_admin_ids]} ]]; then
    echo 'To enable Telegram bot, you have to give Telegram admin IDs with --tgbot-admin-ids option.'
    exit 1
  fi
  if [[ ! ${config[server]} =~ ${regex[domain]} && ${config[security]} == 'letsencrypt' ]]; then
    echo 'You have to assign a domain to server with "--server <domain>" option if you want to use "letsencrypt" as TLS certifcate.'
    exit 1
  fi
  if [[ ${config[transport]} == 'ws' && ${config[security]} == 'reality' ]]; then
    echo 'You cannot use "ws" transport with "reality" TLS certificate. Use other transports or change TLS certifcate to letsencrypt or selfsigned'
    exit 1
  fi
  if [[ ${config[subscriptions]} == 'ON' && ${config[security]} == 'reality' ]]; then
    echo 'Subscription links are not available with "reality" security. Use letsencrypt or selfsigned security, or disable subscriptions with --enable-subscriptions false'
    exit 1
  fi
  if [[ ${config[security]} == 'letsencrypt' && ${config[port]} -ne 443 ]]; then
    if lsof -i :80 >/dev/null 2>&1; then
      free_80=false
      for container in $(${docker_cmd} -p ${compose_project} ps -q); do
        if docker port "${container}"| grep '0.0.0.0:80' >/dev/null 2>&1; then
          free_80=true
          break
        fi
      done
    fi
    if [[ ${free_80} != 'true' ]]; then
      echo 'Port 80 must be free if you want to use "letsencrypt" as the security option.'
      exit 1
    fi
  fi
  if [[ -n "${args[security]}" ]]; then
    if [[ "${config[security]}" == 'reality' && "${config_file[security]}" != 'reality' ]]; then
      config[domain]="${defaults[domain]}"
    fi
    if [[ "${config[security]}" != 'reality' && "${config_file[security]}" == 'reality' ]]; then
      config[domain]="${config[server]}"
    fi
  fi
  if [[ -n "${args[server]}" && "${config[security]}" != 'reality' ]]; then
    config[domain]="${config[server]}"
  fi
  if [[ -z ${config[api_token]} ]]; then
    config[api_token]=$(openssl rand -hex 24)
  fi
  if [[ ${config[tgbot]} == 'ON' && -z ${config[helper_token]} ]]; then
    config[helper_token]=$(openssl rand -hex 24)
  fi
  if [[ -n "${args[warp]}" && "${args[warp]}" == 'OFF' && "${config_file[warp]}" == 'ON' ]]; then
    if [[ -n ${config[warp_id]} && -n ${config[warp_token]} ]]; then
      warp_delete_account "${config[warp_id]}" "${config[warp_token]}"
    fi
  fi
  if { [[ -n "${args[warp]}" && "${args[warp]}" == 'ON' && "${config_file[warp]}" == 'OFF' ]] || \
       [[ "${config[warp]}" == 'ON' && ( -z ${config[warp_private_key]} || \
                                         -z ${config[warp_token]} || \
                                         -z ${config[warp_id]} || \
                                         -z ${config[warp_client_id]} || \
                                         -z ${config[warp_interface_ipv4]} || \
                                         -z ${config[warp_interface_ipv6]} ) ]]; }; then
    config[warp]='OFF'
    warp_create_account || exit 1
    if [[ -n ${config[warp_license]} ]]; then
      warp_add_license "${config[warp_id]}" "${config[warp_token]}" "${config[warp_license]}" || exit 1
    fi
    config[warp]='ON'
  fi
  if [[ -n ${args[warp_license]} && "${args[warp_license]}" != "${config_file[warp_license]}" ]]; then
    if ! warp_add_license "${config[warp_id]}" "${config[warp_token]}" "${args[warp_license]}"; then
      config[warp]='OFF'
      config[warp_license]=""
      warp_delete_account "${config[warp_id]}" "${config[warp_token]}"
      echo "WARP has been disabled due to the license error."
    fi 
  fi
}

function update_config_file {
  mkdir -p "${config_path}"
  touch "${path[config]}"
  for item in "${config_items[@]}"; do
    if grep -q "^${item}=" "${path[config]}"; then
      sed -i "s|^${item}=.*|${item}=${config[${item}]}|" "${path[config]}"
    else
      echo "${item}=${config[${item}]}" >> "${path[config]}"
    fi
  done
  secure_file_permissions
  check_reload
}

function update_users_file {
  rm -f "${path[users]}"
  for user in "${!users[@]}"; do
    echo "${user}=${users[${user}]}" >> "${path[users]}"
  done
  if [[ ${config[subscriptions]} == 'ON' ]]; then
    sync_subscriptions_file || true
  fi
  secure_file_permissions
  check_reload
}

function generate_keys {
  local key_pair
  key_pair=$(docker run --rm "${image[xray]}" xray x25519)
  config_file[public_key]=$(echo "${key_pair}" | grep 'Public key:' | awk '{print $3}')
  config_file[private_key]=$(echo "${key_pair}" | grep 'Private key:' | awk '{print $3}')
  config_file[short_id]=$(openssl rand -hex 8)
  config_file[short_ids]="${config_file[short_id]},$(openssl rand -hex 8),$(openssl rand -hex 8)"
  config_file[service_path]=$(openssl rand -hex 4)
}

function uninstall {
  if docker compose >/dev/null 2>&1; then
    docker compose --project-directory "${config_path}" down --timeout 2 || true
    docker compose --project-directory "${config_path}" -p ${compose_project} down --timeout 2 || true
    docker compose --project-directory "${config_path}/tgbot" -p ${tgbot_project} down --timeout 2 || true
  elif which docker-compose >/dev/null 2>&1; then
    docker-compose --project-directory "${config_path}" down --timeout 2 || true
    docker-compose --project-directory "${config_path}" -p ${compose_project} down --timeout 2 || true
    docker-compose --project-directory "${config_path}/tgbot" -p ${tgbot_project} down --timeout 2 || true
  fi
  rm -rf "${config_path}"
  echo "Reality-EZPZ uninstalled successfully."
  exit 0
}

function install_packages {
  if [[ -n $BOT_TOKEN ]]; then 
    return 0
  fi
  if ! which qrencode whiptail jq xxd gpg >/dev/null 2>&1; then
    if which apt >/dev/null 2>&1; then
      apt update
      DEBIAN_FRONTEND=noninteractive apt install qrencode whiptail jq xxd gnupg tar -y
      return 0
    fi
    if which yum >/dev/null 2>&1; then
      yum makecache
      yum install epel-release -y || true
      yum install qrencode newt jq vim-common gnupg2 tar -y
      return 0
    fi
    echo "OS is not supported!"
    return 1
  fi
}

function install_docker {
  if ! which docker >/dev/null 2>&1; then
    curl -fsSL -m 5 https://get.docker.com | bash
    systemctl enable --now docker
    docker_cmd="docker compose"
    return 0
  fi
  if docker compose >/dev/null 2>&1; then
    docker_cmd="docker compose"
    return 0
  fi
  if which docker-compose >/dev/null 2>&1; then
    docker_cmd="docker-compose"
    return 0
  fi
  curl -fsSL -m 30 "https://github.com/docker/compose/releases/download/v2.28.0/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  docker_cmd="docker-compose"
  return 0
}

function generate_docker_compose {
  cat >"${path[compose]}" <<EOF
version: "3"
networks:
  reality:
    driver: bridge
    enable_ipv6: true
    ipam:
      config:
      - subnet: fc11::1:0/112
services:
  engine:
    image: ${image[xray]}
    $([[ ${config[security]} == 'reality' ]] && echo "ports:" || echo "expose:")
    $([[ ${config[security]} == 'reality' && ${config[port]} -eq 443 ]] && echo '- 80:8080' || true)
    $([[ ${config[security]} == 'reality' ]] && echo "- ${config[port]}:8443" || true)
    $([[ ${config[security]} != 'reality' ]] && echo "- 8443" || true)
    restart: always
    environment:
      TZ: Etc/UTC
    volumes:
    - ./${path[engine]#${config_path}/}:/etc/xray/config.json
    $([[ ${config[security]} != 'reality' ]] && { [[ ${config[transport]} == 'http' ]] || [[ ${config[transport]} == 'tcp' ]] || [[ ${config[transport]} == 'xhttp' ]]; } && echo "- ./${path[server_crt]#${config_path}/}:/etc/xray/server.crt" || true)
    $([[ ${config[security]} != 'reality' ]] && { [[ ${config[transport]} == 'http' ]] || [[ ${config[transport]} == 'tcp' ]] || [[ ${config[transport]} == 'xhttp' ]]; } && echo "- ./${path[server_key]#${config_path}/}:/etc/xray/server.key" || true)
    networks:
    - reality
$(if [[ ${config[security]} != 'reality' ]]; then
echo "
  nginx:
    image: ${image[nginx]}
    expose:
    - 80
    restart: always
    volumes:
    - ./website:/usr/share/nginx/html
    networks:
    - reality
  haproxy:
    image: ${image[haproxy]}
    ports:
    $([[ ${config[security]} == 'letsencrypt' || ${config[port]} -eq 443 ]] && echo '- 80:8080' || true)
    - ${config[port]}:8443
    restart: always
    volumes:
    - ./${path[haproxy]#${config_path}/}:/usr/local/etc/haproxy/haproxy.cfg
    - ./${path[server_pem]#${config_path}/}:/usr/local/etc/haproxy/server.pem
    networks:
    - reality"
fi)
$(if [[ ${config[security]} == 'letsencrypt' ]]; then
echo "
  certbot:
    build:
      context: ./certbot
    expose:
    - 80
    restart: always
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./certbot/data:/etc/letsencrypt
    - ./$(dirname "${path[server_pem]#${config_path}/}"):/certificate
    - ./${path[certbot_deployhook]#${config_path}/}:/deployhook.sh
    - ./${path[certbot_startup]#${config_path}/}:/startup.sh
    - ./website:/website
    networks:
    - reality
    entrypoint: /bin/sh
    command: /startup.sh"
fi)
$(if [[ ${config[subscriptions]} == 'ON' && ${config[security]} != 'reality' ]]; then
echo "
  subscription-api:
    build:
      context: ./subscription-api
    expose:
    - 8081
    restart: always
    environment:
      CONFIG_PATH: /opt/reality-ezpz
    volumes:
    - ../:/opt/reality-ezpz:ro
    networks:
    - reality"
fi)
EOF
}

function generate_tgbot_compose {
  cat >"${path[tgbot_compose]}" <<EOF
version: "3"
networks:
  tgbot_internal:
    driver: bridge
    internal: true
  tgbot_egress:
    driver: bridge
services:
  vpn-helper:
    build:
      context: ./helper
    restart: always
    environment:
      HELPER_LISTEN: ":8090"
      HELPER_TOKEN: ${config[helper_token]}
      COMPOSE_PROJECT: ${compose_project}
      COMPOSE_DIR: ${config_path}
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ../:${config_path}:ro
    networks:
    - tgbot_internal
  vpn-api:
    build:
      context: ./api
    restart: always
    environment:
      API_LISTEN: ":8080"
      API_TOKEN: ${config[api_token]}
      HELPER_URL: http://vpn-helper:8090
      HELPER_TOKEN: ${config[helper_token]}
      CONFIG_PATH: ${config_path}
      COMPOSE_PROJECT: ${compose_project}
      COMPOSE_DIR: ${config_path}
    volumes:
    - ../:${config_path}
    depends_on:
    - vpn-helper
    networks:
    - tgbot_internal
  tgbot:
    build:
      context: ./bot
    restart: always
    environment:
      BOT_TOKEN: ${config[tgbot_token]}
      BOT_ADMIN_IDS: ${config[tgbot_admin_ids]}
      VPN_API_URL: http://vpn-api:8080
      VPN_API_TOKEN: ${config[api_token]}
    depends_on:
    - vpn-api
    networks:
    - tgbot_internal
    - tgbot_egress
EOF
}

function generate_haproxy_config {
echo "
global
  ssl-default-bind-options ssl-min-ver TLSv1.2
defaults
  option http-server-close
  timeout connect 5s
  timeout client 50s
  timeout client-fin 1s
  timeout server-fin 1s
  timeout server 50s
  timeout tunnel 50s
  timeout http-keep-alive 1s
  timeout queue 15s
frontend http
  mode http
  bind :::8080 v4v6
$(if [[ ${config[security]} == 'letsencrypt' ]]; then echo "
  use_backend certbot if { path_beg /.well-known/acme-challenge }
  acl letsencrypt-acl path_beg /.well-known/acme-challenge
  redirect scheme https if !letsencrypt-acl
"; fi)
  use_backend default
frontend tls
$(if [[ ${config[transport]} != 'tcp' ]]; then echo "
  bind :::8443 v4v6 ssl crt /usr/local/etc/haproxy/server.pem alpn h2,http/1.1
  mode http
  http-request set-header Host ${config[server]}
$(if [[ ${config[subscriptions]} == 'ON' ]]; then echo "
  stick-table type ip size 100k expire 1m store http_req_rate(60s)
  http-request track-sc0 src if { path_beg /${config[subscription_path]}/ }
  http-request deny status 429 if { path_beg /${config[subscription_path]}/ } { sc_http_req_rate(0) gt 30 }
  use_backend subscription_api if { path_beg /${config[subscription_path]}/ }
"; fi)
$(if [[ ${config[security]} == 'letsencrypt' ]]; then echo "
  use_backend certbot if { path_beg /.well-known/acme-challenge }
"; fi)
  use_backend engine if { path_beg /${config[service_path]} }
  use_backend default
"; else echo "
  bind :::8443 v4v6
  mode tcp
  use_backend engine
"; fi)
backend engine
  retry-on conn-failure empty-response response-timeout
$(if [[ ${config[transport]} != 'tcp' ]]; then echo "
  mode http
"; else echo "
  mode tcp
"; fi)
$(if [[ ${config[transport]} == 'grpc' ]]; then echo "
  server engine engine:8443 check tfo proto h2
"; elif [[ ${config[transport]} == 'http' || ${config[transport]} == 'xhttp' ]]; then echo "
  server engine engine:8443 check tfo ssl verify none
"; else echo "
  server engine engine:8443 check tfo
"; fi)
$(if [[ ${config[security]} == 'letsencrypt' ]]; then echo "
backend certbot
  mode http
  server certbot certbot:80
"; fi)
$(if [[ ${config[subscriptions]} == 'ON' && ${config[transport]} != 'tcp' ]]; then echo "
backend subscription_api
  mode http
  server subscription-api subscription-api:8081 check
"; fi)
backend default
  mode http
  server nginx nginx:80
" | grep -vE '^\s*$' > "${path[haproxy]}"
}

function generate_certbot_script {
  cat >"${path[certbot_startup]}" << EOF
#!/bin/sh
trap exit TERM
fullchain_path=/etc/letsencrypt/live/${config[server]}/fullchain.pem
if [[ -r "\${fullchain_path}" ]]; then
  fullchain_fingerprint=\$(openssl x509 -noout -fingerprint -sha256 -in "\${fullchain_path}" 2>/dev/null |\
awk -F= '{print \$2}' | tr -d : | tr '[:upper:]' '[:lower:]')
  installed_fingerprint=\$(openssl x509 -noout -fingerprint -sha256 -in /certificate/server.pem 2>/dev/null |\
awk -F= '{print \$2}' | tr -d : | tr '[:upper:]' '[:lower:]')
  if [[ \$fullchain_fingerprint != \$installed_fingerprint ]]; then
    /deployhook.sh /certificate ${compose_project} ${config[server]} ${service[server_crt]} $([[ ${config[transport]} != 'tcp' ]] && echo "${service[server_pem]}" || true)
  fi
fi
while true; do
  ls -d /website/* | grep -E '^/website/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\$'|xargs rm -f
  uuid=\$(uuidgen)
  echo "\$uuid" > "/website/\$uuid"
  response=\$(curl -skL --max-time 3 http://${config[server]}/\$uuid)
  if echo "\$response" | grep \$uuid >/dev/null; then
    break
  fi
  echo "Domain ${config[server]} is not pointing to the server"
  sleep 5
done
ls -d /website/* | grep -E '^/website/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\$'|xargs rm -f
while true; do
  certbot certonly -n \\
    --standalone \\
    --key-type ecdsa \\
    --elliptic-curve secp256r1 \\
    --agree-tos \\
    --register-unsafely-without-email \\
    -d ${config[server]} \\
    --deploy-hook "/deployhook.sh /certificate ${compose_project} ${config[server]} ${service[server_crt]} $([[ ${config[transport]} != 'tcp' ]] && echo "${service[server_pem]}" || true)"
  sleep 1h &
  wait \${!}
done
EOF
}

function generate_certbot_deployhook {
  cat >"${path[certbot_deployhook]}" << EOF
#!/bin/sh
cert_path=\$1
compose_project=\$2
domain=\$3
renewed_path=/etc/letsencrypt/live/\$domain
cat "\$renewed_path/fullchain.pem" > "\$cert_path/server.crt"
cat "\$renewed_path/privkey.pem" > "\$cert_path/server.key"
cat "\$renewed_path/fullchain.pem" "\$renewed_path/privkey.pem" > "\$cert_path/server.pem"
i=4
while [ \$i -le \$# ]; do
  eval service=\\\${\$i}
  docker compose -p "${compose_project}" restart --timeout 2 "\$service"
  i=\$((i+1))
done
EOF
  chmod +x "${path[certbot_deployhook]}"
}

function generate_certbot_dockerfile {
  cat >"${path[certbot_dockerfile]}" << EOF
FROM ${image[certbot]}
RUN apk add --no-cache docker-cli-compose curl uuidgen
EOF
}

function generate_tgbot_api_dockerfile {
  cat >"${path[tgbot_api_dockerfile]}" << EOF
FROM ${image[golang]} AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=\$(go env GOARCH) go build -trimpath -ldflags="-s -w" -o /out/vpn-api .

FROM ${image[alpine]}
RUN apk add --no-cache ca-certificates
COPY --from=build /out/vpn-api /usr/local/bin/vpn-api
ENTRYPOINT ["/usr/local/bin/vpn-api"]
EOF
}

function generate_tgbot_bot_dockerfile {
  cat >"${path[tgbot_bot_dockerfile]}" << EOF
FROM ${image[golang]} AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=\$(go env GOARCH) go build -trimpath -ldflags="-s -w" -o /out/tgbot .

FROM ${image[alpine]}
RUN apk add --no-cache ca-certificates
COPY --from=build /out/tgbot /usr/local/bin/tgbot
ENTRYPOINT ["/usr/local/bin/tgbot"]
EOF
}

function generate_tgbot_helper_dockerfile {
  cat >"${path[tgbot_helper_dockerfile]}" << EOF
FROM ${image[golang]} AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=\$(go env GOARCH) go build -trimpath -ldflags="-s -w" -o /out/vpn-helper .

FROM ${image[alpine]}
RUN apk add --no-cache ca-certificates docker-cli-compose
COPY --from=build /out/vpn-helper /usr/local/bin/vpn-helper
ENTRYPOINT ["/usr/local/bin/vpn-helper"]
EOF
}

function sync_tgbot_sources {
  local source_root
  source_root="${script_dir}/tgbot"
  if [[ ! -r "${source_root}/api/main.go"    || \
        ! -r "${source_root}/api/go.mod"      || \
        ! -r "${source_root}/bot/main.go"     || \
        ! -r "${source_root}/bot/go.mod"      || \
        ! -r "${source_root}/bot/go.sum"      || \
        ! -r "${source_root}/helper/main.go"  || \
        ! -r "${source_root}/helper/go.mod"   ]]; then
    if [[ -r "${path[tgbot_api_main]}"    && -r "${path[tgbot_api_gomod]}"  && \
          -r "${path[tgbot_bot_main]}"    && -r "${path[tgbot_bot_gomod]}"  && \
          -r "${path[tgbot_bot_gosum]}"   && -r "${path[tgbot_helper_main]}" && \
          -r "${path[tgbot_helper_gomod]}" ]]; then
      return 0
    fi
    echo "Cannot find local tgbot sources in ${source_root}. Run this script from a checked-out repository." >&2
    return 1
  fi
  cp "${source_root}/api/main.go"    "${path[tgbot_api_main]}"
  cp "${source_root}/api/go.mod"     "${path[tgbot_api_gomod]}"
  cp "${source_root}/bot/main.go"    "${path[tgbot_bot_main]}"
  cp "${source_root}/bot/go.mod"     "${path[tgbot_bot_gomod]}"
  cp "${source_root}/bot/go.sum"     "${path[tgbot_bot_gosum]}"
  cp "${source_root}/helper/main.go" "${path[tgbot_helper_main]}"
  cp "${source_root}/helper/go.mod"  "${path[tgbot_helper_gomod]}"
}

function sync_subscription_api_sources {
  local source_root
  source_root="${script_dir}/tgbot/subscription"
  if [[ ! -r "${source_root}/main.go" || ! -r "${source_root}/go.mod" ]]; then
    if [[ -r "${path[subscription_api_main]}" && -r "${path[subscription_api_gomod]}" ]]; then
      return 0
    fi
    echo "Cannot find subscription-api sources in ${source_root}. Run this script from a checked-out repository." >&2
    return 1
  fi
  mkdir -p "$(dirname "${path[subscription_api_main]}")"
  cp "${source_root}/main.go" "${path[subscription_api_main]}"
  cp "${source_root}/go.mod"  "${path[subscription_api_gomod]}"
}

function generate_subscription_api_dockerfile {
  mkdir -p "$(dirname "${path[subscription_api_dockerfile]}")"
  cat >"${path[subscription_api_dockerfile]}" <<EOF
FROM ${image[golang]} AS build
WORKDIR /src
COPY go.mod .
RUN go mod download
COPY main.go .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/subscription-api .

FROM ${image[alpine]}
RUN apk add --no-cache ca-certificates
COPY --from=build /out/subscription-api /usr/local/bin/subscription-api
ENTRYPOINT ["/usr/local/bin/subscription-api"]
EOF
}

# ── Subscription token management ────────────────────────────────────────────

function generate_subscription_token {
  openssl rand -base64 32 | tr -d '/+=\n' | head -c 43
}

function ensure_subscriptions_file {
  if [[ ! -f "${path[subscriptions]}" ]]; then
    printf '{"version":1,"users":{}}\n' > "${path[subscriptions]}"
    chmod 600 "${path[subscriptions]}"
  fi
}

function sync_subscriptions_file {
  ensure_subscriptions_file
  local tmp_file
  tmp_file=$(mktemp "${config_path}/.subscriptions-XXXXXX.tmp")
  trap 'rm -f "${tmp_file}"' RETURN

  # Build updated JSON using python3 (available in modern Alpine/Ubuntu)
  python3 - "${path[subscriptions]}" "${path[users]}" "${tmp_file}" <<'PYEOF'
import json, sys, os, time

subs_path, users_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

# Load subscriptions
try:
    with open(subs_path) as f:
        subs = json.load(f)
except Exception:
    subs = {"version": 1, "users": {}}
if not isinstance(subs.get("users"), dict):
    subs["users"] = {}

# Load users
current_users = {}
with open(users_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' in line:
            k, _, v = line.partition('=')
            current_users[k] = v

now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

# Remove deleted users
subs["users"] = {u: e for u, e in subs["users"].items() if u in current_users}

# Add new users without tokens
import base64, secrets
for u in current_users:
    if u not in subs["users"]:
        token = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b'=').decode()
        subs["users"][u] = {"token": token, "created_at": now, "rotated_at": now}

with open(out_path, 'w') as f:
    json.dump(subs, f, indent=2)
    f.write('\n')
PYEOF
  chmod 600 "${tmp_file}"
  mv "${tmp_file}" "${path[subscriptions]}"
}

function show_subscription_url {
  local username="$1"
  ensure_subscriptions_file
  local token
  token=$(python3 - "${path[subscriptions]}" "${username}" <<'PYEOF'
import json, sys
subs_path, username = sys.argv[1], sys.argv[2]
try:
    with open(subs_path) as f:
        subs = json.load(f)
    entry = subs.get("users", {}).get(username, {})
    print(entry.get("token", ""), end="")
except Exception:
    pass
PYEOF
)
  if [[ -z "${token}" ]]; then
    echo "No subscription token for user '${username}'. Run sync or enable subscriptions first." >&2
    return 1
  fi
  local sub_path="${config[subscription_path]:-sub}"
  local host="${config[server]}"
  local port="${config[port]}"
  if [[ "${port}" != "443" ]]; then
    host="${host}:${port}"
  fi
  echo "https://${host}/${sub_path}/${token}"
}

function rotate_subscription_token {
  local username="$1"
  ensure_subscriptions_file
  local tmp_file new_token
  tmp_file=$(mktemp "${config_path}/.subscriptions-XXXXXX.tmp")
  trap 'rm -f "${tmp_file}"' RETURN
  new_token=$(python3 - "${path[subscriptions]}" "${username}" "${tmp_file}" <<'PYEOF'
import json, sys, base64, secrets, time

subs_path, username, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(subs_path) as f:
        subs = json.load(f)
except Exception:
    subs = {"version": 1, "users": {}}
if not isinstance(subs.get("users"), dict):
    subs["users"] = {}

now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
token = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b'=').decode()
existing = subs["users"].get(username, {})
subs["users"][username] = {
    "token": token,
    "created_at": existing.get("created_at", now),
    "rotated_at": now,
}
with open(out_path, 'w') as f:
    json.dump(subs, f, indent=2)
    f.write('\n')
print(token, end="")
PYEOF
)
  chmod 600 "${tmp_file}"
  mv "${tmp_file}" "${path[subscriptions]}"
  echo "${new_token}"
}

function generate_selfsigned_certificate {
  openssl ecparam -name prime256v1 -genkey -out "${path[server_key]}"
  openssl req -new -key "${path[server_key]}" -out /tmp/server.csr -subj "/CN=${config[server]}"
  openssl x509 -req -days 365 -in /tmp/server.csr -signkey "${path[server_key]}" -out "${path[server_crt]}"
  cat "${path[server_key]}" "${path[server_crt]}" > "${path[server_pem]}"
  rm -f /tmp/server.csr
}

function generate_engine_config {
  local users_object=""
  local reality_object=""
  local tls_object=""
  local warp_object=""
  local mldsa_fragment=""
  local short_ids_json=""
  local flow_part=""
  local seed_part=""
  local user_entry=""
  local sid
  local user
  local -a short_ids_array=()
  local reality_port=443
  local temp_file
  if [[ ${config[security]} == 'reality' && ${config[domain]} =~ ":" ]]; then
    reality_port="${config[domain]#*:}"
  fi
  IFS=',' read -r -a short_ids_array <<< "${config[short_ids]}"
  for sid in "${short_ids_array[@]}"; do
    sid=$(echo "${sid}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    [[ -z "${sid}" ]] && continue
    if [[ -n "${short_ids_json}" ]]; then
      short_ids_json+=", "
    fi
    short_ids_json+="\"${sid}\""
  done
  if [[ -z "${short_ids_json}" ]]; then
    short_ids_json="\"${config[short_id]}\""
  fi
  if [[ ${config[xray_experimental]} == 'ON' && -n ${config[reality_mldsa65_seed]} ]]; then
    mldsa_fragment=', "mldsa65Seed": "'"${config[reality_mldsa65_seed]}"'"'
  fi
  reality_object='"security":"reality",
    "realitySettings":{
      "show": false,
      "dest": "'"${config[domain]%%:*}"':'"${reality_port}"'",
      "xver": 0,
      "serverNames": ["'"${config[domain]%%:*}"'"],
      "privateKey": "'"${config[private_key]}"'",
      "maxTimeDiff": 60000,
      "shortIds": ['"${short_ids_json}"']'"${mldsa_fragment}"',
      "limitFallbackUpload": {
        "afterBytes": '"${config[reality_limit_fallback_upload_after_bytes]}"',
        "bytesPerSec": '"${config[reality_limit_fallback_upload_bytes_per_sec]}"',
        "burstBytesPerSec": '"${config[reality_limit_fallback_upload_burst_bytes_per_sec]}"'
      },
      "limitFallbackDownload": {
        "afterBytes": '"${config[reality_limit_fallback_download_after_bytes]}"',
        "bytesPerSec": '"${config[reality_limit_fallback_download_bytes_per_sec]}"',
        "burstBytesPerSec": '"${config[reality_limit_fallback_download_burst_bytes_per_sec]}"'
      }
    }'
  tls_object='"security": "tls",
    "tlsSettings": {
      "certificates": [{
        "oneTimeLoading": true,
        "certificateFile": "/etc/xray/server.crt",
        "keyFile": "/etc/xray/server.key"
      }]
    }'
  if [[ ${config[warp]} == 'ON' ]]; then
    warp_object='{
      "protocol": "wireguard",
      "tag": "warp",
      "settings": {
        "secretKey": "'"${config[warp_private_key]}"'",
        "address": [
          "'"${config[warp_interface_ipv4]}"'/32",
          "'"${config[warp_interface_ipv6]}"'/128"
        ],
        "peers": [
          {
            "endpoint": "engage.cloudflareclient.com:2408",
            "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="
          }
        ],
        "mtu": 1280
      }
    },'
  fi
  for user in "${!users[@]}"; do
    if [ -n "$users_object" ]; then
      users_object="${users_object},"$'\n'
    fi
    flow_part=""
    seed_part=""
    if [[ ${config[transport]} == 'tcp' ]]; then
      flow_part=', "flow": "xtls-rprx-vision"'
    fi
    if [[ ${config[xray_experimental]} == 'ON' && \
          ${config[experimental_user]} == "${user}" && \
          -n ${config[experimental_test_seed]} ]]; then
      seed_part=', "testSeed": "'"${config[experimental_test_seed]}"'"'
    fi
    user_entry='{"id": "'"${users[${user}]}"'", "email": "'"${user}"'"'"${flow_part}${seed_part}"'}'
    users_object=${users_object}${user_entry}
  done
  cat >"${path[engine]}" <<EOF
{
  "version": {
    "min": "${config[xray_version_min]}"
  },
  "api": {
    "tag": "xray_api",
    "services": [
      "HandlerService",
      "StatsService",
      "RoutingService",
      "ReflectionService"
    ]
  },
  "stats": {},
  "metrics": {
    "tag": "xray_metrics"
  },
  "observatory": {
    "subjectSelector": ["internet", "warp"],
    "probeUrl": "https://www.google.com/generate_204",
    "probeInterval": "20s",
    "enableConcurrency": false
  },
  "burstObservatory": {
    "subjectSelector": ["internet", "warp"],
    "pingConfig": {
      "destination": "https://www.google.com/generate_204",
      "connectivity": "",
      "interval": "30s",
      "sampling": 3,
      "timeout": "5s"
    }
  },
  "log": {
    "loglevel": "error"
  },
  "dns": {
    "servers": [$([[ ${config[safenet]} == ON ]] && echo '"tcp+local://1.1.1.3","tcp+local://1.0.0.3"' || echo '"tcp+local://1.1.1.1","tcp+local://1.0.0.1"')]
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "xray_api_in"
    },
    {
      "listen": "127.0.0.1",
      "port": 11111,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "xray_metrics_in"
    },
    {
      "listen": "0.0.0.0",
      "port": 8080,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "${config[domain]%%:*}",
        "port": 80,
        "network": "tcp"
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "vless",
      "tag": "inbound",
      "settings": {
        "clients": [${users_object}],
        "decryption": "none"
      },
      "streamSettings": {
        $([[ ${config[transport]} == 'grpc' ]] && echo '"grpcSettings": {"serviceName": "'"${config[service_path]}"'"},' || true)
        $([[ ${config[transport]} == 'ws' ]] && echo '"wsSettings": {"headers": {"Host": "'"${config[server]}"'"}, "path": "/'"${config[service_path]}"'"},' || true)
        $([[ ${config[transport]} == 'http' ]] && echo '"httpSettings": {"host":["'"${config[server]}"'"], "path": "/'"${config[service_path]}"'"},' || true)
        $([[ ${config[transport]} == 'xhttp' ]] && echo '"xhttpSettings": {"host": "'"${config[server]}"'", "path": "/'"${config[service_path]}"'", "mode": "'"${config[xhttp_mode]:-stream-up}"'"},' || true)
        "network": "${config[transport]}",
        $(if [[ ${config[security]} == 'reality' ]]; then
          echo "${reality_object}"
        elif [[ ${config[transport]} == 'http' || ${config[transport]} == 'tcp' || ${config[transport]} == 'xhttp' ]]; then
          echo "${tls_object}"
        else
          echo '"security":"none"'
        fi)
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "internet"$(
        if [[ ${config[fragment]:-OFF} == ON ]]; then
          printf ',\n      "settings": {"fragment": {"packets": "tlshello", "length": "100-200", "interval": "10-20"}}'
        fi)
    },
    $([[ ${config[warp]} == ON ]] && echo "${warp_object}" || true)
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["xray_api_in"],
        "outboundTag": "xray_api"
      },
      {
        "type": "field",
        "inboundTag": ["xray_metrics_in"],
        "outboundTag": "xray_metrics"
      },
      {
        "type": "field",
        "ip": [
          $([[ ${config[warp]} == OFF ]] && echo '"geoip:cn", "geoip:ir",')
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "127.0.0.0/8",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10",
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "port": "25, 587, 465, 2525",
        "network": "tcp",
        "outboundTag": "block"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "outboundTag": "block",
        "domain": [
          $([[ ${config[safenet]} == ON ]] && echo '"geosite:category-porn",' || true)
          "geosite:category-ads-all",
          "domain:pushnotificationws.com",
          "domain:sunlight-leds.com",
          "domain:icecyber.org"
        ]
      },
      {
        "type": "field",
        "inboundTag": "inbound",
        "outboundTag": "$([[ ${config[warp]} == ON ]] && echo "warp" || echo "internet")"
      }
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "handshake": 2,
        "connIdle": 120,
        "statsUserUplink": true,
        "statsUserDownlink": true,
        "statsUserOnline": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  }
}
EOF
  if [[ -r ${config_path}/xray.patch ]]; then
    if ! jq empty "${config_path}/xray.patch"; then
      echo "xray.patch is not a valid json file. Fix it or remove it!"
      exit 1
    fi
    temp_file=$(mktemp)
    jq -s add "${path[engine]}" "${config_path}/xray.patch" > "${temp_file}"
    mv "${temp_file}" "${path[engine]}"
  fi
}

function generate_config {
  generate_docker_compose
  generate_engine_config
  if [[ ${config[security]} != "reality" ]]; then
    mkdir -p "${config_path}/certificate"
    generate_haproxy_config
    if [[ ! -r "${path[server_pem]}" || ! -r "${path[server_crt]}" || ! -r "${path[server_key]}" ]]; then
      generate_selfsigned_certificate
    fi
  fi
  if [[ ${config[security]} == "letsencrypt" ]]; then
    mkdir -p "${config_path}/certbot"
    generate_certbot_deployhook
    generate_certbot_dockerfile
    generate_certbot_script
  fi
  if [[ ${config[tgbot]} == "ON" ]]; then
    mkdir -p "${config_path}/tgbot/api"
    mkdir -p "${config_path}/tgbot/bot"
    mkdir -p "${config_path}/tgbot/helper"
    generate_tgbot_compose
    generate_tgbot_api_dockerfile
    generate_tgbot_bot_dockerfile
    generate_tgbot_helper_dockerfile
    sync_tgbot_sources || exit 1
  fi
  if [[ ${config[subscriptions]} == "ON" && ${config[security]} != "reality" ]]; then
    mkdir -p "${config_path}/subscription-api"
    generate_subscription_api_dockerfile
    sync_subscription_api_sources || exit 1
    sync_subscriptions_file || true
  fi
}

function get_ipv6 {
  curl -fsSL -m 3 --ipv6 https://cloudflare.com/cdn-cgi/trace 2> /dev/null | grep ip | cut -d '=' -f2
}

function print_client_configuration {
  local username=$1
  local client_config_base
  local client_config
  local ipv6
  local client_config_ipv6
  local sid
  local sid_index=0
  local primary_done=false
  local -a short_ids_array=()
  client_config_base="vless://"
  client_config_base="${client_config_base}${users[${username}]}"
  client_config_base="${client_config_base}@${config[server]}"
  client_config_base="${client_config_base}:${config[port]}"
  client_config_base="${client_config_base}?security=$([[ ${config[security]} == 'reality' ]] && echo reality || echo tls)"
  client_config_base="${client_config_base}&encryption=none"
  client_config_base="${client_config_base}&alpn=$([[ ${config[transport]} == 'ws' ]] && echo 'http/1.1' || echo 'h2,http/1.1')"
  client_config_base="${client_config_base}&headerType=none"
  client_config_base="${client_config_base}&fp=${config[fingerprint]:-random}"
  client_config_base="${client_config_base}&type=${config[transport]}"
  client_config_base="${client_config_base}&flow=$([[ ${config[transport]} == 'tcp' ]] && echo 'xtls-rprx-vision' || true)"
  client_config_base="${client_config_base}&sni=${config[domain]%%:*}"
  client_config_base="${client_config_base}$([[ ${config[transport]} == 'ws' || ${config[transport]} == 'http' || ${config[transport]} == 'xhttp' ]] && echo "&host=${config[server]}" || true)"
  client_config_base="${client_config_base}$([[ ${config[security]} == 'reality' ]] && echo "&pbk=${config[public_key]}" || true)"
  client_config_base="${client_config_base}$([[ ${config[transport]} == 'ws' || ${config[transport]} == 'http' || ${config[transport]} == 'xhttp' ]] && echo "&path=%2F${config[service_path]}" || true)"
  client_config_base="${client_config_base}$([[ ${config[transport]} == 'grpc' ]] && echo '&mode=gun' || true)"
  client_config_base="${client_config_base}$([[ ${config[transport]} == 'grpc' ]] && echo "&serviceName=${config[service_path]}" || true)"
  if [[ ${config[xray_experimental]} == 'ON' && \
        ${config[experimental_user]} == "${username}" && \
        -n ${config[experimental_test_seed]} ]]; then
    client_config_base="${client_config_base}&seed=${config[experimental_test_seed]}"
  fi
  if [[ ${config[security]} == 'reality' ]]; then
    IFS=',' read -r -a short_ids_array <<< "${config[short_ids]}"
  else
    short_ids_array+=("")
  fi
  for sid in "${short_ids_array[@]}"; do
    sid_index=$((sid_index+1))
    client_config="${client_config_base}"
    if [[ ${config[security]} == 'reality' ]]; then
      client_config="${client_config}&sid=${sid}"
    fi
    client_config="${client_config}#${username}$([[ ${sid_index} -gt 1 ]] && echo "-sid${sid_index}" || true)"
    if [[ ${primary_done} == false ]]; then
      primary_done=true
      echo ""
      echo "=================================================="
      echo "Client configuration:"
      echo ""
      echo "$client_config"
      echo ""
      echo "Or you can scan the QR code:"
      echo ""
      qrencode -t ansiutf8 "${client_config}"
      ipv6=$(get_ipv6)
      if [[ -n $ipv6 ]]; then
        client_config_ipv6=$(echo "$client_config" | sed "s/@${config[server]}:/@[${ipv6}]:/" | sed "s/#${username}/#${username}-ipv6/")
        echo ""
        echo "==================IPv6 Config======================"
        echo "Client configuration:"
        echo ""
        echo "$client_config_ipv6"
        echo ""
        echo "Or you can scan the QR code:"
        echo ""
        qrencode -t ansiutf8 "${client_config_ipv6}"
      fi
      continue
    fi
    echo ""
    echo "Alternative rotated shortId config #${sid_index}:"
    echo "${client_config}"
  done
}

function upgrade {
  local uuid
  local warp_token
  local warp_id
  if [[ -e "${HOME}/reality/config" ]]; then
    ${docker_cmd} --project-directory "${HOME}/reality" down --remove-orphans --timeout 2
    mv -f "${HOME}/reality" ${config_path}
  fi
  uuid=$(grep '^uuid=' "${path[config]}" 2>/dev/null | cut -d= -f2 || true)
  if [[ -n $uuid ]]; then
    sed -i '/^uuid=/d' "${path[users]}"
    echo "RealityEZPZ=${uuid}" >> "${path[users]}"
    sed -i 's|=true|=ON|g; s|=false|=OFF|g' "${path[users]}"
  fi
  rm -f "${config_path}/xray.conf"
  rm -f "${config_path}/singbox.conf"
  if ! ${docker_cmd} ls | grep ${compose_project} >/dev/null && [[ -r ${path[compose]} ]]; then
    ${docker_cmd} --project-directory ${config_path} down --remove-orphans --timeout 2
  fi
  if [[ -r ${path[config]} ]]; then
    sed -i 's|transport=h2|transport=http|g' "${path[config]}"
    sed -i 's|transport=tuic|transport=tcp|g' "${path[config]}"
    sed -i 's|transport=hysteria2|transport=tcp|g' "${path[config]}"
    sed -i 's|transport=shadowtls|transport=tcp|g' "${path[config]}"
    sed -i 's|security=tls-invalid|security=selfsigned|g' "${path[config]}"
    sed -i 's|security=tls-valid|security=letsencrypt|g' "${path[config]}"
    sed -i 's|^tgbot_admins=|tgbot_admin_ids=|g' "${path[config]}"
    sed -i '/^core=/d' "${path[config]}"
  fi
  for key in "${!path[@]}"; do
    if [[ -d "${path[$key]}" ]]; then
      rm -rf "${path[$key]}"
    fi
  done
  if [[ -d "${config_path}/warp" ]]; then
    ${docker_cmd} --project-directory ${config_path} -p ${compose_project} down --remove-orphans --timeout 2 || true
    warp_token=$(cat ${config_path}/warp/reg.json | jq -r '.api_token')
    warp_id=$(cat ${config_path}/warp/reg.json | jq -r '.registration_id')
    warp_api "DELETE" "/reg/${warp_id}" "" "${warp_token}" >/dev/null 2>&1 || true
    rm -rf "${config_path}/warp"
  fi
}

function main_menu {
  local selection
  while true; do
    selection=$(whiptail --clear --backtitle "$BACKTITLE" --title "Server Management" \
      --menu "$MENU" $HEIGHT $WIDTH $CHOICE_HEIGHT \
      --ok-button "Select" \
      --cancel-button "Exit" \
      "1" "Add New User" \
      "2" "Delete User" \
      "3" "View User" \
      "4" "View Server Config" \
      "5" "Configuration" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    case $selection in
      1 )
        add_user_menu
        ;;
      2 )
        delete_user_menu
        ;;
      3 )
        view_user_menu
        ;;
      4 )
        view_config_menu
        ;;
      5 )
        configuration_menu
        ;;
    esac
  done
}

function add_user_menu {
  local username
  local message
  while true; do
    username=$(whiptail \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Add New User" \
      --inputbox "Enter username:" \
      $HEIGHT $WIDTH \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ! $username =~ ${regex[username]} ]]; then
      message_box "Invalid Username" "Username can only contains A-Z, a-z and 0-9"
      continue
    fi
    if [[ -n ${users[$username]} ]]; then
      message_box "Invalid Username" '"'"${username}"'" already exists.'
      continue
    fi
    users[$username]=$(cat /proc/sys/kernel/random/uuid)
    update_users_file
    whiptail \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Add New User" \
      --yes-button "View User" \
      --no-button "Return" \
      --yesno 'User "'"${username}"'" has been created.' \
      $HEIGHT $WIDTH \
      3>&1 1>&2 2>&3
    if [[ $? -ne 0 ]]; then
      break
    fi
    view_user_menu "${username}"
  done
}

function delete_user_menu {
  local username
  while true; do
    username=$(list_users_menu "Delete User")
    if [[ $? -ne 0 ]]; then
      return 0
    fi
    if [[ ${#users[@]} -eq 1 ]]; then
      message_box "Delete User" "You cannot delete the only user.\nAt least one user is needed.\nCreate a new user, then delete this one."
      continue
    fi
    whiptail \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Delete User" \
      --yesno "Are you sure you want to delete $username?" \
      $HEIGHT $WIDTH \
      3>&1 1>&2 2>&3
    if [[ $? -ne 0 ]]; then
      continue
    fi
    unset "users[$username]"
    update_users_file
    message_box "Delete User" 'User "'"${username}"'" has been deleted.'
  done
}

function view_user_menu {
  local username
  local user_config
  while true; do
    if [[ $# -gt 0 ]]; then
      username=$1
    else
      username=$(list_users_menu "View User")
      if [[ $? -ne 0 ]]; then
        return 0
      fi
    fi
    user_config=$(echo "
Protocol: vless
Remarks: ${username}
Address: ${config[server]}
Port: ${config[port]}
ID: ${users[$username]}
Flow: $([[ ${config[transport]} == 'tcp' ]] && echo 'xtls-rprx-vision' || true)
Network: ${config[transport]}
$([[ ${config[transport]} == 'ws' || ${config[transport]} == 'http' || ${config[transport]} == 'xhttp' ]] && echo "Host Header: ${config[server]}" || true)
$([[ ${config[transport]} == 'ws' || ${config[transport]} == 'http' || ${config[transport]} == 'xhttp' ]] && echo "Path: /${config[service_path]}" || true)
$([[ ${config[transport]} == 'grpc' ]] && echo 'gRPC mode: gun' || true)
$([[ ${config[transport]} == 'grpc' ]] && echo 'gRPC serviceName: '"${config[service_path]}" || true)
TLS: $([[ ${config[security]} == 'reality' ]] && echo 'reality' || echo 'tls')
SNI: ${config[domain]%%:*}
ALPN: $([[ ${config[transport]} == 'ws' ]] && echo 'http/1.1' || echo 'h2,http/1.1')
Fingerprint: chrome
$([[ ${config[security]} == 'reality' ]] && echo "PublicKey: ${config[public_key]}" || true)
$([[ ${config[security]} == 'reality' ]] && echo "ShortIds: ${config[short_ids]}" || true)
$([[ ${config[xray_experimental]} == 'ON' && ${config[experimental_user]} == "${username}" && -n ${config[experimental_test_seed]} ]] && echo "Experimental Seed: ${config[experimental_test_seed]}" || true)
    " | tr -s '\n')
    whiptail \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "${username} details" \
      --yes-button "View QR" \
      --no-button "Return" \
      --yesno "${user_config}" \
      $HEIGHT $WIDTH \
      3>&1 1>&2 2>&3
    if [[ $? -eq 0 ]]; then
      clear
      print_client_configuration "${username}"
      echo
      echo "Press Enter to return ..."
      read -r
      clear
    fi
    if [[ $# -gt 0 ]]; then
      return 0
    fi
  done
}

function list_users_menu {
  local title=$1
  local -a options=()
  local key
  local value
  local selection
  while IFS=' ' read -r key value; do
    options+=("${key}" "${value}")
  done < <(dict_expander users)
  selection=$(whiptail --clear --noitem --backtitle "$BACKTITLE" --title "$title" \
    --menu "Select the user" $HEIGHT $WIDTH $CHOICE_HEIGHT "${options[@]}" \
    3>&1 1>&2 2>&3)
  if [[ $? -ne 0 ]]; then
    return 1
  fi
  echo "${selection}"
}

function show_server_config {
  local server_config
  server_config="Core: xray"
  server_config=$server_config$'\n'"Server Address: ${config[server]}"
  server_config=$server_config$'\n'"Domain SNI: ${config[domain]}"
  server_config=$server_config$'\n'"Port: ${config[port]}"
  server_config=$server_config$'\n'"Transport: ${config[transport]}"
  server_config=$server_config$'\n'"Security: ${config[security]}"
  server_config=$server_config$'\n'"Xray version.min: ${config[xray_version_min]}"
  server_config=$server_config$'\n'"Safenet: ${config[safenet]}"
  server_config=$server_config$'\n'"WARP: ${config[warp]}"
  server_config=$server_config$'\n'"REALITY shortIds: ${config[short_ids]}"
  server_config=$server_config$'\n'"Fallback Upload Limit (after/base/burst): ${config[reality_limit_fallback_upload_after_bytes]}/${config[reality_limit_fallback_upload_bytes_per_sec]}/${config[reality_limit_fallback_upload_burst_bytes_per_sec]}"
  server_config=$server_config$'\n'"Fallback Download Limit (after/base/burst): ${config[reality_limit_fallback_download_after_bytes]}/${config[reality_limit_fallback_download_bytes_per_sec]}/${config[reality_limit_fallback_download_burst_bytes_per_sec]}"
  server_config=$server_config$'\n'"Xray Experimental: ${config[xray_experimental]}"
  server_config=$server_config$'\n'"Experimental User: ${config[experimental_user]}"
  server_config=$server_config$'\n'"WARP License: $([[ -n ${config[warp_license]} ]] && echo '[set]' || echo '[empty]')"
  server_config=$server_config$'\n'"Telegram Bot: ${config[tgbot]}"
  server_config=$server_config$'\n'"Telegram Bot Token: [hidden]"
  server_config=$server_config$'\n'"Telegram Bot Admin IDs: ${config[tgbot_admin_ids]}"
  server_config=$server_config$'\n'"Internal API Token: [hidden]"
  server_config=$server_config$'\n'"Internal Helper Token: [hidden]"
  echo "${server_config}"
}

function view_config_menu {
  local server_config
  server_config=$(show_server_config)
  message_box "Server Configuration" "${server_config}"
}

function restart_menu {
  whiptail \
    --clear \
    --backtitle "$BACKTITLE" \
    --title "Restart Services" \
    --yesno "Are you sure to restart services?" \
    $HEIGHT $WIDTH \
    3>&1 1>&2 2>&3
  if [[ $? -ne 0 ]]; then
    return
  fi
  restart_docker_compose
  if [[ ${config[tgbot]} == 'ON' ]]; then
    restart_tgbot_compose
  fi
}

function regenerate_menu {
  whiptail \
    --clear \
    --backtitle "$BACKTITLE" \
    --title "Regenrate keys" \
    --yesno "Are you sure to regenerate keys?" \
    $HEIGHT $WIDTH \
    3>&1 1>&2 2>&3
  if [[ $? -ne 0 ]]; then
    return
  fi
  generate_keys
  config[public_key]=${config_file[public_key]}
  config[private_key]=${config_file[private_key]}
  config[short_id]=${config_file[short_id]}
  update_config_file
  message_box "Regenerate keys" "All keys has been regenerated."
}

function restore_defaults_menu {
  whiptail \
    --clear \
    --backtitle "$BACKTITLE" \
    --title "Restore Default Config" \
    --yesno "Are you sure to restore default configuration?" \
    $HEIGHT $WIDTH \
    3>&1 1>&2 2>&3
  if [[ $? -ne 0 ]]; then
    return
  fi
  restore_defaults
  update_config_file
  message_box "Restore Default Config" "All configurations has been restored to their defaults."
}

function configuration_menu {
  local selection
  while true; do
    selection=$(whiptail --clear --backtitle "$BACKTITLE" --title "Configuration" \
      --menu "Select an option:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
      "1" "Server Address" \
      "2" "Transport" \
      "3" "SNI Domain" \
      "4" "Security" \
      "5" "Port" \
      "6" "Safe Internet" \
      "7" "WARP" \
      "8" "Telegram Bot" \
      "9" "Restart Services" \
      "10" "Regenerate Keys" \
      "11" "Restore Defaults" \
      "12" "Create Backup" \
      "13" "Restore Backup" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    case $selection in
      1 )
        config_server_menu
        ;;
      2 )
        config_transport_menu
        ;;
      3 )
        config_sni_domain_menu
        ;;
      4 )
        config_security_menu
        ;;
      5 )
        config_port_menu
        ;;
      6 )
        config_safenet_menu
        ;;
      7 )
        config_warp_menu
        ;;
      8 )
        config_tgbot_menu
        ;;
      9 )
        restart_menu
        ;;
      10 )
        regenerate_menu
        ;;
      11 )
        restore_defaults_menu
        ;;
      12 )
        backup_menu
        ;;
      13 )
        restore_backup_menu
        ;;
    esac
  done
}

function config_server_menu {
  local server
  while true; do
    server=$(whiptail --clear --backtitle "$BACKTITLE" --title "Server Address" \
      --inputbox "Enter Server IP or Domain:" $HEIGHT $WIDTH "${config["server"]}" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ! ${server} =~ ${regex[domain]} && ${config[security]} == 'letsencrypt' ]]; then
      message_box 'Invalid Configuration' 'You have to assign a valid domain to server if you want to use "letsencrypt" certificate.'
      continue
    fi
    if [[ -z ${server} ]]; then
      server="${defaults[server]}"
    fi
    config[server]="${server}"
    if [[ ${config[security]} != 'reality' ]]; then
      config[domain]="${server}"
    fi
    update_config_file
    break
  done
}

function config_transport_menu {
  local transport
  while true; do
    transport=$(whiptail --clear --backtitle "$BACKTITLE" --title "Transport" \
      --radiolist --noitem "Select a transport protocol:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
      "tcp" "$([[ "${config[transport]}" == 'tcp' ]] && echo 'on' || echo 'off')" \
      "http" "$([[ "${config[transport]}" == 'http' ]] && echo 'on' || echo 'off')" \
      "grpc" "$([[ "${config[transport]}" == 'grpc' ]] && echo 'on' || echo 'off')" \
      "ws" "$([[ "${config[transport]}" == 'ws' ]] && echo 'on' || echo 'off')" \
      "xhttp" "$([[ "${config[transport]}" == 'xhttp' ]] && echo 'on' || echo 'off')" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ${transport} == 'ws' && ${config[security]} == 'reality' ]]; then
      message_box 'Invalid Configuration' 'You cannot use "ws" transport with "reality" TLS certificate. Use other transports or change TLS certifcate to "letsencrypt" or "selfsigned"'
      continue
    fi
    config[transport]=$transport
    update_config_file
    break
  done
}

function config_sni_domain_menu {
  local sni_domain
  while true; do
    sni_domain=$(whiptail --clear --backtitle "$BACKTITLE" --title "SNI Domain" \
      --inputbox "Enter SNI domain:" $HEIGHT $WIDTH "${config[domain]}" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ! $sni_domain =~ ${regex[domain_port]} ]]; then
      message_box "Invalid Domain" '"'"${sni_domain}"'" in not a valid domain.'
      continue
    fi
    config[domain]=$sni_domain
    update_config_file
    break
  done
}

function config_security_menu {
  local security
  local free_80=true
  while true; do
    security=$(whiptail --clear --backtitle "$BACKTITLE" --title "Security Type" \
      --radiolist --noitem "Select a security type:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
      "reality" "$([[ "${config[security]}" == 'reality' ]] && echo 'on' || echo 'off')" \
      "letsencrypt" "$([[ "${config[security]}" == 'letsencrypt' ]] && echo 'on' || echo 'off')" \
      "selfsigned" "$([[ "${config[security]}" == 'selfsigned' ]] && echo 'on' || echo 'off')" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ! ${config[server]} =~ ${regex[domain]} && ${security} == 'letsencrypt' ]]; then
      message_box 'Invalid Configuration' 'You have to assign a valid domain to server if you want to use "letsencrypt" as security type'
      continue
    fi
    if [[ ${config[transport]} == 'ws' && ${security} == 'reality' ]]; then
      message_box 'Invalid Configuration' 'You cannot use "reality" TLS certificate with "ws" transport protocol. Change TLS certifcate to "letsencrypt" or "selfsigned" or use other transport protocols'
      continue
    fi
    if [[ ${security} == 'letsencrypt' && ${config[port]} -ne 443 ]]; then
      if lsof -i :80 >/dev/null 2>&1; then
        free_80=false
        for container in $(${docker_cmd} -p ${compose_project} ps -q); do
          if docker port "${container}" | grep '0.0.0.0:80' >/dev/null 2>&1; then
            free_80=true
            break
          fi
        done
      fi
      if [[ ${free_80} != 'true' ]]; then
        message_box 'Port 80 must be free if you want to use "letsencrypt" as the security option.'
        continue
      fi
    fi
    if [[ ${security} != 'reality' ]]; then
      config[domain]="${config[server]}"
    fi
    if [[ ${security} == 'reality' ]]; then
      config[domain]="${defaults[domain]}"
    fi
    config[security]="${security}"
    update_config_file
    break
  done
}

function config_port_menu {
  local port
  while true; do
    port=$(whiptail --clear --backtitle "$BACKTITLE" --title "Port" \
      --inputbox "Enter port number:" $HEIGHT $WIDTH "${config[port]}" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ! $port =~ ${regex[port]} ]]; then
      message_box "Invalid Port" "Port must be an integer"
      continue
    fi
    if ((port < 1 || port > 65535)); then
      message_box "Invalid Port" "Port must be between 1 to 65535"
      continue
    fi
    config[port]=$port
    update_config_file
    break
  done
}

function config_safenet_menu {
  local safenet
  safenet=$(whiptail --clear --backtitle "$BACKTITLE" --title "Safe Internet" \
    --radiolist --noitem "Enable blocking malware and adult content" $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "Enable" "$([[ "${config[safenet]}" == 'ON' ]] && echo 'on' || echo 'off')" \
    "Disable" "$([[ "${config[safenet]}" == 'OFF' ]] && echo 'on' || echo 'off')" \
    3>&1 1>&2 2>&3)
  if [[ $? -ne 0 ]]; then
    return
  fi
  config[safenet]=$([[ $safenet == 'Enable' ]] && echo ON || echo OFF)
  update_config_file
}

function config_warp_menu {
  local warp
  local warp_license
  local error
  local temp_file
  local exit_code
  local old_warp=${config[warp]}
  local old_warp_license=${config[warp_license]}
  while true; do
    warp=$(whiptail --clear --backtitle "$BACKTITLE" --title "WARP" \
      --radiolist --noitem "Enable WARP:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
      "Enable" "$([[ "${config[warp]}" == 'ON' ]] && echo 'on' || echo 'off')" \
      "Disable" "$([[ "${config[warp]}" == 'OFF' ]] && echo 'on' || echo 'off')" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ $warp == 'Disable' ]]; then
      config[warp]=OFF
      if [[ -n ${config[warp_id]} && -n ${config[warp_token]} ]]; then
        warp_delete_account "${config[warp_id]}" "${config[warp_token]}"
      fi
      return
    fi
    if [[ -z ${config[warp_private_key]} || \
          -z ${config[warp_token]} || \
          -z ${config[warp_id]} || \
          -z ${config[warp_client_id]} || \
          -z ${config[warp_interface_ipv4]} || \
          -z ${config[warp_interface_ipv6]} ]]; then
      temp_file=$(mktemp)
      warp_create_account > "${temp_file}"
      exit_code=$?
      error=$(< "${temp_file}")
      rm -f "${temp_file}"
      if [[ ${exit_code} -ne 0 ]]; then
        message_box "WARP account creation error" "${error}"
        continue
      fi
    fi
    config[warp]=ON
    while true; do
      warp_license=$(whiptail --clear --backtitle "$BACKTITLE" --title "WARP+ License" \
        --inputbox "Enter WARP+ License (optional). Leave blank for free WARP:" $HEIGHT $WIDTH "${config[warp_license]}" \
        3>&1 1>&2 2>&3)
      if [[ $? -ne 0 ]]; then
        return
      fi
      if [[ -z $warp_license ]]; then
        config[warp_license]=""
        update_config_file
        return
      fi
      if [[ ! $warp_license =~ ${regex[warp_license]} ]]; then
        message_box "Invalid Input" "Invalid WARP+ License"
        continue
      fi
      temp_file=$(mktemp)
      warp_add_license "${config[warp_id]}" "${config[warp_token]}" "${warp_license}" > "${temp_file}"
      exit_code=$?
      error=$(< "${temp_file}")
      rm -f "${temp_file}"
      if [[ ${exit_code} -ne 0 ]]; then
        message_box "WARP license error" "${error}"
        continue
      fi
      return
    done
  done
  config[warp]=$old_warp
  config[warp_license]=$old_warp_license
}

function config_tgbot_menu {
  local tgbot
  local tgbot_token
  local tgbot_admin_ids
  local old_tgbot=${config[tgbot]}
  local old_tgbot_token=${config[tgbot_token]}
  local old_tgbot_admin_ids=${config[tgbot_admin_ids]}
  local old_api_token=${config[api_token]}
  local old_helper_token=${config[helper_token]}
  while true; do
    tgbot=$(whiptail --clear --backtitle "$BACKTITLE" --title "Enable Telegram Bot" \
      --radiolist --noitem "Enable Telegram Bot:" $HEIGHT $WIDTH $CHOICE_HEIGHT \
      "Enable" "$([[ "${config[tgbot]}" == 'ON' ]] && echo 'on' || echo 'off')" \
      "Disable" "$([[ "${config[tgbot]}" == 'OFF' ]] && echo 'on' || echo 'off')" \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ $tgbot == 'Disable' ]]; then
      config[tgbot]=OFF
      update_config_file
      return
    fi
    config[tgbot]=ON
    if [[ -z ${config[api_token]} ]]; then
      config[api_token]=$(openssl rand -hex 24)
    fi
    if [[ -z ${config[helper_token]} ]]; then
      config[helper_token]=$(openssl rand -hex 24)
    fi
    while true; do
      tgbot_token=$(whiptail --clear --backtitle "$BACKTITLE" --title "Telegram Bot Token" \
        --inputbox "Enter Telegram Bot Token:" $HEIGHT $WIDTH "${config[tgbot_token]}" \
        3>&1 1>&2 2>&3)
      if [[ $? -ne 0 ]]; then
        break
      fi
      if [[ ! $tgbot_token =~ ${regex[tgbot_token]} ]]; then
        message_box "Invalid Input" "Invalid Telegram Bot Token"
        continue
      fi 
      if ! curl -sSfL -m 3 "https://api.telegram.org/bot${tgbot_token}/getMe" >/dev/null 2>&1; then
        message_box "Invalid Input" "Telegram Bot Token is incorrect. Check it again."
        continue
      fi
      config[tgbot_token]=$tgbot_token
      while true; do
        tgbot_admin_ids=$(whiptail --clear --backtitle "$BACKTITLE" --title "Telegram Bot Admin IDs" \
          --inputbox "Enter Telegram User IDs allowed to use the bot (comma-separated):" $HEIGHT $WIDTH "${config[tgbot_admin_ids]}" \
          3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then
          break
        fi
        if [[ ! $tgbot_admin_ids =~ ${regex[tgbot_admin_ids]} ]]; then
          message_box "Invalid Input" "Invalid Telegram user IDs format."
          continue
        fi
        config[tgbot_admin_ids]=$tgbot_admin_ids
        update_config_file
        return
      done
    done
  done
  config[tgbot]=$old_tgbot
  config[tgbot_token]=$old_tgbot_token
  config[tgbot_admin_ids]=$old_tgbot_admin_ids
  config[api_token]=$old_api_token
  config[helper_token]=$old_helper_token
}

function backup_menu {
  local backup_password
  local result
  local upload_temp=false
  backup_password=$(whiptail \
    --clear \
    --backtitle "$BACKTITLE" \
    --title "Backup" \
    --inputbox "Choose a password for encrypted backup file." \
    $HEIGHT $WIDTH \
    3>&1 1>&2 2>&3)
  if [[ $? -ne 0 ]]; then
    return
  fi
  if [[ -z "${backup_password}" ]]; then
    message_box "Backup Failed" "Backup password is required."
    return
  fi
  if whiptail \
    --clear \
    --backtitle "$BACKTITLE" \
    --title "Backup Upload" \
    --yes-button "Upload" \
    --no-button "Local only" \
    --yesno "Upload encrypted backup to temp.sh? (recommended: Local only)" \
    $HEIGHT $WIDTH \
    3>&1 1>&2 2>&3; then
    upload_temp=true
  fi

  if result=$(backup "${backup_password}" "${upload_temp}" 2>&1); then
    clear
    if [[ "${upload_temp}" == true ]]; then
      echo "Encrypted backup uploaded successfully."
      echo "Download URL:"
      echo ""
      echo "${result}"
      echo ""
      echo "The URL is valid for 3 days."
    else
      echo "Encrypted backup created successfully."
      echo "Local file:"
      echo ""
      echo "${result}"
    fi
    echo ""
    echo
    echo "Press Enter to return ..."
    read -r
    clear
  else
    message_box "Backup Failed" "${result}"
  fi
}

function restore_backup_menu {
  local backup_file
  local backup_password
  local result
  while true; do
    backup_file=$(whiptail \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Restore Backup" \
      --inputbox "Enter backup file path or URL" \
      $HEIGHT $WIDTH \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      break
    fi
    if [[ ! $backup_file =~ ${regex[file_path]} ]] && [[ ! $backup_file =~ ${regex[url]} ]]; then
      message_box "Invalid Backup path of URL" "Backup file path or URL is not valid."
      continue
    fi
    backup_password=$(whiptail \
      --clear \
      --backtitle "$BACKTITLE" \
      --title "Restore Backup" \
      --inputbox "Enter backup file password." \
      $HEIGHT $WIDTH \
      3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then
      continue
    fi
    if result=$(restore "${backup_file}" "${backup_password}" 2>&1); then
      parse_config_file
      parse_users_file
      build_config
      update_config_file
      update_users_file
      message_box "Backup Restore Successful" "Backup has been restored successfully."
      args[restart]=true
      break
    else
      message_box "Backup Restore Failed" "${result}"
    fi
  done
}

function restart_docker_compose {
  ${docker_cmd} --project-directory ${config_path} -p ${compose_project} up -d --build --remove-orphans
}

function restart_tgbot_compose {
  ${docker_cmd} --project-directory ${config_path}/tgbot -p ${tgbot_project} up -d --build --remove-orphans
}

function restart_container {
  if [[ -z "$(${docker_cmd} ls | grep "${path[compose]}" | grep running || true)" ]]; then
    restart_docker_compose
    return
  fi
  if ${docker_cmd} --project-directory ${config_path} -p ${compose_project} ps --services "$1" | grep "$1"; then
    ${docker_cmd} --project-directory ${config_path} -p ${compose_project} restart --timeout 2 "$1"
  fi
}

function warp_api {
  local verb=$1
  local resource=$2
  local data=$3
  local token=$4
  local team_token=$5
  local endpoint=https://api.cloudflareclient.com/v0a2158
  local temp_file
  local error
  local command
  local headers=(
    "User-Agent: okhttp/3.12.1"
    "CF-Client-Version: a-6.10-2158"
    "Content-Type: application/json"
  )
  temp_file=$(mktemp)
  if [[ -n ${token} ]]; then
    headers+=("Authorization: Bearer ${token}")
  fi
  if [[ -n ${team_token} ]]; then
    headers+=("Cf-Access-Jwt-Assertion: ${team_token}")
  fi
  command="curl -sLX ${verb} -m 3 -w '%{http_code}' -o ${temp_file} ${endpoint}${resource}"
  for header in "${headers[@]}"; do
    command+=" -H '${header}'"
  done
  if [[ -n ${data} ]]; then
    command+=" -d '${data}'"
  fi
  response_code=$(( $(eval "${command}" || true) ))
  response_body=$(cat "${temp_file}")
  rm -f "${temp_file}"
  if [[ response_code -eq 0 ]]; then
    return 1
  fi
  if [[ response_code -gt 399 ]]; then
    error=$(echo "${response_body}" | jq -r '.errors[0].message' 2> /dev/null || true)
    if [[ ${error} != 'null' ]]; then
      echo "${error}"
    fi
    return 2
  fi
  echo "${response_body}"
}

function warp_create_account {
  local response
  docker run --rm -it -v "${config_path}":/data "${image[wgcf]}" register --config /data/wgcf-account.toml --accept-tos
  if [[ $? -ne 0 || ! -r ${config_path}/wgcf-account.toml ]]; then
    echo "WARP account creation has been failed!"
    return 1
  fi
  config[warp_token]=$(cat ${config_path}/wgcf-account.toml | grep 'access_token' | cut -d "'" -f2)
  config[warp_id]=$(cat ${config_path}/wgcf-account.toml | grep 'device_id' | cut -d "'" -f2)
  config[warp_private_key]=$(cat ${config_path}/wgcf-account.toml | grep 'private_key' | cut -d "'" -f2)
  rm -f ${config_path}/wgcf-account.toml
  response=$(warp_api "GET" "/reg/${config[warp_id]}" "" "${config[warp_token]}")
  if [[ $? -ne 0 ]]; then
    if [[ -n ${response} ]]; then
      echo "${response}"
    fi
    return 1
  fi
  config[warp_client_id]=$(echo "${response}" | jq -r '.config.client_id')
  config[warp_interface_ipv4]=$(echo "${response}" | jq -r '.config.interface.addresses.v4')
  config[warp_interface_ipv6]=$(echo "${response}" | jq -r '.config.interface.addresses.v6')
  update_config_file
}

function warp_add_license {
  local id=$1
  local token=$2
  local license=$3
  local data
  local response
  data='{"license": "'$license'"}'
  response=$(warp_api "PUT" "/reg/${id}/account" "${data}" "${token}")
  if [[ $? -ne 0 ]]; then
    if [[ -n ${response} ]]; then
      echo "${response}"
    fi
    return 1
  fi
  config[warp_license]=${license}
  update_config_file
}

function warp_delete_account {
  local id=$1
  local token=$2
  warp_api "DELETE" "/reg/${id}" "" "${token}" >/dev/null 2>&1 || true
  config[warp_private_key]=""
  config[warp_token]=""
  config[warp_id]=""
  config[warp_client_id]=""
  config[warp_interface_ipv4]=""
  config[warp_interface_ipv6]=""
  update_config_file
}

function check_reload {
  declare -A restart
  generate_config
  validate_engine_config
  secure_file_permissions
  for key in "${!path[@]}"; do
    if [[ "${md5["$key"]}" != $(get_md5 "${path[$key]}") ]]; then
      restart["${service["$key"]}"]='true'
      md5["$key"]=$(get_md5 "${path[$key]}")
    fi
  done
  if [[ "${restart[tgbot]}" == 'true' && "${config[tgbot]}" == 'ON' ]]; then
    restart_tgbot_compose
  fi
  if [[ "${config[tgbot]}" == 'OFF' ]]; then
    ${docker_cmd} --project-directory ${config_path}/tgbot -p ${tgbot_project} down --remove-orphans --timeout 2 >/dev/null 2>&1 || true
  fi
  if [[ "${restart[compose]}" == 'true' ]]; then
    restart_docker_compose
    return
  fi
  for key in "${!restart[@]}"; do
    if [[ $key != 'none' && $key != 'tgbot' ]]; then
      restart_container "${key}"
    fi
  done
}

function message_box {
  local title=$1
  local message=$2
  whiptail \
    --clear \
    --backtitle "$BACKTITLE" \
    --title "$title" \
    --msgbox "$message" \
    $HEIGHT $WIDTH \
    3>&1 1>&2 2>&3
}

function get_md5 {
  local file_path
  file_path=$1
  md5sum "${file_path}" 2>/dev/null | cut -f1 -d' ' || true
}

function validate_engine_config {
  local output
  if [[ ! -r "${path[engine]}" ]]; then
    echo "Engine config not found: ${path[engine]}" >&2
    return 1
  fi
  if ! output=$(docker run --rm \
    -v "${path[engine]}:/etc/xray/config.json:ro" \
    "${image[xray]}" xray -test -c /etc/xray/config.json 2>&1); then
    echo "Xray config validation failed:" >&2
    echo "${output}" >&2
    return 1
  fi
  return 0
}

function secure_file_permissions {
  local file
  local dir
  local secret_files=(
    "${config_path}/config"
    "${config_path}/users"
    "${config_path}/engine.conf"
    "${config_path}/docker-compose.yml"
    "${config_path}/tgbot/docker-compose.yml"
    "${config_path}/tgbot/api/main.go"
    "${config_path}/tgbot/bot/main.go"
    "${config_path}/tgbot/helper/main.go"
    "${config_path}/certificate/server.key"
    "${config_path}/subscriptions.json"
    "${config_path}/subscription-api/main.go"
  )
  local secret_dirs=(
    "${config_path}"
    "${config_path}/tgbot"
    "${config_path}/tgbot/api"
    "${config_path}/tgbot/bot"
    "${config_path}/tgbot/helper"
    "${config_path}/certificate"
    "${config_path}/subscription-api"
  )
  for dir in "${secret_dirs[@]}"; do
    if [[ -d "${dir}" ]]; then
      chmod 700 "${dir}" 2>/dev/null || true
    fi
  done
  for file in "${secret_files[@]}"; do
    if [[ -f "${file}" ]]; then
      chmod 600 "${file}" 2>/dev/null || true
    fi
  done
}

function generate_file_list {
  path[config]="${config_path}/config"
  path[users]="${config_path}/users"
  path[compose]="${config_path}/docker-compose.yml"
  path[engine]="${config_path}/engine.conf"
  path[haproxy]="${config_path}/haproxy.cfg"
  path[certbot_deployhook]="${config_path}/certbot/deployhook.sh"
  path[certbot_dockerfile]="${config_path}/certbot/Dockerfile"
  path[certbot_startup]="${config_path}/certbot/startup.sh"
  path[server_pem]="${config_path}/certificate/server.pem"
  path[server_key]="${config_path}/certificate/server.key"
  path[server_crt]="${config_path}/certificate/server.crt"
  path[tgbot_api_main]="${config_path}/tgbot/api/main.go"
  path[tgbot_api_gomod]="${config_path}/tgbot/api/go.mod"
  path[tgbot_api_dockerfile]="${config_path}/tgbot/api/Dockerfile"
  path[tgbot_bot_main]="${config_path}/tgbot/bot/main.go"
  path[tgbot_bot_gomod]="${config_path}/tgbot/bot/go.mod"
  path[tgbot_bot_gosum]="${config_path}/tgbot/bot/go.sum"
  path[tgbot_bot_dockerfile]="${config_path}/tgbot/bot/Dockerfile"
  path[tgbot_helper_main]="${config_path}/tgbot/helper/main.go"
  path[tgbot_helper_gomod]="${config_path}/tgbot/helper/go.mod"
  path[tgbot_helper_dockerfile]="${config_path}/tgbot/helper/Dockerfile"
  path[tgbot_compose]="${config_path}/tgbot/docker-compose.yml"
  path[subscriptions]="${config_path}/subscriptions.json"
  path[subscription_api_main]="${config_path}/subscription-api/main.go"
  path[subscription_api_gomod]="${config_path}/subscription-api/go.mod"
  path[subscription_api_dockerfile]="${config_path}/subscription-api/Dockerfile"

  service[config]='none'
  service[users]='none'
  service[compose]='compose'
  service[engine]='engine'
  service[haproxy]='haproxy'
  service[certbot_deployhook]='certbot'
  service[certbot_dockerfile]='compose'
  service[certbot_startup]='certbot'
  service[server_pem]='haproxy'
  service[server_key]='engine'
  service[server_crt]='engine'
  service[tgbot_api_main]='tgbot'
  service[tgbot_api_dockerfile]='tgbot'
  service[tgbot_bot_main]='tgbot'
  service[tgbot_bot_dockerfile]='tgbot'
  service[tgbot_helper_main]='tgbot'
  service[tgbot_helper_dockerfile]='tgbot'
  service[tgbot_compose]='tgbot'
  service[subscriptions]='none'
  service[subscription_api_main]='subscription-api'
  service[subscription_api_gomod]='subscription-api'
  service[subscription_api_dockerfile]='subscription-api'

  for key in "${!path[@]}"; do
    md5["$key"]=$(get_md5 "${path[$key]}")
  done
}

function tune_kernel {
  local mem_kb
  local file_max
  local somaxconn
  local syn_backlog
  local conntrack_max
  mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  if (( mem_kb < 1048576 )); then
    file_max=100000
    somaxconn=2048
    syn_backlog=4096
    conntrack_max=262144
  elif (( mem_kb < 4194304 )); then
    file_max=200000
    somaxconn=4096
    syn_backlog=8192
    conntrack_max=524288
  else
    file_max=400000
    somaxconn=8192
    syn_backlog=16384
    conntrack_max=1048576
  fi
  cat >/etc/sysctl.d/99-reality-ezpz.conf <<EOF
fs.file-max = ${file_max}
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = ${somaxconn}
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.netfilter.nf_conntrack_max=${conntrack_max}
EOF
  sysctl -qp /etc/sysctl.d/99-reality-ezpz.conf >/dev/null 2>&1 || true
}

function configure_docker {
  local docker_config="/etc/docker/daemon.json"
  local config_modified=false
  local temp_file
  temp_file=$(mktemp)
  if [[ ! -f "${docker_config}" ]] || [[ ! -s "${docker_config}" ]]; then
    echo '{"experimental": true, "ip6tables": true}' | jq . > "${docker_config}"
    config_modified=true
  else
    if ! jq . "${docker_config}" &> /dev/null; then
      echo '{"experimental": true, "ip6tables": true}' | jq . > "${docker_config}"
      config_modified=true
    else
      if jq 'if .experimental != true or .ip6tables != true then .experimental = true | .ip6tables = true else . end' "${docker_config}" | jq . > "${temp_file}"; then
        if ! cmp --silent "${docker_config}" "${temp_file}"; then
          mv "${temp_file}" "${docker_config}"
          config_modified=true
        fi
      fi
    fi
  fi
  rm -f "${temp_file}"
  if [[ "${config_modified}" = true ]] || ! systemctl is-active --quiet docker; then
    sudo systemctl restart docker || true
  fi
}

parse_args "$@" || show_help
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi
generate_file_list
install_packages
if [[ ${args[backup]} == true ]]; then
  if [[ -z ${args[backup_password]} ]]; then
    echo "Backup password is required with --backup-password." >&2
    exit 1
  fi
  backup_upload=false
  if [[ ${args[backup_upload_temp]} == true ]]; then
    backup_upload=true
  fi
  if backup_result=$(backup "${args[backup_password]}" "${backup_upload}"); then
    if [[ "${backup_upload}" == true ]]; then
      echo "Encrypted backup uploaded successfully."
      echo "${backup_result}"
      echo "The URL is valid for 3 days."
    else
      echo "Encrypted backup created successfully at:"
      echo "${backup_result}"
    fi
    exit 0
  fi
  exit 1
fi
if [[ -n ${args[restore]} ]]; then
  if [[ -z ${args[backup_password]} ]]; then
    echo "Backup password is required with --backup-password." >&2
    exit 1
  fi
  if restore "${args[restore]}" "${args[backup_password]}"; then
    args[restart]=true
    echo "Backup has been restored successfully."
  fi
  echo "Press Enter to continue ..."
  read -r
  clear
fi
install_docker
configure_docker
upgrade
parse_config_file
parse_users_file
build_config
update_config_file
update_users_file
tune_kernel

if [[ ${args[menu]} == 'true' ]]; then
  set +e
  main_menu
  set -e
fi
if [[ ${args[restart]} == 'true' ]]; then
  restart_docker_compose
  if [[ ${config[tgbot]} == 'ON' ]]; then
    restart_tgbot_compose
  fi
fi
if [[ -z "$(${docker_cmd} ls | grep "${path[compose]}" | grep running || true)" ]]; then
  restart_docker_compose
fi
if [[ -z "$(${docker_cmd} ls | grep "${path[tgbot_compose]}" | grep running || true)" && ${config[tgbot]} == 'ON' ]]; then
  restart_tgbot_compose
fi
if [[ ${args[server-config]} == true ]]; then
  show_server_config
  exit 0
fi
if [[ -n ${args[show_subscription]} ]]; then
  username="${args[show_subscription]}"
  if [[ -z "${users["${username}"]}" ]]; then
    echo "User \"${username}\" does not exist."
    exit 1
  fi
  if [[ ${config[subscriptions]} != 'ON' ]]; then
    echo "Subscription feature is disabled. Enable with --enable-subscriptions true"
    exit 1
  fi
  show_subscription_url "${username}"
  exit 0
fi
if [[ -n ${args[rotate_subscription]} ]]; then
  username="${args[rotate_subscription]}"
  if [[ -z "${users["${username}"]}" ]]; then
    echo "User \"${username}\" does not exist."
    exit 1
  fi
  if [[ ${config[subscriptions]} != 'ON' ]]; then
    echo "Subscription feature is disabled. Enable with --enable-subscriptions true"
    exit 1
  fi
  new_token=$(rotate_subscription_token "${username}")
  _sub_path="${config[subscription_path]:-sub}"
  _host="${config[server]}"
  _port="${config[port]}"
  if [[ "${_port}" != "443" ]]; then
    _host="${_host}:${_port}"
  fi
  echo "New subscription URL for ${username}:"
  echo "https://${_host}/${_sub_path}/${new_token}"
  exit 0
fi
if [[ -n ${args[list_users]} ]]; then
  for user in "${!users[@]}"; do
    echo "${user}"
  done
  exit 0
fi
if [[ ${#users[@]} -eq 1 ]]; then
  for user in "${!users[@]}"; do
    username="${user}"
  done
fi
if [[ -n ${args[show_config]} ]]; then
  username="${args[show_config]}"
  if [[ -z "${users["${username}"]}" ]]; then
    echo "User \"${username}\" does not exist."
    exit 1
  fi
fi
if [[ -n ${args[add_user]} ]]; then
  username="${args[add_user]}"
fi
if [[ -n $username ]]; then
  print_client_configuration "${username}"
fi
echo "Command has been executed successfully!"
exit 0
