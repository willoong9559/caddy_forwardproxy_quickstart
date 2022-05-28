#!/bin/bash
set -euo pipefail

function prompt() {
    while true; do
        read -p "$1 [y/N] " yn
        case $yn in
            [Yy] ) return 0;;
            [Nn]|"" ) return 1;;
        esac
    done
}

if [[ $(id -u) != 0 ]]; then
    echo Please run this script as root.
    exit 1
fi

if ! command -v go &> /dev/null; then
    echo Please install the latest version of Go.
    exit 1
fi

NAME=caddy
TMPDIR="$(mktemp -d)"
INSTALLPREFIX=/usr
CONFIGPREFIX=/etc/caddy
SYSTEMDPREFIX=/etc/systemd/system

BINARYPATH="$INSTALLPREFIX/bin/$NAME"
CONFIGPATH="/etc/$NAME/Caddyfile"
SYSTEMDPATH="$SYSTEMDPREFIX/$NAME.service"

echo Entering temp directory $TMPDIR...
cd "$TMPDIR"

echo Building Caddy with forwardproxy plugins...
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest || exit 1
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2 || exit 1

echo Installing $NAME to $BINARYPATH...
install -Dm755 "$NAME" "$BINARYPATH" || exit 1

if ! [[ -d "$CONFIGPREFIX" ]]; then
    mkdir -p /etc/$NAME/ || exit 1
fi
if ! [[ -f "$CONFIGPATH" ]] || prompt "The server config already exists in $CONFIGPATH, overwrite?"; then
    cat > "$CONFIGPATH" << EOF
{
  servers {
    protocol {
      experimental_http3
    }
  }
}
:443, example.com
tls me@example.com
route {
  forward_proxy {
    basic_auth user pass
    hide_ip
    hide_via
    probe_resistance
  }
  file_server {
    root /var/www/html
  }
}
EOF
else
    echo Skipping installing $NAME server config...
fi

echo Creating unique Linux group and user for caddy...
if grep -q $NAME /etc/group; then
    echo "Group $NAME exists in /etc/group"
else
    groupadd --system $NAME
fi
if grep -q $NAME /etc/passwd; then
    echo "User $NAME exists in /etc/passwd"
else
    useradd --system \
        --gid $NAME \
    	--create-home \
	    --home-dir /var/lib/$NAME \
	    --shell /usr/sbin/nologin \
	    --comment "$NAME web server" \
        $NAME
fi

if [[ -d "$SYSTEMDPREFIX" ]]; then
    echo Installing $NAME systemd service to $SYSTEMDPATH...
    if ! [[ -f "$SYSTEMDPATH" ]] || prompt "The systemd service already exists in $SYSTEMDPATH, overwrite?"; then
        cat > "$SYSTEMDPATH" << EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

        echo Reloading systemd daemon...
        systemctl daemon-reload
    else
        echo Skipping installing $NAME systemd service...
    fi
fi

echo Deleting temp directory $TMPDIR...
rm -rf "$TMPDIR"

echo Done!
