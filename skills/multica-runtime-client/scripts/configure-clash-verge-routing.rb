#!/usr/bin/env ruby
# Persist Multica/Tailscale routing in the active Clash Verge rules enhancement.

require "fileutils"
require "yaml"

COMMAND = ARGV.fetch(0, "")
ROOT = File.expand_path(ARGV.fetch(1, ""))
PROFILES_PATH = File.join(ROOT, "profiles.yaml")

RULES = [
  "DOMAIN-SUFFIX,ts.net,DIRECT",
  "IP-CIDR,100.64.0.0/10,DIRECT,no-resolve",
  "IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve"
].freeze

def load_yaml(path)
  raise "missing config: #{path}" unless File.file?(path)

  data = YAML.safe_load(File.read(path), permitted_classes: [], aliases: true)
  raise "invalid YAML mapping: #{path}" unless data.is_a?(Hash)

  data
end

def active_profile(profiles)
  items = profiles["items"]
  raise "profiles.items must be an array" unless items.is_a?(Array)

  current = profiles["current"]
  item = items.find { |candidate| candidate.is_a?(Hash) && candidate["uid"] == current }
  raise "current Clash Verge profile is unavailable" unless item
  raise "current Clash Verge profile cannot accept enhancements" unless %w[local remote].include?(item["type"])

  [items, item]
end

def desired_state(root)
  profiles = load_yaml(PROFILES_PATH)
  items, current = active_profile(profiles)

  option = current["option"] ||= {}
  raise "current profile option must be a mapping" unless option.is_a?(Hash)

  rules_uid = option["rules"]
  rules_item = items.find { |candidate| candidate.is_a?(Hash) && candidate["uid"] == rules_uid }
  if rules_item && rules_item["type"] != "rules"
    raise "current rules enhancement has an unexpected type"
  end

  unless rules_item
    rules_uid = "multicaTailscaleRules"
    rules_item = items.find { |candidate| candidate.is_a?(Hash) && candidate["uid"] == rules_uid }
    if rules_item
      raise "reserved rules enhancement has an unexpected type" unless rules_item["type"] == "rules"
    else
      rules_item = {
        "uid" => rules_uid,
        "type" => "rules",
        "name" => "Multica Tailscale Direct",
        "file" => "#{rules_uid}.yaml",
        "updated" => Time.now.to_i
      }
      items << rules_item
    end
    option["rules"] = rules_uid
  end

  rules_file = rules_item["file"] || "#{rules_uid}.yaml"
  raise "rules enhancement file escapes the profiles directory" unless File.basename(rules_file) == rules_file

  rules_path = File.join(root, "profiles", rules_file)
  rules = File.file?(rules_path) ? load_yaml(rules_path) : { "prepend" => [], "append" => [], "delete" => [] }
  prepend = rules["prepend"] ||= []
  raise "rules prepend must be an array" unless prepend.is_a?(Array)

  rules["prepend"] = RULES + prepend.reject { |rule| RULES.include?(rule.to_s) }
  rules["append"] ||= []
  rules["delete"] ||= []

  [profiles, rules, rules_path]
end

def atomic_write(path, value)
  directory = File.dirname(path)
  FileUtils.mkdir_p(directory)
  temporary = File.join(directory, ".#{File.basename(path)}.multica.#{$$}.tmp")
  mode = File.file?(path) ? File.stat(path).mode & 0o777 : 0o600
  File.open(temporary, "w", mode) { |file| file.write(YAML.dump(value)) }
  File.chmod(mode, temporary)
  File.rename(temporary, path)
ensure
  File.delete(temporary) if temporary && File.exist?(temporary)
end

profiles, rules, rules_path = desired_state(ROOT)

case COMMAND
when "rules-path"
  puts rules_path
when "check"
  current_profiles = load_yaml(PROFILES_PATH)
  current_rules = File.file?(rules_path) ? load_yaml(rules_path) : nil
  unchanged = current_profiles == profiles && current_rules == rules
  exit(unchanged ? 0 : 10)
when "apply"
  atomic_write(rules_path, rules)
  atomic_write(PROFILES_PATH, profiles)
else
  warn "usage: configure-clash-verge-routing.rb check|apply|rules-path CONFIG_ROOT"
  exit 2
end
