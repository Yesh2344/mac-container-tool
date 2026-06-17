# Copyright © 2025-2026 Apple Inc. and the mac-container-tool project authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Version and build configuration variables
BUILD_CONFIGURATION ?= debug
WARNINGS_AS_ERRORS ?= true
SWIFT_CONFIGURATION := $(if $(filter-out false,$(WARNINGS_AS_ERRORS)),-Xswiftc -warnings-as-errors)
export RELEASE_VERSION ?= $(shell git describe --tags --always)
export GIT_COMMIT := $(shell git rev-parse HEAD)

# Commonly used locations
SWIFT := "/usr/bin/swift"
DEST_DIR ?= /usr/local/
ROOT_DIR := $(shell git rev-parse --show-toplevel)
BUILD_BIN_DIR = $(shell $(SWIFT) build -c $(BUILD_CONFIGURATION) --show-bin-path)
STAGING_DIR := bin/$(BUILD_CONFIGURATION)/staging/
PKG_PATH := bin/$(BUILD_CONFIGURATION)/mac-container-tool-installer-unsigned.pkg
DSYM_DIR := bin/$(BUILD_CONFIGURATION)/bundle/mac-container-tool-dSYM
DSYM_PATH := bin/$(BUILD_CONFIGURATION)/bundle/mac-container-tool-dSYM.zip
CODESIGN_OPTS ?= --force --sign - --timestamp=none


# Conditionally use a temporary data directory for integration tests
SYSTEM_START_OPTS :=
ifneq ($(strip $(APP_ROOT)),)
	SYSTEM_START_OPTS += --app-root "$(strip $(APP_ROOT))"
endif
ifneq ($(strip $(LOG_ROOT)),)
	SYSTEM_START_OPTS += --log-root "$(strip $(LOG_ROOT))"
endif

MACOS_VERSION := $(shell sw_vers -productVersion)
MACOS_MAJOR := $(shell echo $(MACOS_VERSION) | cut -d. -f1)

SUDO ?= sudo
.DEFAULT_GOAL := all

include Protobuf.Makefile

.PHONY: all
all: mac-container-tool
all: init-block

.PHONY: build
build:
	@echo Building mac-container-tool binaries...
	@$(SWIFT) --version
	@$(SWIFT) build -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION)

.PHONY: cli
cli:
	@echo Building mac-container-tool CLI...
	@$(SWIFT) --version
	@$(SWIFT) build -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION) --product mac-container-tool
	@echo Installing mac-container-tool CLI to bin/...
	@mkdir -p bin
	@install "$(BUILD_BIN_DIR)/mac-container-tool" "bin/mac-container-tool"

.PHONY: mac-container-tool
# Install binaries under project directory
mac-container-tool: build
	@"$(MAKE)" BUILD_CONFIGURATION=$(BUILD_CONFIGURATION) DEST_DIR="$(ROOT_DIR)/" SUDO= install

.PHONY: release
release: BUILD_CONFIGURATION = release
release: all

.PHONY: init-block
init-block:
	@echo Building initfs if mac-container-toolization is in edit mode
	@scripts/install-init.sh $(SYSTEM_START_OPTS)

.PHONY: install
install: installer-pkg
	@echo Installing mac-container-tool installer package
	@if [ -z "$(SUDO)" ] ; then \
		temp_dir=$$(mktemp -d) ; \
		xar -xf $(PKG_PATH) -C $${temp_dir} ; \
		(cd "$(DEST_DIR)" && pax -rz -f $${temp_dir}/Payload) ; \
		rm -rf $${temp_dir} ; \
	else \
		$(SUDO) installer -pkg $(PKG_PATH) -target / ; \
	fi

