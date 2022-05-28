# forwardproxy-quickstart

A simple installation script for caddyserver with forward proxy plugin.

This script will help you install the caddy binary to `/usr/bin`, a template for server configuration to `/etc/caddy`, and (if applicable) a systemd service to `/etc/systemd/system`.
## Usage

- via `curl`
    ```
    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/willoong9559/forwardproxy-quickstart/master/quickstart.sh)"
    ```
- via `wget`
    ```
    sudo bash -c "$(wget -O- https://raw.githubusercontent.com/willoong9559/forwardproxy-quickstart/master/quickstart.sh)"
    ```
