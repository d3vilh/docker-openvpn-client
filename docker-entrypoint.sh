#!/usr/bin/env bash
# Bothered alltogeather with killswitch.sh from Wyatt Gill <wfg@github.com> 
set -o errexit
set -o nounset
set -o pipefail

# If the user has mounted a custom configuration file, use that instead.
cleanup() {
    kill TERM "$openvpn_pid"
    exit 0
}
# Check if a variable is set to true.
is_enabled() {
    [[ ${1,,} =~ ^(true|t|yes|y|1|on|enable|enabled)$ ]]
}

# If a pattern is given, a random file will be selected.
if [[ $CONFIG_FILE ]]; then
    config_file=$(find /config -name "$CONFIG_FILE" 2> /dev/null | sort | shuf -n 1)
else
    config_file=$(find /config -name '*.conf' -o -name '*.ovpn' 2> /dev/null | sort | shuf -n 1)
fi

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
    openvpn_args+=("--route-up" "/usr/local/bin/killswitch.sh $ALLOWED_SUBNETS")
fi

# If the user has mounted a custom credentials file (Docker secret), use that instead.
if [[ $AUTH_SECRET ]]; then
    openvpn_args+=("--auth-user-pass" "/run/secrets/$AUTH_SECRET")
fi

openvpn "${openvpn_args[@]}" &
openvpn_pid=$!

# Wait for the OpenVPN process to exit.
trap cleanup TERM
wait $openvpn_pid