$(STAGING_DIR):
	@echo Installing mac-container-tool binaries from "$(BUILD_BIN_DIR)" into "$(STAGING_DIR)"...
	@rm -rf "$(STAGING_DIR)"
	@mkdir -p "$(join $(STAGING_DIR), bin)"
	@mkdir -p "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-runtime-linux/bin)"
	@mkdir -p "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-network-vmnet/bin)"
	@mkdir -p "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-core-images/bin)"
	@mkdir -p "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/bin)"
	@mkdir -p "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/resources)"

	@install "$(BUILD_BIN_DIR)/mac-container-tool" "$(join $(STAGING_DIR), bin/mac-container-tool)"
	@install "$(BUILD_BIN_DIR)/mac-container-tool-apiserver" "$(join $(STAGING_DIR), bin/mac-container-tool-apiserver)"
	@install "$(BUILD_BIN_DIR)/mac-container-tool-runtime-linux" "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-runtime-linux/bin/mac-container-tool-runtime-linux)"
	@install Sources/Plugins/RuntimeLinux/config.toml "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-runtime-linux/config.toml)"
	@install "$(BUILD_BIN_DIR)/mac-container-tool-network-vmnet" "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-network-vmnet/bin/mac-container-tool-network-vmnet)"
	@install Sources/Plugins/NetworkVmnet/config.toml "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-network-vmnet/config.toml)"
	@install "$(BUILD_BIN_DIR)/mac-container-tool-core-images" "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-core-images/bin/mac-container-tool-core-images)"
	@install Sources/Plugins/CoreImages/config.toml "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-core-images/config.toml)"
	@install "$(BUILD_BIN_DIR)/machine-apiserver" "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/bin/machine-apiserver)"
	@install Sources/Plugins/MachineAPIServer/config.toml "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/config.toml)"
	@install Sources/Plugins/MachineAPIServer/Resources/init "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/resources/init)"
	@install Sources/Plugins/MachineAPIServer/Resources/create-user.sh "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/resources/create-user.sh)"

	@echo Install update script
	@install scripts/update-mac-container-tool.sh "$(join $(STAGING_DIR), bin/update-mac-container-tool.sh)"
	@echo Install uninstaller script
	@install scripts/uninstall-mac-container-tool.sh "$(join $(STAGING_DIR), bin/uninstall-mac-container-tool.sh)"

.PHONY: installer-pkg
installer-pkg: $(STAGING_DIR)
	@echo Signing mac-container-tool binaries...
	@codesign $(CODESIGN_OPTS) --identifier com.apple.mac-container-tool.cli "$(join $(STAGING_DIR), bin/mac-container-tool)"
	@codesign $(CODESIGN_OPTS) --identifier com.apple.mac-container-tool.apiserver "$(join $(STAGING_DIR), bin/mac-container-tool-apiserver)"
	@codesign $(CODESIGN_OPTS) --prefix=com.apple.mac-container-tool. "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-core-images/bin/mac-container-tool-core-images)"
	@codesign $(CODESIGN_OPTS) --prefix=com.apple.mac-container-tool. --entitlements=signing/mac-container-tool-runtime-linux.entitlements "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-runtime-linux/bin/mac-container-tool-runtime-linux)"
	@codesign $(CODESIGN_OPTS) --prefix=com.apple.mac-container-tool. --entitlements=signing/mac-container-tool-network-vmnet.entitlements "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/mac-container-tool-network-vmnet/bin/mac-container-tool-network-vmnet)"
	@codesign $(CODESIGN_OPTS) --prefix=com.apple.mac-container-tool. "$(join $(STAGING_DIR), libexec/mac-container-tool/plugins/machine-apiserver/bin/machine-apiserver)"

	@echo Creating application installer
	@pkgbuild --root "$(STAGING_DIR)" --identifier com.apple.mac-container-tool-installer --install-location /usr/local --version ${RELEASE_VERSION} $(PKG_PATH)
	@rm -rf "$(STAGING_DIR)"

