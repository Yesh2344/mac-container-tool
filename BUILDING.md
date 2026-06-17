# Building the project

To build the `mac-container-tool` project, you need:

- Mac with Apple silicon
- macOS 15 minimum, macOS 26 recommended
- Xcode 26, set as the [active developer directory](https://developer.apple.com/library/archive/technotes/tn2339/_index.html#//apple_ref/doc/uid/DTS40014588-CH1-HOW_DO_I_SELECT_THE_DEFAULT_VERSION_OF_XCODE_TO_USE_FOR_MY_COMMAND_LINE_TOOLS_)

> [!IMPORTANT]
> There is a bug in the `vmnet` framework on macOS 26 that causes network creation to fail if the `mac-container-tool` helper applications are located under your `Documents` or `Desktop` directories. If you use `make install`, you can simply run the `mac-container-tool` binary in `/usr/local`. If you prefer to use the binaries that `make all` creates in your project `bin` and `libexec` directories, locate your project elsewhere, such as `~/projects/mac-container-tool`, until this issue is resolved.

## Compile and test

Build `mac-container-tool` and the background services from source, and run basic and integration tests in an isolated application data directory:

```bash
rm -rf test-data
make APP_ROOT=test-data all test integration
```

Copy the binaries to `/usr/local/bin` and `/usr/local/libexec` (requires entering an administrator password):

```bash
make install
```

Or to install a release build, with better performance than the debug build:

```bash
BUILD_CONFIGURATION=release make all test integration
BUILD_CONFIGURATION=release make install
```

## Compile protobufs

`mac-container-tool` uses gRPC to communicate to the builder virtual machine that creates images from `Dockerfile`s, and depends on specific versions of `grpc-swift` and `swift-protobuf`. If you make changes to the gRPC APIs in the [mac-container-tool-builder-shim](https://github.com/apple/mac-container-tool-builder-shim) project, install the tools and re-generate the gRPC code in this project using:

```bash
make protos
```

## Develop using a local copy of Containerization

To make changes to `mac-container-tool` that require changes to the Containerization project, or vice versa:

1. Clone the [Containerization](https://github.com/apple/mac-container-toolization) repository such that it sits next to your clone
of the `mac-container-tool` repository. Ensure that you [follow mac-container-toolization instructions](https://github.com/apple/mac-container-toolization/blob/main/README.md#prepare-to-build-package)
to prepare your build environment.

2. In your development shell, go to the `mac-container-tool` project directory.

    ```bash
    cd mac-container-tool
    ```

3. If the `mac-container-tool` services are already running, stop them.

    ```bash
    bin/mac-container-tool system stop
    ```

4. Reconfigure the Swift project to use your local `mac-container-toolization` package and update your `Package.resolved` file.

    ```bash
    /usr/bin/swift package edit --path ../mac-container-toolization mac-container-toolization
    /usr/bin/swift package update mac-container-toolization
    ```

    > [!IMPORTANT]
    > If you are using Xcode, do **not** run `swift package edit`. Instead, temporarily modify `Package.swift` to replace the versioned `mac-container-toolization` dependency:
    >
    > ```swift
    > .package(url: "https://github.com/apple/mac-container-toolization.git", exact: Version(stringLiteral: scVersion)),
    > ```
    >
    > with the local path dependency:
    >
    > ```swift
    > .package(path: "../mac-container-toolization"),
    > ```
    >
    > **Note:** If you have already run `swift package edit`, whether intentionally or by accident, follow the steps in the next section to restore the normal `mac-container-toolization` dependency. Otherwise, the modified `Package.swift` file will not work, and the project may fail to build.

5. If you want `mac-container-tool` to use any changes you made in the `vminit` subproject of Containerization, set the init image in your runtime configuration file at `~/.config/mac-container-tool/config.toml`:

    ```toml
    [vminit]
    image = "vminit:latest"
    ```

6. Build `mac-container-tool`.

    ```
    make clean all
    ```

7. Restart the `mac-container-tool` services.

    ```
    bin/mac-container-tool system stop
    bin/mac-container-tool system start
    ```

To revert to using the Containerization dependency from your `Package.swift`:

1. If you were using the local init filesystem, remove the `init` override from your `~/.config/mac-container-tool/config.toml` (or delete the `[vminit]` section if no other image settings are present).

2. Use the Swift package manager to restore the normal `mac-container-toolization` dependency and update your `Package.resolved` file. If you are using Xcode, revert your `Package.swift` change instead of using `swift package unedit`.

    ```bash
    /usr/bin/swift package unedit mac-container-toolization
    /usr/bin/swift package update mac-container-toolization
    ```

3. Rebuild `mac-container-tool`.

    ```bash
    make clean all
    ```

4. Restart the `mac-container-tool` services.

    ```bash
    bin/mac-container-tool system stop
    bin/mac-container-tool system start
    ```

## Develop using a local copy of mac-container-tool-builder-shim

To test changes that require the `mac-container-tool-builder-shim` project:

1. Clone the [mac-container-tool-builder-shim](https://github.com/apple/mac-container-tool-builder-shim) repository and navigate to its directory.

2. After making the necessary changes, build the custom builder image, set it as the active builder image in `~/.config/mac-container-tool/config.toml`, and remove the existing `buildkit` mac-container-tool so the new image will be used:

```bash
mac-container-tool build -t builder .
mac-container-tool rm -f buildkit
```

Add the following to your `~/.config/mac-container-tool/config.toml`:

```toml
[build]
image = "builder:latest"
```

3. Run the `mac-container-tool` build as usual:

```bash
mac-container-tool build ...
```

> [!IMPORTANT]
> If your modified builder image is broken, make sure to rebuild and correctly tag the builder image before attempting to build `mac-container-tool-builder-shim` again.

## Debug XPC Helpers

Attach debugger to the XPC helpers using their launchd service labels:

1. Find launchd service labels:

   ```console
   % mac-container-tool system start
   % mac-container-tool run -d --name test debian:bookworm sleep infinity
   test
   % launchctl list | grep mac-container-tool
   27068   0       com.apple.mac-container-tool.mac-container-tool-network-vmnet.default
   27072   0       com.apple.mac-container-tool.mac-container-tool-core-images
   26980   0       com.apple.mac-container-tool.apiserver
   27331   0       com.apple.mac-container-tool.mac-container-tool-runtime-linux.test
   ```

2. Stop mac-container-tool and start again after setting the environment variable `CONTAINER_DEBUG_LAUNCHD_LABEL` to the label of service to attach debugger. Services whose label starts with the `CONTAINER_DEBUG_LAUNCHD_LABEL` will wait the debugger:

    ```console
    % export CONTAINER_DEBUG_LAUNCHD_LABEL=com.apple.mac-container-tool.mac-container-tool-runtime-linux.test
    % mac-container-tool system start # Only the service `com.apple.mac-container-tool.mac-container-tool-runtime-linux.test` waits debugger
    ```

    ```console
    % export CONTAINER_DEBUG_LAUNCHD_LABEL=com.apple.mac-container-tool.mac-container-tool-runtime-linux
    % mac-container-tool system start # Every service starting with `com.apple.mac-container-tool.mac-container-tool-runtime-linux` waits debugger
    ```

3. Run the command to launch the service, and attach debugger:

    ```console
    % mac-container-tool run -it --name test debian:bookworm
    ⠧ [6/6] Starting mac-container-tool [0s] # It hangs as the service is waiting for debugger
    ```

## Pre-commit hook

Run `make pre-commit` to install a pre-commit hook that ensures that your changes have correct formatting and license headers when you run `git commit`.
