#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "uri"
require "yaml"

root = Pathname.new(`git rev-parse --show-toplevel`.strip)
abort "Run this command from a Git working tree." unless $?.success?

tracked_and_pending = `git ls-files --cached --others --exclude-standard -z`
paths = tracked_and_pending.split("\0").map { |path| root.join(path) }.select(&:file?)

artifact_patterns = [
  %r{(?:^|/)\.DS_Store$},
  %r{(?:^|/)xcuserdata/},
  %r{(?:^|/)DerivedData/},
  %r{(?:^|/)\.build/},
  %r{(?:^|/)build/},
  /\.(?:xcarchive|xcresult|dmg|log|p12|mobileprovision|pem|key|p8)\z/i
].freeze

secret_patterns = {
  "GitHub token" => /(?:gh[pousr]_[A-Za-z0-9]{20,}|github_[p]at_[A-Za-z0-9_]{20,})/,
  "OpenAI-style key" => /sk-[A-Za-z0-9_-]{20,}/,
  "AWS access key" => /AKIA[0-9A-Z]{16}/,
  "private key block" => /-----BEGIN [A-Z ]*PRIVATE\s+KEY-----/
}.freeze

allowed_email_domains = %w[
  bookmarkbridge.fr
  example.com
  example.org
  example.test
  example.invalid
].freeze
violations = []
markdown_files = []
yaml_files = []
text_file_count = 0

paths.each do |absolute_path|
  relative_path = absolute_path.relative_path_from(root).to_s

  if artifact_patterns.any? { |pattern| relative_path.match?(pattern) }
    violations << "#{relative_path}: generated, local, or sensitive artifact is tracked"
  end

  content = absolute_path.binread
  next if content.include?("\0")

  content = content.force_encoding(Encoding::UTF_8)
  next unless content.valid_encoding?

  text_file_count += 1
  markdown_files << absolute_path if absolute_path.extname.casecmp(".md").zero?
  yaml_files << absolute_path if %w[.yml .yaml].include?(absolute_path.extname.downcase)

  content.scan(%r{/Users/([A-Za-z0-9._-]+)}) do |match|
    username = match.first
    next if username == "tester"

    violations << "#{relative_path}: local macOS username appears in an absolute path"
  end

  content.scan(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i) do |email|
    next if email.end_with?("@2x.png")

    domain = email.split("@", 2).last.downcase
    next if allowed_email_domains.include?(domain)

    violations << "#{relative_path}: non-placeholder email address detected"
  end

  secret_patterns.each do |label, pattern|
    violations << "#{relative_path}: #{label} pattern detected" if content.match?(pattern)
  end
end

markdown_files.each do |markdown_path|
  content = markdown_path.read
  content.scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |raw_target|
    target = raw_target.strip
    target = target[1..-2] if target.start_with?("<") && target.end_with?(">")
    target = target.split(/\s+["']/, 2).first
    next if target.empty? || target.start_with?("#")
    next if target.match?(%r{\A(?:https?|mailto):}i)

    local_target = URI.decode_www_form_component(target.split("#", 2).first)
    resolved = markdown_path.dirname.join(local_target).cleanpath
    next if resolved.exist?

    relative_markdown = markdown_path.relative_path_from(root)
    violations << "#{relative_markdown}: broken relative link #{target.inspect}"
  rescue ArgumentError
    relative_markdown = markdown_path.relative_path_from(root)
    violations << "#{relative_markdown}: invalid encoded link #{target.inspect}"
  end
end

yaml_files.each do |yaml_path|
  Psych.parse_file(yaml_path.to_s)
rescue Psych::SyntaxError => error
  relative_yaml = yaml_path.relative_path_from(root)
  violations << "#{relative_yaml}: invalid YAML (#{error.message.lines.first.strip})"
end

workflow_path = root.join(".github/workflows/ci.yml")
workflow = workflow_path.read
required_workflow_content = [
  "runs-on: macos-26",
  "actions/checkout@v6",
  "persist-credentials: false",
  "CODE_SIGNING_ALLOWED=NO",
  "QA/Scripts/run-qa.sh --qa-only"
].freeze
required_workflow_content.each do |required_content|
  next if workflow.include?(required_content)

  violations << ".github/workflows/ci.yml: missing #{required_content.inspect}"
end

forbidden_workflow_patterns = {
  "repository secret reference" => /secrets\./,
  "release publication command" => /\bgh\s+release\b/,
  "notarization command" => /\bnotarytool\b/,
  "release upload action" => %r{actions/upload-release-asset}
}.freeze
forbidden_workflow_patterns.each do |label, pattern|
  violations << ".github/workflows/ci.yml: #{label} is not allowed" if workflow.match?(pattern)
end

if violations.empty?
  puts "Repository audit passed."
  puts "Checked #{paths.count} tracked or pending files (#{text_file_count} UTF-8 text files)."
  puts "Validated #{markdown_files.count} Markdown files and #{yaml_files.count} YAML files."
  puts "Confirmed the CI workflow is read-only and non-publishing."
  exit 0
end

warn "Repository audit failed with #{violations.uniq.count} finding(s):"
violations.uniq.sort.each { |violation| warn "- #{violation}" }
exit 1