.PHONY: dsym
dsym:
	@echo Copying debug symbols...
	@rm -rf "$(DSYM_DIR)"
	@mkdir -p "$(DSYM_DIR)"
	@cp -a "$(BUILD_BIN_DIR)/mac-container-tool-runtime-linux.dSYM" "$(DSYM_DIR)"
	@cp -a "$(BUILD_BIN_DIR)/mac-container-tool-network-vmnet.dSYM" "$(DSYM_DIR)"
	@cp -a "$(BUILD_BIN_DIR)/mac-container-tool-core-images.dSYM" "$(DSYM_DIR)"
	@cp -a "$(BUILD_BIN_DIR)/mac-container-tool-apiserver.dSYM" "$(DSYM_DIR)"
	@cp -a "$(BUILD_BIN_DIR)/mac-container-tool.dSYM" "$(DSYM_DIR)"

	@echo Packaging the debug symbols...
	@(cd "$(dir $(DSYM_DIR))" ; zip -r $(notdir $(DSYM_PATH)) $(notdir $(DSYM_DIR)))

.PHONY: test
test:
	@$(SWIFT) test -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION) --skip TestCLI

.PHONY: install-kernel
install-kernel:
	@echo Stopping system before installing kernel
	@bin/mac-container-tool system stop || true
	@echo Starting system to install kernel
	@bin/mac-container-tool --debug system start --timeout 60 --enable-kernel-install $(SYSTEM_START_OPTS)


# Coverage report generation helpers
# Directory that swift test spits out raw coverage data
COV_DATA_DIR = $(shell $(SWIFT) test --show-coverage-path | xargs dirname)
COV_REPORT_FILE = $(ROOT_DIR)/code-coverage-report
COVERAGE_OUTPUT_DIR := $(ROOT_DIR)/coverage-reports
TEST_BINARY = $(BUILD_BIN_DIR)/mac-container-toolPackageTests.xctest/Contents/MacOS/mac-container-toolPackageTests
# Set of files we do not want to get caught in the coverage generation
LLVM_COV_IGNORE := \
	--ignore-filename-regex=".build/" \
	--ignore-filename-regex=".pb.swift" \
	--ignore-filename-regex=".proto" \
	--ignore-filename-regex=".grpc.swift"

# Generate JSON + HTML coverage reports and a coverage-percent.txt from a profdata file.
# $(1) = profdata path, $(2) = tier name (unit/integration/combined)
define GENERATE_COV_REPORTS
	@echo Exporting $(2) coverage JSON...
	@xcrun llvm-cov export --compilation-dir=`pwd` \
		-instr-profile=$(1) \
		$(LLVM_COV_IGNORE) \
		$(TEST_BINARY) > $(COVERAGE_OUTPUT_DIR)/$(2)/coverage-summary.json
	@echo Generating $(2) coverage HTML report...
	@xcrun llvm-cov show --compilation-dir=`pwd` --format=html \
		-instr-profile=$(1) \
		$(LLVM_COV_IGNORE) \
		-output-dir=$(COVERAGE_OUTPUT_DIR)/$(2)/html \
		$(TEST_BINARY)
	@echo Extracting $(2) coverage percentages...
	@jq -r '"line coverage: \(.data[0].totals.lines.percent | . * 100 | round | . / 100)%\nfunction coverage: \(.data[0].totals.functions.percent | . * 100 | round | . / 100)%"' \
		$(COVERAGE_OUTPUT_DIR)/$(2)/coverage-summary.json > $(COVERAGE_OUTPUT_DIR)/$(2)/coverage-percent.txt
	@cat $(COVERAGE_OUTPUT_DIR)/$(2)/coverage-percent.txt
endef

INTEGRATION_TEST_SUITES ?= \
	TestCLIHelp \
	TestCLIStatus \
	TestCLIVersion \
	TestCLINetwork \
	TestCLIRunLifecycle \
	TestCLIRunCapabilities \
	TestCLIExecCommand \
	TestCLICreateCommand \
	TestCLIRunCommand1 \
	TestCLIRunCommand2 \
	TestCLIRunCommand3 \
	TestCLIPruneCommand \
	TestCLIRegistry \
	TestCLIStatsCommand \
	TestCLIImagesCommand \
	TestCLIRunBase \
	TestCLIRunInitImage \
	TestCLIBuildBase \
	TestCLIExportCommand \
	TestCLIVolumes \
	TestCLIKernelSet \
	TestCLIAnonymousVolumes \
	TestCLINotFound \
	TestCLISystemDF \
	TestCLIMachineCommand \
	TestCLIMachineRuntime \
	TestCLINoParallelCases

