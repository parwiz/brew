#:  * `outdated` [`--quiet`|`--verbose`|`--json=v1`] [`--fetch-HEAD`]:
#:    Show formulae that have an updated version available.
#:
#:    By default, version information is displayed in interactive shells, and
#:    suppressed otherwise.
#:
#:    If `--quiet` is passed, list only the names of outdated brews (takes
#:    precedence over `--verbose`).
#:
#:    If `--verbose` is passed, display detailed version information.
#:
#:    If `--json=`<version> is passed, the output will be in JSON format. The only
#:    valid version is `v1`.
#:
#:    If `--fetch-HEAD` is passed, fetch the upstream repository to detect if
#:    the HEAD installation of the formula is outdated. Otherwise, the
#:    repository's HEAD will be checked for updates when a new stable or devel
#:    version has been released.

require "formula"
require "keg"

module Homebrew
  def outdated
    formulae = if ARGV.resolved_formulae.empty?
      Formula.installed
    else
      ARGV.resolved_formulae
    end
    if ARGV.json == "v1"
      outdated = print_outdated_json(formulae)
    else
      outdated = print_outdated(formulae)
    end
    Homebrew.failed = !ARGV.resolved_formulae.empty? && !outdated.empty?
  end

  def print_outdated(formulae)
    verbose = ($stdout.tty? || ARGV.verbose?) && !ARGV.flag?("--quiet")
    fetch_head = ARGV.fetch_head?

    outdated_formulae = formulae.select { |f| f.outdated?(fetch_head: fetch_head) }

    outdated_formulae.each do |f|
      if verbose
        outdated_kegs = f.outdated_kegs(fetch_head: fetch_head)

        current_version = if f.alias_changed?
          latest = f.latest_formula
          "#{latest.name} (#{latest.pkg_version})"
        elsif f.head? && outdated_kegs.any? { |k| k.version.to_s == f.pkg_version.to_s }
          # There is a newer HEAD but the version number has not changed.
          "latest HEAD"
        else
          f.pkg_version.to_s
        end

        outdated_versions = outdated_kegs.
          group_by { |keg| Formulary.from_keg(keg) }.
          sort_by { |formula, kegs| formula.full_name }.
          map do |formula, kegs|
            "#{formula.full_name} (#{kegs.map(&:version).join(", ")})"
          end.join(", ")

        puts "#{outdated_versions} < #{current_version}"
      else
        puts f.full_installed_specified_name
      end
    end
  end

  def print_outdated_json(formulae)
    json = []
    fetch_head = ARGV.fetch_head?
    outdated_formulae = formulae.select { |f| f.outdated?(fetch_head: fetch_head) }

    outdated = outdated_formulae.each do |f|
      outdated_versions = f.outdated_kegs(fetch_head: fetch_head).map(&:version)
      current_version = if f.head? && outdated_versions.any? { |v| v.to_s == f.pkg_version.to_s }
        "HEAD"
      else
        f.pkg_version.to_s
      end

      json << { name: f.full_name,
                installed_versions: outdated_versions.collect(&:to_s),
                current_version: current_version }
    end
    puts Utils::JSON.dump(json)

    outdated
  end
end
