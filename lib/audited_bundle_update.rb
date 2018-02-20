require 'bundler'
require 'bundler/lockfile_parser'
require "bundler/cli"
require "bundler/cli/update"
require "open-uri"
require 'net/http'
require 'json'
require 'versionomy'

class AuditedBundleUpdate
  def run!
    @before_specs = gem_specs
    bundle_update
    @after_specs = gem_specs

    output_gems("Added Gems", added_gems)
    output_gems("Removed Gems", removed_gems)
    output_changed_gems(changed_gems)
  end

  def output_gems(title, gems)
    return if gems.empty?

    puts "### #{title}"
    puts "\n"
    gems.each { |the_gem| puts "* #{the_gem.name}" }

    puts "\n"
  end

  def output_changed_gems(gems)
    return if gems.empty?

    major_upgrades = gems.select {|_, versions| versions[:before].major != versions[:after].major }
    minor_upgrades = gems.select {|_, versions| versions[:before].minor != versions[:after].minor }
    point_upgrades = gems.reject { |name, _| major_upgrades.keys.include?(name) || minor_upgrades.keys.include?(name) }

    puts "### Upgraded Gems"
    puts "\n"

    output_changed_gems_section("Major", major_upgrades)
    output_changed_gems_section("Minor", minor_upgrades)
    output_changed_gems_section("Point", point_upgrades)

    puts "\n"
  end

  def output_changed_gems_section(title, gems)
    puts "### #{title} Upgrades"
    puts "\n"
    gems.each { |name, versions| puts "* #{name} (#{versions[:before]} -> #{versions[:after]})" }

    puts "\n"
  end

  def added_gems
    @after_specs.reject {|spec| @before_specs.map(&:name).include?(spec.name) }
  end

  def removed_gems
    @before_specs.reject {|spec| @after_specs.map(&:name).include?(spec.name) }
  end

  def changed_gems
    gems = @after_specs.reject do |after_spec|
      next unless after_spec
      before_spec = @before_specs.find {|before_spec| before_spec && before_spec.name == after_spec.name }
      next unless before_spec # new gem
      before_spec.version == after_spec.version
    end

    gems.map! do |the_gem|
      before_gem = @before_specs.find {|before_spec| before_spec.name == the_gem.name }
      after_gem = @after_specs.find {|after_spec| after_spec.name == the_gem.name }
      versions = {
        before: Versionomy.parse(before_gem.version.to_s),
        after: Versionomy.parse(after_gem.version.to_s)
      }
      [the_gem.name, versions]
    end

    gems.to_h
  end

  def gem_info(name, version)
    gem_url = "https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}"
    response = URI.parse(gem_url).read
    JSON.parse(response)
  end

  def gem_specs
    root     = File.expand_path(Dir.pwd)
    lockfile = Bundler::LockfileParser.new(
      File.read(File.join(root, 'Gemfile.lock'))
    )
    lockfile.specs
  end

  def bundle_update
    Bundler::CLI::Update.new({}, []).run
  end
end
