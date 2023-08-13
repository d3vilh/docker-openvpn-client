FROM arm64v8/alpine
#FROM amd64/alpine
#FROM arm32v6/alpine
LABEL maintainer="Mr.Philipp <d3vilh@github.com>"

# Install openvpn
RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash bind-tools curl ip6tables iptables openvpn \
                shadow tini tzdata && \
    addgroup -S vpn && \
    rm -rf /tmp/*

COPY . /usr/local/bin

ENV KILL_SWITCH=on

HEALTHCHECK --interval=60s --timeout=15s --start-period=120s \
             CMD curl -LSs 'https://api.ipify.org'

ENTRYPOINT [ "docker-entrypoint.sh" ]
