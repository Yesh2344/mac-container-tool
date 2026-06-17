# Customize `mac-container-tool` default configuration values

> [!IMPORTANT]
> This file contains documentation for the CURRENT BRANCH. To find documentation for official releases, find the target release on the [Release Page](https://github.com/apple/mac-container-tool/releases) and click the tag corresponding to your release version.
>
> Example: [release 0.4.1 tag](https://github.com/apple/mac-container-tool/tree/0.4.1)

Take a guided tour of setting configurations for `mac-container-tool` CLI commands and services.

## Configuration sources

The `mac-container-tool` service loads values from these TOML files at startup, with first-match-wins precedence:

1. Your user file at `~/.config/mac-container-tool/config.toml`.
2. An optional file shipped with the `mac-container-tool` package install at `<installRoot>/etc/mac-container-tool/config.toml`.

Any key absent from both files falls back to a hardcoded default. For the full schema and defaults, see the [`config.toml` reference](../mac-container-tool-system-config.md).

## Create a custom user TOML configuration file

The `mac-container-tool` service reads your file once at startup, so restart the service whenever you want changes to take effect.

### Open or create your config file

Your editable config lives at `~/.config/mac-container-tool/config.toml`. Create it if it does not exist:

```bash
mkdir -p ~/.config/mac-container-tool
touch ~/.config/mac-container-tool/config.toml
```

### Set the values you want to customize

Open the file in the editor of your choice and add only the sections and keys you want to change. 

For this tutorial, increase the default CPU and memory limits used for each new mac-container-tool and set a DNS domain for resolving mac-container-tool IP addresses from the host. 

```toml
[mac-container-tool]
cpus = 8
memory = "4g"

[dns]
domain = "test"
```

Each top-level table maps directly to a section of [ContainerSystemConfig](../mac-container-tool-system-config.md). 

### Restart the `mac-container-tool` service

To make your edits take effect, stop and start the system:

```bash
mac-container-tool system stop
mac-container-tool system start
```

### Verify the values are loaded

Use `mac-container-tool system property list` (alias `ls`) to print the merged configuration that the `mac-container-tool` service is using. 

```console
% mac-container-tool system property list
[build]
cpus = 2
memory = "2048mb"
rosetta = true
image = "ghcr.io/apple/mac-container-tool-builder-shim/builder:0.11.0"

[mac-container-tool]
cpus = 8
memory = "4gb"

[dns]
domain = "test"

[kernel]
binaryPath = "opt/kata/share/kata-mac-container-tools/vmlinux-6.18.15-186"
url = "https://github.com/kata-mac-container-tools/kata-mac-container-tools/releases/download/3.28.0/kata-static-3.28.0-arm64.tar.zst"

[network]

[registry]
domain = "docker.io"

[vminit]
image = "ghcr.io/apple/mac-container-toolization/vminit:0.32.2"
```

For machine-readable output, pass `--format json`:

```bash
mac-container-tool system property list --format json
```
