APP_NAME = Can I Open
BUNDLE_ID = com.canIOpen.app
EXECUTABLE = CanIOpen
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
VERSION = 0.1.1

# The standalone Command Line Tools currently ship a macOS 27 SDK whose
# SwiftUI macros are unavailable to `swift build`. Prefer the compatible
# 26.5 SDK when it is installed; full Xcode toolchains use their default SDK.
CLT_PATH = /Library/Developer/CommandLineTools
CLT_SDK = $(shell xcrun --sdk macosx26.5 --show-sdk-path 2>/dev/null)
ifeq ($(shell xcode-select -p 2>/dev/null),$(CLT_PATH))
ifneq ($(CLT_SDK),)
SWIFT_BUILD = SDKROOT=$(CLT_SDK) swift build
else
SWIFT_BUILD = swift build
endif
else
SWIFT_BUILD = swift build
endif

.PHONY: build run debug clean

build:
	$(SWIFT_BUILD) -c release
	@echo "Assembling app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@cp "$(BUILD_DIR)/release/$(EXECUTABLE)" "$(APP_BUNDLE)/Contents/MacOS/$(EXECUTABLE)"
	@/usr/libexec/PlistBuddy -c "Clear dict" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy \
		-c "Add :CFBundleIdentifier string $(BUNDLE_ID)" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundleDisplayName string $(APP_NAME)" \
		-c "Add :CFBundleExecutable string $(EXECUTABLE)" \
		-c "Add :CFBundleVersion string $(VERSION)" \
		-c "Add :CFBundleShortVersionString string $(VERSION)" \
		-c "Add :CFBundleIconFile string AppIcon.icns" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :LSMinimumSystemVersion string 13.0" \
		-c "Add :NSHighResolutionCapable bool true" \
		-c "Add :CFBundleInfoDictionaryVersion string 6.0" \
		"$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --sign - --identifier "$(BUNDLE_ID)" "$(APP_BUNDLE)"
	@echo "Built: $(APP_BUNDLE)"

run: build
	@open "$(APP_BUNDLE)"

debug:
	$(SWIFT_BUILD)
	@echo "Assembling debug app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@cp "$(BUILD_DIR)/debug/$(EXECUTABLE)" "$(APP_BUNDLE)/Contents/MacOS/$(EXECUTABLE)"
	@/usr/libexec/PlistBuddy -c "Clear dict" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy \
		-c "Add :CFBundleIdentifier string $(BUNDLE_ID)" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundleDisplayName string $(APP_NAME)" \
		-c "Add :CFBundleExecutable string $(EXECUTABLE)" \
		-c "Add :CFBundleVersion string $(VERSION)" \
		-c "Add :CFBundleShortVersionString string $(VERSION)" \
		-c "Add :CFBundleIconFile string AppIcon.icns" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :LSMinimumSystemVersion string 13.0" \
		-c "Add :NSHighResolutionCapable bool true" \
		-c "Add :CFBundleInfoDictionaryVersion string 6.0" \
		"$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --sign - --identifier "$(BUNDLE_ID)" "$(APP_BUNDLE)"
	@open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