empty :=
space := $(empty) $(empty)
INTEGRATION_FILTER := $(subst $(space),|,$(strip $(INTEGRATION_TEST_SUITES)))

.PHONY: coverage-build
coverage-build:
	@echo Building tests with coverage instrumentation...
	@$(SWIFT) build --build-tests --enable-code-coverage -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION)

.PHONY: coverage
# Merge the raw coverage data generated from coverage-unit and coverage-integration into one unified report
coverage: coverage-build coverage-unit coverage-integration
	@echo Merging combined coverage profdata...
	@mkdir -p $(COVERAGE_OUTPUT_DIR)/combined
	@xcrun llvm-profdata merge -sparse \
		$(COVERAGE_OUTPUT_DIR)/unit/default.profdata \
		$(COVERAGE_OUTPUT_DIR)/integration/default.profdata \
		-o $(COVERAGE_OUTPUT_DIR)/combined/default.profdata
	$(call GENERATE_COV_REPORTS,$(COVERAGE_OUTPUT_DIR)/combined/default.profdata,combined)

.PHONY: coverage-unit
coverage-unit:
	@echo Running unit test coverage...
	@rm -f $(COV_DATA_DIR)/*.profraw
	@mkdir -p $(COVERAGE_OUTPUT_DIR)/unit
	@$(SWIFT) test --skip-build --enable-code-coverage -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION) --skip TestCLI
	@echo Merging unit coverage profdata...
	@xcrun llvm-profdata merge -sparse $(COV_DATA_DIR)/*.profraw -o $(COVERAGE_OUTPUT_DIR)/unit/default.profdata
	$(call GENERATE_COV_REPORTS,$(COVERAGE_OUTPUT_DIR)/unit/default.profdata,unit)

.PHONY: coverage-integration
coverage-integration: all
	@echo Ensuring apiserver stopped before the coverage integration tests...
	@bin/mac-container-tool system stop && sleep 3 && scripts/ensure-mac-container-tool-stopped.sh
	@echo Running integration test coverage...
	@rm -f $(COV_DATA_DIR)/*.profraw
	@mkdir -p $(COVERAGE_OUTPUT_DIR)/integration
	@bin/mac-container-tool --debug system start --timeout 60 $(SYSTEM_START_OPTS) && \
	echo "Starting CLI integration tests with coverage" && \
	{ \
		export CLITEST_LOG_ROOT=$(LOG_ROOT) ; \
		export CONTAINER_CLI_PATH=$(ROOT_DIR)/bin/mac-container-tool ; \
		$(SWIFT) test --skip-build --enable-code-coverage -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION) --filter "$(INTEGRATION_FILTER)" ; \
		exit_code=$$? ; \
		cp $(COV_DATA_DIR)/*.profraw $(COVERAGE_OUTPUT_DIR)/integration/ ; \
		echo Ensuring apiserver stopped after the coverage integration tests ; \
		scripts/ensure-mac-container-tool-stopped.sh ; \
		exit $${exit_code} ; \
	}
	@echo Merging integration coverage profdata...
	@xcrun llvm-profdata merge -sparse $(COVERAGE_OUTPUT_DIR)/integration/*.profraw -o $(COVERAGE_OUTPUT_DIR)/integration/default.profdata
	$(call GENERATE_COV_REPORTS,$(COVERAGE_OUTPUT_DIR)/integration/default.profdata,integration)

.PHONY: integration
integration: init-block
	@echo Ensuring apiserver stopped before the CLI integration tests...
	@bin/mac-container-tool system stop && sleep 3 && scripts/ensure-mac-container-tool-stopped.sh
	@if [ -n "$(APP_ROOT)" ]; then \
		echo "Clearing application data under $(APP_ROOT) (preserving kernels)..." ; \
		mkdir -p $(APP_ROOT) ; \
		find "$(APP_ROOT)" -mindepth 1 -maxdepth 1 ! -name kernels -exec rm -rf {} + ; \
	fi
	@echo Running the integration tests...
	@bin/mac-container-tool --debug system start --timeout 60 --enable-kernel-install $(SYSTEM_START_OPTS) && \
	echo "Starting CLI integration tests" && \
	{ \
		CLITEST_LOG_ROOT=$(LOG_ROOT) && export CLITEST_LOG_ROOT ; \
		CONTAINER_CLI_PATH=$(ROOT_DIR)/bin/mac-container-tool && export CONTAINER_CLI_PATH ; \
		$(SWIFT) test -c $(BUILD_CONFIGURATION) $(SWIFT_CONFIGURATION) --filter "$(INTEGRATION_FILTER)" ; \
		exit_code=$$? ; \
		echo Ensuring apiserver stopped after the CLI integration tests ; \
		scripts/ensure-mac-container-tool-stopped.sh ; \
		exit $${exit_code} ; \
	}

.PHONY: fmt
fmt: swift-fmt update-licenses

.PHONY: check
check: swift-fmt-check check-licenses

.PHONY: swift-fmt
SWIFT_SRC = $(shell find . -type f -name '*.swift' -not -path "*/.*" -not -path "*.pb.swift" -not -path "*.grpc.swift" -not -path "*/checkouts/*")
swift-fmt:
	@echo Applying the standard code formatting...
	@$(SWIFT) format --recursive --configuration .swift-format -i $(SWIFT_SRC)

swift-fmt-check:
	@echo Applying the standard code formatting...
	@$(SWIFT) format lint --recursive --strict --configuration .swift-format-nolint $(SWIFT_SRC)

.PHONY: update-licenses
update-licenses:
	@echo Updating license headers...
	@./scripts/ensure-hawkeye-exists.sh
	@.local/bin/hawkeye format --fail-if-unknown --fail-if-updated false

.PHONY: check-licenses
check-licenses:
	@echo Checking license headers existence in source files...
	@./scripts/ensure-hawkeye-exists.sh
	@.local/bin/hawkeye check --fail-if-unknown

.PHONY: pre-commit
pre-commit:
	$(eval HOOKS_DIR := $(shell git rev-parse --git-path hooks))
	cp scripts/pre-commit.fmt $(HOOKS_DIR)/
	touch $(HOOKS_DIR)/pre-commit
	cat $(HOOKS_DIR)/pre-commit | grep -v 'hooks/pre-commit\.fmt' > /tmp/pre-commit.new || true
	echo 'PRECOMMIT_NOFMT=$${PRECOMMIT_NOFMT} $$(git rev-parse --git-path hooks/pre-commit.fmt)' >> /tmp/pre-commit.new
	mv /tmp/pre-commit.new $(HOOKS_DIR)/pre-commit
	chmod +x $(HOOKS_DIR)/pre-commit
	@./scripts/ensure-hawkeye-exists.sh

.PHONY: serve-docs
serve-docs:
	@echo 'to browse: open http://127.0.0.1:8000/mac-container-tool/documentation/'
	@rm -rf _serve
	@mkdir -p _serve
	@cp -a _site _serve/mac-container-tool
	@python3 -m http.server --bind 127.0.0.1 --directory ./_serve

.PHONY: docs
docs:
	@echo Updating API documentation...
	@rm -rf _site
	@scripts/make-docs.sh _site mac-container-tool

.PHONY: cleancontent
cleancontent:
	@bin/mac-container-tool system stop || true
	@echo Cleaning the content...
	@rm -rf ~/Library/Application\ Support/com.apple.mac-container-tool

.PHONY: clean
clean:
	@echo Cleaning build files...
	@rm -rf bin/ libexec/
	@rm -rf _site _serve
	@rm -f $(COV_REPORT_FILE)
	@rm -rf $(COVERAGE_OUTPUT_DIR)
	@$(SWIFT) package clean
