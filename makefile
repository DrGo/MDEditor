# Makefile for MDEditor Swift Package

# Variables
SWIFT := swift
PACKAGE_NAME := MDEditor
# Determine the build configuration, default to debug
BUILD_CONFIG ?= debug -q
BUILD_DIR := .build/$(BUILD_CONFIG)

# The name of your .xctest bundle can sometimes vary.
# For a package named MDEditor and a test target MDEditorTests,
# Xcode/SwiftPM often creates MDEditorPackageTests.xctest.
# Adjust TEST_PRODUCT_NAME if your .xctest bundle is named differently (e.g., MDEditorTests.xctest).
TEST_PRODUCT_NAME := $(PACKAGE_NAME)PackageTests
TEST_EXECUTABLE_PATH := $(BUILD_DIR)/$(TEST_PRODUCT_NAME).xctest

# On macOS, the actual executable is inside the .xctest bundle
# For Linux, this path structure would be different (typically just the test executable name in BUILD_DIR)
ifeq ($(shell uname -s),Darwin)
    TEST_EXECUTABLE := $(TEST_EXECUTABLE_PATH)/Contents/MacOS/$(TEST_PRODUCT_NAME)
else
    # For Linux, swift test creates an executable with the name of your test target directly
    TEST_EXECUTABLE := $(BUILD_DIR)/MDEditorTests
endif

# MODIFIED: Changed to use default.profdata as observed from user's output
PROFDATA_FILE := $(BUILD_DIR)/codecov/default.profdata
LCOV_FILE := coverage.lcov
HTML_REPORT_DIR := coverage_html

# Phony targets are not files
.PHONY: all test coverage coverage-report coverage-html clean help

all: test

help:
	echo "Makefile for MDEditor Swift Package"
	echo ""
	echo "Usage: make [target]"
	echo ""
	echo "Targets:"
	echo "  all                  Alias for 'make test'."
	echo "  test                 Runs the Swift package tests."
	echo "  coverage             Runs tests and enables code coverage data generation."
	echo "  coverage-report      Generates and displays a code coverage summary report in the terminal."
	echo "                       (Assumes 'make coverage' has been run)."
	echo "  coverage-html        Generates an HTML code coverage report in '$(HTML_REPORT_DIR)'."
	echo "                       (Assumes 'make coverage' has been run. Requires 'lcov' and 'genhtml')."
	echo "  clean                Removes build artifacts, .profdata, .lcov, and HTML coverage reports."
	echo "  help                 Shows this help message."
	echo ""
	echo "Variables:"
	echo "  BUILD_CONFIG         Set the build configuration (default: debug). Example: make test BUILD_CONFIG=release"
	echo "  TEST_PRODUCT_NAME    Set the test product name (default: $(PACKAGE_NAME)PackageTests). Adjust if your .xctest bundle name differs."

buildonly: 
	@$(SWIFT) build --quiet 2>&1 | grep -E ":\d+:\d+: (error|warning):" | sed 's|.*/||'

build:
	@$(SWIFT) build --quiet 2>&1 | grep -E ":\d+:\d+: (error|warning):" | sed 's|.*/||' | tee /dev/tty | pbcopy

testbuild:
	@$(SWIFT) test --quiet 2>&1 | grep -E ":\d+:\d+: (error|warning):" | sed 's|.*/||' | tee /dev/tty | pbcopy

test:
	$(SWIFT) test --skip-build --build-path .build --configuration $(BUILD_CONFIG)

# Target to run tests with coverage enabled
coverage:
	echo "📊 Running tests with code coverage for $(PACKAGE_NAME)..."
	$(SWIFT) test --enable-code-coverage --build-path .build --configuration $(BUILD_CONFIG)
	echo "🔍 Verifying coverage data generation at $(PROFDATA_FILE)..."
	if [ -f "$(PROFDATA_FILE)" ]; then \
		echo "✅ Coverage data successfully verified at: $(PROFDATA_FILE)"; \
	else \
		echo "❌ Error: Coverage data NOT found at $(PROFDATA_FILE) immediately after generation attempt."; \
		echo "   Build directory for coverage: $(BUILD_DIR)/codecov/"; \
		echo "   Contents of $(BUILD_DIR)/codecov/:"; \
		ls -la "$(BUILD_DIR)/codecov/"; \
		echo "   Please check if 'swift test --enable-code-coverage' produced the .profdata file as expected (e.g., as 'default.profdata')."; \
		exit 1; \
	fi

# Target to generate and display a coverage report summary
coverage-report: coverage
	echo "📝 Generating coverage summary report..."
	if [ ! -f "$(PROFDATA_FILE)" ]; then \
		echo "❌ Error: $(PROFDATA_FILE) not found. Run 'make coverage' first (or it failed to produce the file)."; \
		exit 1; \
	fi
	if [ ! -e "$(TEST_EXECUTABLE)" ]; then \
		echo "❌ Error: Test executable not found at $(TEST_EXECUTABLE)."; \
		echo "   This might be due to a different test product name or build issues."; \
		echo "   Check the TEST_PRODUCT_NAME variable in the Makefile or the path in .build/$(BUILD_CONFIG)/"; \
		exit 1; \
	fi
	echo "Displaying coverage for: $(TEST_EXECUTABLE)"
	xcrun llvm-cov report \
		"$(TEST_EXECUTABLE)" \
		-instr-profile="$(PROFDATA_FILE)" \
		-ignore-filename-regex="\.build|Tests|Yams|swift-markdown" \
		-use-color

# Target to generate an HTML coverage report
coverage-html: coverage
	echo "📄 Generating HTML coverage report..."
	if [ ! -f "$(PROFDATA_FILE)" ]; then \
		echo "❌ Error: $(PROFDATA_FILE) not found. Run 'make coverage' first (or it failed to produce the file)."; \
		exit 1; \
	fi
	if [ ! -e "$(TEST_EXECUTABLE)" ]; then \
		echo "❌ Error: Test executable not found at $(TEST_EXECUTABLE)."; \
		echo "   Check the TEST_PRODUCT_NAME variable in the Makefile or the path in .build/$(BUILD_CONFIG)/"; \
		exit 1; \
	fi
	echo "Exporting LCOV data for: $(TEST_EXECUTABLE)"
	xcrun llvm-cov export \
		"$(TEST_EXECUTABLE)" \
		-instr-profile="$(PROFDATA_FILE)" \
		-ignore-filename-regex="\.build|Tests|Yams|swift-markdown" \
		-format=lcov > "$(LCOV_FILE)"
	echo "📊 LCOV data saved to $(LCOV_FILE)"
	echo "🛠️ Generating HTML report from $(LCOV_FILE)..."
	if ! command -v genhtml &> /dev/null; then \
		echo "⚠️ 'genhtml' command not found. 'lcov' package might be missing."; \
		echo "   On macOS, try: brew install lcov"; \
		echo "   Skipping HTML report generation."; \
	else \
		genhtml "$(LCOV_FILE)" --output-directory "$(HTML_REPORT_DIR)"; \
		echo "✅ HTML report generated in $(HTML_REPORT_DIR)/index.html"; \
		echo "   Run 'open $(HTML_REPORT_DIR)/index.html' to view."; \
	fi

# Target to clean build artifacts and coverage files
clean:
	echo "🧹 Cleaning build artifacts and coverage data..."
	rm -rf .build
	rm -f "$(LCOV_FILE)"
	rm -rf "$(HTML_REPORT_DIR)"
	echo "✅ Clean complete."


