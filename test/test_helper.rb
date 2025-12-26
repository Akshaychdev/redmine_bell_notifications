# frozen_string_literal: true

# Redmine Bell Notifications Plugin
# Test Helper

# Load Redmine test helper first (it will load mocha if available)
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

# Load plugin classes
require File.expand_path(File.dirname(__FILE__) + '/../lib/redmine_bell_notifications')

# Add plugin fixture path
class ActiveSupport::TestCase
  self.fixture_paths << File.expand_path('fixtures', __dir__)
end
