#!/bin/bash
# Bothered alltogeather with killswitch.sh from Wyatt Gill <wfg@github.com>

set -o errexit
set -o nounset
set -o pipefail

echo "Allowed subnets: $ALLOWED_SUBNETS"
echo "Auth Secret: $AUTH_SECRET"
echo "Config file: $CONFIG_FILE"
echo "Kill switch: $KILL_SWITCH"
echo "DBG: pwd"
pwd
echo "DBG: ls -lrt /config"
ls -lrt /config
echo "DBG: run find /config -name $CONFIG_FILE"
find /config -name "$CONFIG_FILE" 2> /dev/null

if [[ -z "${1:-}" ]]; then
#  ALLOWED_SUBNETS="10.0.60.0/24,192.168.88.0/24"
  AUTH_SECRET=''
else
#  ALLOWED_SUBNETS="$1"
  AUTH_SECRET="$2"
fi

default_gateway=$(ip -4 route | awk '$1 == "default" { print $3 }')
#for subnet in ${ALLOWED_SUBNETS//,/ }; do
#    echo "adding iptables rules for $subnet"
#    iptables --insert OUTPUT --destination "$subnet" --jump ACCEPT
#    echo "adding routes $subnet"
#    ip route add "$subnet" via "$default_gateway"
#done

# If the user has mounted a custom configuration file, use that instead.
cleanup() {
    kill TERM "$openvpn_pid"
    exit 0
}
# Check if a variable is set to true.
is_enabled() {
    [[ ${1,,} =~ ^(true|t|yes|y|1|on|enable|enabled)$ ]]
}

# If a pattern is given, then exact file will be selected.
if [[ ${CONFIG_FILE:-} ]]; then
    echo "DBG:1"
    config_file=$(find /config -name "$CONFIG_FILE" 2> /dev/null)
fi

# If a pattern is not given, a random file will be selected.
if [[ -z ${CONFIG_FILE:-} ]]; then
    echo "DBG:2"
    config_file=$(find /config -name '*.conf' -o -name '*.ovpn' 2> /dev/null | sort | shuf -n 1)
else
    echo "DBG:3"
    config_file=$(find /config -name "$CONFIG_FILE" 2> /dev/null | sort | shuf -n 1)
fi

echo "Following config_file choosen:"
echo $config_file

if [[ -z $config_file ]]; then
    echo "no openvpn configuration file found" >&2
    exit 1
fi

# If the user has mounted a custom configuration file, use that instead.
echo "using openvpn configuration file: $config_file"

openvpn_args=(
    "--config" "$config_file"
    "--cd" "/config"
)

# If the user has mounted a custom killswitch script, use that instead.
if is_enabled "$KILL_SWITCH"; then
echo "killswitch enabled"
echo "passing $ALLOWED_SUBNETS to killswitch.sh"
    openvpn_args+=("--route-up" "/usr/local/bin/killswitch.sh $ALLOWED_SUBNETS")
fi

# If the user has mounted a custom credentials file (Docker secret), use that instead.
if [[ $AUTH_SECRET ]]; then
echo "using auth secret: $AUTH_SECRET"
    openvpn_args+=("--auth-user-pass" "/run/secrets/$AUTH_SECRET")
fi

openvpn "${openvpn_args[@]}" &
openvpn_pid=$!

# Wait for the OpenVPN process to exit.
trap cleanup TERM
wait $openvpn_pid