#!/usr/bin/env ruby
# Adds a unit test target to the flo Xcode project so tests can run headless
# via `xcodebuild test`.
#
# Safe to run multiple times — updates settings but won't create duplicates.

require "xcodeproj"

project_path = File.expand_path("../flo.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == "flo" }
abort "Could not find main 'flo' target" unless main_target

test_target = project.targets.find { |t| t.name == "floTests" }

unless test_target
  puts "Creating test target 'floTests'..."

  deployment_target =
    main_target.build_configurations.first.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] || "16.0"

  test_target = project.new_target(
    :unit_test_bundle,
    "floTests",
    :ios,
    deployment_target
  )

  test_target.product_reference.name = "floTests.xctest"

  # Add test files to the test target
  test_dir = File.expand_path("../floTests", __dir__)
  test_group = project.main_group.new_group("floTests", test_dir)

  Dir.glob(File.join(test_dir, "*.swift")).sort.each do |file|
    file_ref = test_group.new_file(file)
    test_target.source_build_phase.add_file_reference(file_ref)
  end

  # Add the main target as a dependency so @testable import works
  test_target.add_dependency(main_target)

  project.save
  puts "  Created test target: #{test_target.uuid}"
end

# Always update build settings (idempotent)
puts "Updating test target build settings..."
test_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "net.faultables.flo.floTests"
  config.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  config.build_settings["SWIFT_VERSION"] = "5"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"

  # Test host: the test bundle is loaded into the main app at runtime.
  # These are required for @testable import to resolve symbols from the
  # main target (the linker needs to know they'll be provided by the host).
  config.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/flo.app/flo"
  config.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"

  config.build_settings["FRAMEWORK_SEARCH_PATHS"] = "$(inherited)"
  config.build_settings["HEADER_SEARCH_PATHS"] = "$(inherited)"

  if config.name == "Debug"
    main_target.build_configurations.each do |main_config|
      main_config.build_settings["ENABLE_TESTABILITY"] = "YES" if main_config.name == "Debug"
    end
  end
end

# Scheme was manually created in xcshareddata/xcschemes/flo.xcscheme.
# The xcodeproj gem's XCScheme API has bugs in this version, so we leave it as-is.

project.save
puts "✅ Test target and scheme configured."
puts ""
puts "Run tests headless:"
puts "  xcodebuild test \\"
puts "    -project flo.xcodeproj \\"
puts "    -scheme flo \\"
puts "    -destination 'platform=iOS Simulator,name=iPhone 17' \\"
puts "    -only-testing:floTests"
