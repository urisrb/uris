local_gemfile = File.expand_path("../Gemfile.local", __dir__)

ENV["BUNDLE_GEMFILE"] ||=
  File.exist?(local_gemfile) ? local_gemfile : File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup"
