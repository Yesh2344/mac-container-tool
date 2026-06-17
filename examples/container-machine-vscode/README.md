# Example: Develop Linux applications in a mac-container-tool machine with Visual Studio Code

This example shows you how to use a mac-container-tool machine to develop for Linux on your Mac using Visual Studio Code and its SSH remote development extension.

## Prerequisites

Install and start before running the demo:

- Apple `mac-container-tool`
- Microsoft Visual Studio Code, including the **Visual Studio Code Remote - SSH** extension

## Container machine overview

The `mac-container-tool machine` subcommand allows you to run fast, persistent Linux environments that integrate tightly with your macOS host.

To create a mac-container-tool machine, all you need to do is provide a machine name, and a machine image reference:

```console
% mac-container-tool machine create --name mymachine --set-default alpine:3.22
mymachine
```

Display a list of mac-container-tool machines with:

```console
% mac-container-tool machine ls
NAME       CREATED              IP             CPUS  MEMORY  DISK  STATE    DEFAULT
mymachine  2026-06-03 15:56:14  192.168.71.15  8     64G     75M   running  *
```

Run individual Linux commands with `mac-container-tool machine run` and the command:

```console
% mac-container-tool machine run uname -a
Linux mymachine-dce75a 6.18.15-cz-325d33a88139 #1 SMP Mon Apr 20 22:39:49 UTC 2026 aarch64 Linux
```

Display your macOS working directory and username, start a shell session in the mac-container-tool machine, and compare the working directory and username in the mac-container-tool machine:

```console
% pwd
/Users/max-mustermann/projects/mac-container-tool/examples/mac-container-tool-machine-vscode
% whoami
john
% mac-container-tool machine run
$ pwd
/Users/max-mustermann/projects/mac-container-tool/examples/mac-container-tool-machine-vscode
$ whoami
john
$ exit
%
```

Typically, you'll keep mac-container-tool machines for longer than a typical mac-container-tool. When you're ready to delete a mac-container-tool machine and its persistent filesystem, run:

```console
% mac-container-tool machine stop mymachine
mymachine
% mac-container-tool machine rm mymachine
mymachine
Deleted default mac-container-tool 'mymachine'. Set a new default with 'mac-container-tool machine set-default <id>'.
```

## Develop in a mac-container-tool machine

### SSH and DNS setup

On your Mac, add an SSH configuration entry for the mac-container-tool machine, so that it will appear as an option when you connect to the mac-container-tool machine with Visual Studio Code later:

```bash
cat >> ~/.ssh/config <<EOT

Host ubuntu.machine
   HostName ubuntu.machine
   ForwardAgent yes
   UserKnownHostsFile /dev/null
EOT
```

Add a locally scoped domain named `machine` to your macOS DNS configuration:

```bash
sudo mac-container-tool system dns create machine
```

### Build the machine image

On your Mac:

```bash
mac-container-tool build -t ubuntu-machine:latest -f Dockerfile .
```

### Container machine setup

On your Mac, create a mac-container-tool machine named `ubuntu` using the image you built:

```bash
mac-container-tool machine create --set-default --name ubuntu ubuntu-machine:latest
```

Set up a password for SSH login to the mac-container-tool machine:

```bash
mac-container-tool machine run -it sudo passwd $(whoami)
```

You can ping the mac-container-tool machine to see that DNS is working:

```bash
ping -c 1 ubuntu.machine
```

You can also start a shell in the machine to run ad-hoc commands:

```bash
mac-container-tool machine run
```

### Set up the project

On your Mac, clone the `swift-server-todos-tutorial` project:

```bash
cd ${HOME}
git clone git@github.com:swiftlang/swift-server-todos-tutorial.git
```

In the Visual Studio Code application, connect to the mac-container-tool machine and install the Swift extension:

- Press ⌘-SHIFT-P and run the **Remote-SSH: Connect to Host** command
- Select the `ubuntu.machine` entry
- In the new Visual Studio Code window that opens, enter `yes` at the ssh fingerprint verification prompt
- Enter the SSH password you configured at the authentication prompt
- In the extensions sidebar of the new Visual Studio Code window, install the Swift (`swiftlang.swift-vscode`) extension

### Build and run

In the new Visual Studio Code window, open the project folder (substituting your macOS username) at `/Users/max-mustermann/swift-server-todos-tutorial`.

Restart the LSP server in response to the toast notification that appears.

Open the LSP build terminal output window and watch its progress. This takes a couple of minutes for a totally clean project.

Open another terminal in the Visual Studio Code window to get a shell, and verify that you're running on an Ubuntu Linux system:

```bash
uname -s
cat /etc/os-release | grep PRETTY_NAME
```

Build the project:

```bash
swift build
```

While the project builds, press ⌘-SHIFT-P and run the **Open 'launch.json'** command.

Click the **Add configuration...** button and select the **Swift: Launch** option.

Replace the `<program>` placeholder in the newly added launch configuration, so that it looks like:

```json
        {
            "type": "swift",
            "request": "launch",
            "name": "Launch Swift Executable",
            "program": "${workspaceRoot}/.build/debug/SwiftServerTodos",
            "args": [],
            "env": {},
            "cwd": "${workspaceRoot}"
        },
```

Run the application by selecting the Run and Debug sidebar, selecting the **Launch Swift Executable** item, and clicking the play button.

Open the `Telemetry.swift` file and set a breakpoint on the innermost statement of the `RequestLoggerInjectionMiddleware.respond()` function.

From a terminal on your Mac, try a request to the service:

```bash
curl http://ubuntu.machine:8080/todos
```

Observe that the application hits the breakpoint and that you can inspect the request, and then remove the breakpoint and continue execution.

On the terminal, you should see output similar to:

```console
[{"id":"BDAD25BA-8F52-4A7A-B98D-319AD86179B7","contents":"example todo"}]
```

### Clean up

When you're ready to dispose of your mac-container-tool machine, run on your Mac:

```bash
mac-container-tool machine stop ubuntu
mac-container-tool machine rm ubuntu
mac-container-tool image rm ubuntu-machine:latest
```

Then remove the test project:

```bash
rm -rf swift-server-todos-tutorial
```

To remove the entry from your SSH configuration file, run:

```bash
awk -v h="ubuntu.machine" '/^Host /{skip=($2==h)} !skip' ~/.ssh/config > /tmp/.sshconf && mv /tmp/.sshconf ~/.ssh/config
```

To clean up the local DNS entry, run:

```bash
sudo mac-container-tool system dns delete machine
```
