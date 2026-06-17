//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc. and the mac-container-tool project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import ArgumentParser
import ContainerAPIClient
import ContainerAPIService
import ContainerLog
import ContainerPersistence
import ContainerPlugin
import ContainerResource
import ContainerXPC
import ContainerizationExtras
import DNSServer
import Foundation
import Logging
import SystemPackage

extension APIServer {
    struct Start: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start helper for the API server"
        )

        static let listenAddress = "127.0.0.1"
        static let localhostDNSPort = 1053
        static let dnsPort = 2053

        @Flag(name: .long, help: "Enable debug logging")
        var debug = false

        var appRoot = ApplicationRoot.path

        var installRoot = InstallRoot.path

        var logRoot = LogRoot.path

        func run() async throws {
            let mac-container-toolSystemConfig: ContainerSystemConfig = try await ConfigurationLoader.load()
            let commandName = APIServer._commandName
            let logPath = logRoot.map { $0.appending(FilePath.Component("\(commandName).log") ?? "unknown") }
            let log = ServiceLogger.bootstrap(category: "APIServer", debug: debug, logPath: logPath)
            log.info("starting helper", metadata: ["name": "\(commandName)"])
            defer {
                log.info("stopping helper", metadata: ["name": "\(commandName)"])
            }

            do {
                log.info("configuring XPC server")
                var routes = [XPCRoute: XPCServer.RouteHandler]()
                let pluginLoader = try initializePluginLoader(log: log)

                try await initializePlugins(pluginLoader: pluginLoader, log: log, routes: &routes, debug: debug)
                let mac-container-toolsService = try initializeContainersService(
                    pluginLoader: pluginLoader,
                    mac-container-toolSystemConfig: mac-container-toolSystemConfig,
                    log: log,
                    routes: &routes
                )
                let networkService = try await initializeNetworksService(
                    pluginLoader: pluginLoader,
                    mac-container-toolsService: mac-container-toolsService,
                    mac-container-toolSystemConfig: mac-container-toolSystemConfig,
                    log: log,
                    routes: &routes
                )
                await mac-container-toolsService.setNetworksService(networkService)
                initializeHealthCheckService(log: log, routes: &routes)
                try initializeKernelService(log: log, routes: &routes)
                let volumesService = try await initializeVolumeService(mac-container-toolsService: mac-container-toolsService, log: log, routes: &routes)
                try initializeDiskUsageService(
                    mac-container-toolsService: mac-container-toolsService,
                    volumesService: volumesService,
                    log: log,
                    routes: &routes
                )

                let server = XPCServer(
                    identifier: "com.apple.mac-container-tool.apiserver",
                    routes: routes.reduce(
                        into: [String: XPCServer.RouteHandler](),
                        {
                            $0[$1.key.rawValue] = $1.value
                        }), log: log)

                await withTaskGroup(of: Result<Void, Error>.self) { group in
                    group.addTask {
                        log.info("starting XPC server")
                        do {
                            try await server.listen()
                            return .success(())
                        } catch {
                            return .failure(error)
                        }
                    }

                    // start up host table DNS
                    group.addTask {
                        let hostsResolver = ContainerDNSHandler(networkService: networkService)
                        let nxDomainResolver = NxDomainResolver()
                        let compositeResolver = CompositeResolver(handlers: [hostsResolver, nxDomainResolver])
                        let hostsQueryValidator = StandardQueryValidator(handler: compositeResolver)
                        let dnsServer: DNSServer = DNSServer(handler: hostsQueryValidator, log: log)
                        log.info(
                            "starting DNS resolver for mac-container-tool hostnames",
                            metadata: [
                                "host": "\(Self.listenAddress)",
                                "port": "\(Self.dnsPort)",
                            ]
                        )
                        do {
                            try await dnsServer.run(host: Self.listenAddress, port: Self.dnsPort)
                            return .success(())
                        } catch {
                            return .failure(error)
                        }

                    }

                    // start up realhost DNS
                    group.addTask {
                        do {
                            let localhostResolver = LocalhostDNSHandler(log: log)
                            await localhostResolver.monitorResolvers()

                            let nxDomainResolver = NxDomainResolver()
                            let compositeResolver = CompositeResolver(handlers: [localhostResolver, nxDomainResolver])
                            let hostsQueryValidator = StandardQueryValidator(handler: compositeResolver)
                            let dnsServer: DNSServer = DNSServer(handler: hostsQueryValidator, log: log)
                            log.info(
                                "starting DNS resolver for localhost",
                                metadata: [
                                    "host": "\(Self.listenAddress)",
                                    "port": "\(Self.localhostDNSPort)",
                                ]
                            )
                            try await dnsServer.run(host: Self.listenAddress, port: Self.localhostDNSPort)
                            return .success(())
                        } catch {
                            return .failure(error)
                        }
                    }

                    for await result in group {
                        switch result {
                        case .success():
                            continue
                        case .failure(let error):
                            log.error("API server task failed: \(error)")
                        }
                    }
                }
            } catch {
                log.error(
                    "helper failed",
                    metadata: [
                        "name": "\(commandName)",
                        "error": "\(error)",
                    ])
                APIServer.exit(withError: error)
            }
        }

        private func initializePluginLoader(log: Logger) throws -> PluginLoader {
            log.info(
                "initializing plugin loader",
                metadata: [
                    "installRoot": "\(installRoot.string)"
                ])

            // TODO: Remove when we convert PluginLoader to FilePath
            let installRootURL = URL(fileURLWithPath: installRoot.string)
            let pluginsURL = PluginLoader.userPluginsDir(installRoot: installRootURL)
            log.info("detecting user plugins directory", metadata: ["path": "\(pluginsURL.path(percentEncoded: false))"])
            var directoryExists: ObjCBool = false
            _ = FileManager.default.fileExists(atPath: pluginsURL.path, isDirectory: &directoryExists)
            let userPluginsURL = directoryExists.boolValue ? pluginsURL : nil

            // plugins built into the application installed as a Unix-like application
            let installRootPluginsPath =
                installRoot
                .appending(FilePath.Component("libexec"))
                .appending(FilePath.Component("mac-container-tool"))
                .appending(FilePath.Component("plugins"))
            let installRootPluginsURL = URL(fileURLWithPath: installRootPluginsPath.string)

            let pluginDirectories = [
                userPluginsURL,
                installRootPluginsURL,
            ].compactMap { $0 }

            let pluginFactories: [PluginFactory] = [
                DefaultPluginFactory(logger: log),
                AppBundlePluginFactory(logger: log),
            ]

            for pluginDirectory in pluginDirectories {
                log.info("discovered plugin directory", metadata: ["path": "\(pluginDirectory.path(percentEncoded: false))"])
            }

            let appRootURL = URL(fileURLWithPath: appRoot.string)
            return try PluginLoader(
                appRoot: appRootURL,
                installRoot: installRootURL,
                logRoot: logRoot,
                pluginDirectories: pluginDirectories,
                pluginFactories: pluginFactories,
                log: log
            )
        }

        // First load all of the plugins we can find. Then just expose
        // the handlers for clients to do whatever they want.
        private func initializePlugins(
            pluginLoader: PluginLoader,
            log: Logger,
            routes: inout [XPCRoute: XPCServer.RouteHandler],
            debug: Bool = false
        ) async throws {
            log.info("initializing plugins")

            let bootPlugins = pluginLoader.findPlugins().filter { $0.shouldBoot }

            let service = PluginsService(pluginLoader: pluginLoader, log: log)
            try await service.loadAll(bootPlugins, debug: debug)

            let harness = PluginsHarness(service: service, log: log)
            routes[XPCRoute.pluginGet] = XPCServer.route(harness.get)
            routes[XPCRoute.pluginList] = XPCServer.route(harness.list)
            routes[XPCRoute.pluginLoad] = XPCServer.route(harness.load)
            routes[XPCRoute.pluginUnload] = XPCServer.route(harness.unload)
            routes[XPCRoute.pluginRestart] = XPCServer.route(harness.restart)
        }

        private func initializeHealthCheckService(log: Logger, routes: inout [XPCRoute: XPCServer.RouteHandler]) {
            log.info("initializing health check service")

            // TODO: Remove when we convert HealthCheckHarness to FilePath
            let installRootURL = URL(fileURLWithPath: installRoot.string)
            let appRootURL = URL(fileURLWithPath: appRoot.string)
            let svc = HealthCheckHarness(
                appRoot: appRootURL,
                installRoot: installRootURL,
                logRoot: logRoot,
                log: log
            )
            routes[XPCRoute.ping] = XPCServer.route(svc.ping)
        }

        private func initializeKernelService(log: Logger, routes: inout [XPCRoute: XPCServer.RouteHandler]) throws {
            log.info("initializing kernel service")

            // TODO: Remove when we convert KernelService to FilePath
            let appRootURL = URL(fileURLWithPath: appRoot.string)
            let svc = try KernelService(log: log, appRoot: appRootURL)
            let harness = KernelHarness(service: svc, log: log)
            routes[XPCRoute.installKernel] = XPCServer.route(harness.install)
            routes[XPCRoute.getDefaultKernel] = XPCServer.route(harness.getDefaultKernel)
        }

        private func initializeContainersService(
            pluginLoader: PluginLoader,
            mac-container-toolSystemConfig: ContainerSystemConfig,
            log: Logger,
            routes: inout [XPCRoute: XPCServer.RouteHandler]
        ) throws -> ContainersService {
            log.info("initializing mac-container-tools service")

            // TODO: Remove when we convert ContainersService to FilePath
            let appRootURL = URL(fileURLWithPath: appRoot.string)
            let service = try ContainersService(
                appRoot: appRootURL,
                pluginLoader: pluginLoader,
                mac-container-toolSystemConfig: mac-container-toolSystemConfig,
                log: log,
                debugHelpers: debug
            )
            let harness = ContainersHarness(service: service, log: log)

            routes[XPCRoute.mac-container-toolList] = XPCServer.route(harness.list)
            routes[XPCRoute.mac-container-toolCreate] = XPCServer.route(harness.create)
            routes[XPCRoute.mac-container-toolDelete] = XPCServer.route(harness.delete)
            routes[XPCRoute.mac-container-toolLogs] = XPCServer.route(harness.logs)
            routes[XPCRoute.mac-container-toolBootstrap] = XPCServer.route(harness.bootstrap)
            routes[XPCRoute.mac-container-toolDial] = XPCServer.route(harness.dial)
            routes[XPCRoute.mac-container-toolStop] = XPCServer.route(harness.stop)
            routes[XPCRoute.mac-container-toolStartProcess] = XPCServer.route(harness.startProcess)
            routes[XPCRoute.mac-container-toolCreateProcess] = XPCServer.route(harness.createProcess)
            routes[XPCRoute.mac-container-toolResize] = XPCServer.route(harness.resize)
            routes[XPCRoute.mac-container-toolWait] = XPCServer.route(harness.wait)
            routes[XPCRoute.mac-container-toolKill] = XPCServer.route(harness.kill)
            routes[XPCRoute.mac-container-toolStats] = XPCServer.route(harness.stats)
            routes[XPCRoute.mac-container-toolDiskUsage] = XPCServer.route(harness.diskUsage)
            routes[XPCRoute.mac-container-toolCopyIn] = XPCServer.route(harness.copyIn)
            routes[XPCRoute.mac-container-toolCopyOut] = XPCServer.route(harness.copyOut)
            routes[XPCRoute.mac-container-toolExport] = XPCServer.route(harness.export)

            return service
        }

        private func initializeNetworksService(
            pluginLoader: PluginLoader,
            mac-container-toolsService: ContainersService,
            mac-container-toolSystemConfig: ContainerSystemConfig,
            log: Logger,
            routes: inout [XPCRoute: XPCServer.RouteHandler]
        ) async throws -> NetworksService {
            log.info("initializing networks service")

            let resourceRoot = appRoot.appending(FilePath.Component("networks"))
            let defaultNetworkConfig = try NetworkConfiguration(
                name: NetworkClient.defaultNetworkName,
                mode: .nat,
                ipv4Subnet: mac-container-toolSystemConfig.network.subnet,
                ipv6Subnet: mac-container-toolSystemConfig.network.subnetv6,
                labels: try .init([ResourceLabelKeys.role: ResourceRoleValues.builtin]),
                plugin: "mac-container-tool-network-vmnet"
            )
            let service = try await NetworksService(
                pluginLoader: pluginLoader,
                resourceRoot: resourceRoot,
                mac-container-toolsService: mac-container-toolsService,
                defaultNetworkConfiguration: defaultNetworkConfig,
                log: log,
                debugHelpers: debug
            )

            let defaultNetwork = try await service.list()
                .filter { $0.isBuiltin }
                .first
            if defaultNetwork == nil {
                // FIXME: default network should be configurable elsewhere
                _ = try await service.create(configuration: defaultNetworkConfig)
            }

            let harness = NetworksHarness(service: service, log: log)

            if #available(macOS 26, *) {
                routes[XPCRoute.networkCreate] = XPCServer.route(harness.create)
            }
            routes[XPCRoute.networkList] = XPCServer.route(harness.list)
            routes[XPCRoute.networkDelete] = XPCServer.route(harness.delete)

            return service
        }

        private func initializeVolumeService(
            mac-container-toolsService: ContainersService,
            log: Logger,
            routes: inout [XPCRoute: XPCServer.RouteHandler]
        ) async throws -> VolumesService {
            log.info("initializing volume service")

            let resourceRoot = appRoot.appending(FilePath.Component("volumes"))
            let service = try await VolumesService(resourceRoot: resourceRoot, mac-container-toolsService: mac-container-toolsService, log: log)
            let harness = VolumesHarness(service: service, log: log)

            routes[XPCRoute.volumeCreate] = XPCServer.route(harness.create)
            routes[XPCRoute.volumeDelete] = XPCServer.route(harness.delete)
            routes[XPCRoute.volumeList] = XPCServer.route(harness.list)
            routes[XPCRoute.volumeInspect] = XPCServer.route(harness.inspect)
            routes[XPCRoute.volumeDiskUsage] = XPCServer.route(harness.diskUsage)

            return service
        }

        private func initializeDiskUsageService(
            mac-container-toolsService: ContainersService,
            volumesService: VolumesService,
            log: Logger,
            routes: inout [XPCRoute: XPCServer.RouteHandler]
        ) throws {
            log.info("initializing disk usage service")

            let service = DiskUsageService(
                mac-container-toolsService: mac-container-toolsService,
                volumesService: volumesService,
                log: log
            )
            let harness = DiskUsageHarness(service: service, log: log)

            routes[XPCRoute.systemDiskUsage] = XPCServer.route(harness.get)
        }
    }
}
