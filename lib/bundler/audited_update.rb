require 'bundler'
require 'bundler/lockfile_parser'
require "bundler/cli"
require "bundler/cli/update"
require "open-uri"
require 'net/http'
require 'json'
require 'versionomy'
require 'launchy'

module Bundler
  class AuditedUpdate
    def run!
      @before_specs = gem_specs
      bundle_update
      @after_specs = gem_specs

      @output = ""
      @output += "# Gem Changes\n"
      @output += "\n"

      output_gems("Added Gems", added_gems)
      output_gems("Removed Gems", removed_gems)
      output_changed_gems(changed_gems)

      puts "\n\n\n\n\n"

      puts "--------------------------------"
      puts "Upgraded Gems"
      puts "(Generated with bundler-audited_updated https://github.com/bmulholland/audited_bundle_update)"
      puts "--------------------------------"

      puts @output
    end

    def output_gems(title, gems)
      return if gems.empty?

      @output += "## #{title}\n"
      @output += "\n"
      gems.each { |the_gem| gem_output(the_gem.name, the_gem.version) }

      @output += "\n"
    end

    def output_changed_gems(gems)
      return if gems.empty?

      major_upgrades = gems.select {|_, versions| versions[:before].major != versions[:after].major }
      minor_upgrades = gems.select {|name, versions| !major_upgrades.keys.include?(name) && versions[:before].minor != versions[:after].minor }
      point_upgrades = gems.reject { |name, _| major_upgrades.keys.include?(name) || minor_upgrades.keys.include?(name) }

      @output += "## Upgraded Gems\n"
      @output += "\n"

      output_changed_gems_section("Major", major_upgrades)
      output_changed_gems_section("Minor", minor_upgrades)
      output_changed_gems_section("Point", point_upgrades)

      @output += "\n"
    end

    def output_changed_gems_section(title, gems)
      @output += "### #{title} Upgrades\n"
      @output += "\n"
      gems.each { |name, versions| gem_output(name, versions) }

      @output += "\n"
    end

    def gem_output(name, version)
      # gems that are continuously released and therefore have no helpful
      # changelog
      continuously_released_gems = ["aws-partitions", "aws-sdk-core"]

      if name.in? continuously_released_gems
        puts "\n\n\n"
        puts "--------------------------------"
        puts "#{name} updated"
        puts "--------------------------------"

        version_string = version
        info = gem_info(name, version)
        guessed_source = gem_source_url(info)
        change_detail = guessed_source

        puts "This gem is continuously updated, with no meaningful changelog."

        impact = nil
        while impact.nil?
          puts "Does #{name} #{version_string} impact your application? (y/n/[o]pen in browser)"
          answer = gets
          answer = answer.downcase.strip
          if answer == "y"
            puts "What's a short description of the impact?"
            impact = gets
          elsif answer == "n"
            impact = "No impact"
          elsif answer == "o"
            Launchy.open(guessed_source)
          else
            puts "Invalid answer"
          end
        end

        change_detail = impact

      elsif version.is_a? Hash
        version_string = "#{version[:before]} -> #{version[:after]}"
        info = gem_info(name, version[:after])

        guessed_source = gem_source_url(info)

        if guessed_source
          changelog_text, changelog_url = guess_changelog(guessed_source)

          if changelog_text && !changelog_text.empty?
            puts "\n\n\n"
            puts "--------------------------------"
            puts "#{name} changes from #{version_string}"
            puts "--------------------------------"
            # Output the changelog text from top until the line that contains the previous version
            changelog_output = changelog_text.split(/^.*#{Regexp.escape(version[:before].to_s)}/, 2).first
              # Max 200 lines
              changelog_output = changelog_output.lines.to_a[0...200].join
            puts changelog_output
            impact = nil
            while impact.nil?
              puts "Does #{name} #{version_string} impact your application? (y/n/[o]pen in browser)"
              answer = gets
              answer = answer.downcase.strip
              if answer == "y"
                puts "What's a short description of the impact?"
                impact = gets
              elsif answer == "n"
                impact = "No impact"
              elsif answer == "o"
                Launchy.open(changelog_url)
              else
                puts "Invalid answer"
              end
            end

            change_detail = impact
          end
        end

      else
        version_string = version
        info = gem_info(name, version)
        guessed_source = gem_source_url(info)
        change_detail = guessed_source
      end

      change_detail ||= "Unsupported source URL, cannot search for changelog"


      @output += "* #{name} (#{version_string}): #{change_detail}\n"
    end

    def guess_changelog(root_url)
      filenames = %w{
      CHANGELOG
      CHANGELOG.md
      Changelog
      Changelog.md
      History
      History.md
      HISTORY.md
      History.rdoc
      Changes
      CHANGES
      CHANGES.md
      NEWS
      }
      changelog_text = nil
      changelog_url = nil

      filenames.each do |filename|
        changelog_text = try_changelog_url(root_url, filename)
        if changelog_text
          changelog_url = changelog_url_for(root_url, filename)
          break
        end
      end

      unless changelog_text
        changelog_text = github_releases_bodies(root_url)
        changelog_url = github_releases_url(root_url) if changelog_text
      end

      unless changelog_text
        changelog_text = "Could not find changelog URL, try manually"
        changelog_url = root_url
      end

      [changelog_text, changelog_url]
    end

    def gem_source_url(info)
      return nil unless info

      source_url_guess = info["source_code_uri"] || info["homepage_uri"]
      if source_url_guess&.include?("github.com")
        source_url_guess
      else
        # Unsupported source URL
        nil
      end
    end

    def added_gems
      @after_specs.reject {|spec| @before_specs.map(&:name).include?(spec.name) }
    end

    def removed_gems
      @before_specs.reject {|spec| @after_specs.map(&:name).include?(spec.name) }
    end

    def changed_gems
      gems = @after_specs.reject do |after_spec|
        before_spec = @before_specs.find {|before_spec| before_spec && before_spec.name == after_spec.name }
        !before_spec || before_spec.version == after_spec.version
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

    def github_releases_url(source_root)
      api_source_root = source_root.gsub("github.com/", "api.github.com/repos/")
      "#{api_source_root}/releases"
    end

    def github_releases_bodies(source_root)
      response = ::URI.parse(github_releases_url(source_root)).read
      releases = JSON.parse(response)
      release_notes = ""
      releases.each do |release|
        next unless release["body"]
        release_notes += release["name"]
        release_notes += "\n"
        release_notes += release["body"]
        release_notes += "\n"
        release_notes += "\n"
      end
      release_notes
    rescue OpenURI::HTTPError
      return nil
    end

    def changelog_url_for(source_root, filename)
      raw_source_root = source_root.gsub("github.com", "raw.githubusercontent.com")
      url = "#{raw_source_root}/master/#{filename}"
    end

    def try_changelog_url(source_root, filename)
      ::URI.parse(changelog_url_for(source_root, filename)).read
    rescue OpenURI::HTTPError
      return nil
    end

    def gem_info(name, version)
      gem_url = "https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}"
      response = ::URI.parse(gem_url).read
      JSON.parse(response)
    rescue OpenURI::HTTPError => e
      # return nil for 404 - which means the gem doens't exist on rubygems,
      # probably private
      raise unless e.message.include?("404")
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
end
