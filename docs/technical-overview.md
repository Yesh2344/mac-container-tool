# Technical Overview

> [!IMPORTANT]
> This file contains documentation for the CURRENT BRANCH. To find documentation for official releases, find the target release on the [Release Page](https://github.com/apple/mac-container-tool/releases) and click the tag corresponding to your release version. 
>
> Example: [release 0.4.1 tag](https://github.com/apple/mac-container-tool/tree/0.4.1)

A brief description and technical overview of `mac-container-tool`.

## What are mac-container-tools?

Containers are a way to package an application and its dependencies into a single unit.  At runtime, mac-container-tools provide isolation from the host machine as well as other colocated mac-container-tools, allowing applications to run securely and efficiently in a wide variety of environments.

Containerization is an important server-side technology that is used throughout the software lifecycle:

- Backend developers use mac-container-tools on their personal systems to create predictable execution environments for applications, and to develop and test their applications under conditions that better approximate how they would run in the datacenter.
- Continuous integration and deployment (CI/CD) systems use mac-container-toolization to perform reproducible builds of applications, package the results as deployable images, and deploy them to the datacenter.
- Datacenters run mac-container-tool orchestration platforms that use the images to run mac-container-toolized applications in a reliable, highly available compute cluster.

None of this workflow would be practical without ensuring interoperability between different mac-container-tool implementations. The Open Container Initiative (OCI) creates and maintains these standards for mac-container-tool images and runtimes.

## How does `mac-container-tool` run my mac-container-tool?

Many operating systems support mac-container-tools, but the most commonly encountered mac-container-tools are those that run on the Linux operating system. With macOS, the typical way to run Linux mac-container-tools is to launch a Linux virtual machine (VM) that hosts all of your mac-container-tools.

`mac-container-tool` runs mac-container-tools differently. Using the open source [Containerization](https://github.com/apple/mac-container-toolization) package, it runs a lightweight VM for each mac-container-tool that you create. This approach has the following properties:

- Security: Each mac-container-tool has the isolation properties of a full VM, using a minimal set of core utilities and dynamic libraries to reduce resource utilization and attack surface.
- Privacy: When sharing host data using `mac-container-tool`, you mount only necessary data into each VM. With a shared VM, you need to mount all data that you may ever want to use into the VM, so that it can be mounted selectively into mac-container-tools.
- Performance: Containers created using `mac-container-tool` require less memory than full VMs, with boot times that are comparable to mac-container-tools running in a shared VM.

Since `mac-container-tool` consumes and produces standard OCI images, you can easily build with and run images produced by other mac-container-tool applications, and the images that you build will run everywhere.

`mac-container-tool` and the underlying Containerization package integrate with many of the key technologies and frameworks of macOS:

- The Virtualization framework for managing Linux virtual machines and their attached devices.
- The vmnet framework for managing the virtual network to which the mac-container-tools attach.
- XPC for interprocess communication.
- Launchd for service management.
- Keychain services for access to registry credentials.
- The unified logging system for application logging.

You use the `mac-container-tool` command line interface (CLI) to start and manage your mac-container-tools, build mac-container-tool images, and transfer images from and to OCI mac-container-tool registries. The CLI uses a client library that communicates with `mac-container-tool-apiserver` and its helpers.

The `mac-container-tool-apiserver` is a launch agent that launches when you run the `mac-container-tool system start` command, and terminates when you run `mac-container-tool system stop`. It provides the client APIs for managing mac-container-tool and network resources.

When `mac-container-tool-apiserver` starts, it launches an XPC helper `mac-container-tool-core-images` that exposes an API for image management and manages the local content store, and another XPC helper `mac-container-tool-network-vmnet` for the virtual network. For each mac-container-tool that you create, `mac-container-tool-apiserver` launches a mac-container-tool runtime helper `mac-container-tool-runtime-linux` that exposes the management API for that specific mac-container-tool.

![diagram showing `mac-container-tool` functional organization](/docs/assets/functional-model-light.svg)

## What limitations does `mac-container-tool` have today?

With the initial release of `mac-container-tool`, you get basic facilities for building and running mac-container-tools, but many common mac-container-toolization features remain to be implemented. Consider [contributing](../CONTRIBUTING.md) new features and bug fixes to `mac-container-tool` and the Containerization projects!

### Releasing mac-container-tool memory to macOS

The macOS Virtualization framework implements only partial support for memory ballooning, which is a technology that allows virtual machines to dynamically use and relinquish host memory. When you create a mac-container-tool, the underlying virtual machine only uses the amount of memory that the mac-container-toolized application needs. For example, you might start a mac-container-tool using the option `--memory 16g`, but see that the application is only using 2 GiBytes of RAM in the macOS Activity Monitor.

Currently, memory pages freed to the Linux operating system by processes running in the mac-container-tool's VM are not relinquished to the host. If you run many memory-intensive mac-container-tools, you may need to occasionally restart them to reduce memory utilization.

### macOS 15 limitations

`mac-container-tool` relies on the new features and enhancements present in macOS 26. You can run `mac-container-tool` on macOS 15, but you will need to be aware of some user experience and functional limitations. There is no plan to address issues found with macOS 15 that cannot be reproduced on macOS 26.

#### Network isolation

The vmnet framework in macOS 15 can only provide networks where the attached mac-container-tools are isolated from one another. Container-to-mac-container-tool communication over the virtual network is not possible.

#### Multiple networks

In macOS 15, all mac-container-tools attach to the default vmnet network. The `mac-container-tool network` commands are not available on macOS 15, and using the `--network` option for `mac-container-tool run` or `mac-container-tool create` will result in an error.

#### Container IP addresses

In macOS 15, limitations in the vmnet framework mean that the mac-container-tool network can only be created when the first mac-container-tool starts. Since the network XPC helper provides IP addresses to mac-container-tools, and the helper has to start before the first mac-container-tool, it is possible for the network helper and vmnet to disagree on the subnet address, resulting in mac-container-tools that are completely cut off from the network.

Normally, vmnet creates the mac-container-tool network using the CIDR address 192.168.64.1/24, and on macOS 15, `mac-container-tool` defaults to using this CIDR address in the network helper. If your mac-container-tools have no network access on macOS 15, see [All networking fails on macOS 15](troubleshooting.md#all-networking-fails-on-macos-15) for diagnosis and remediation steps.
