require 'bundler'
require 'bundler/lockfile_parser'
require "bundler/cli"
require "bundler/cli/update"

class AuditedBundleUpdate
  def run!
    load_gemfile
    puts @lockfile.specs
  end

  def load_gemfile
    @root     = File.expand_path(Dir.pwd)
    @lockfile = Bundler::LockfileParser.new(
      File.read(File.join(@root, 'Gemfile.lock'))
    )
  end

  def bundle_update
    Bundler::CLI::Update.new(options, gems).run
  end
end
