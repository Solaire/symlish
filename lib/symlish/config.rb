require 'yaml'

def load_config(root)
	config_path = File.join(root, "symlish.conf.yaml")
    abs_path = File.realpath(root)

	unless File.exist?(config_path)
		raise "Config file #{config_path} does not exist."
	end

    raw = YAML.load_file(config_path)
    unless raw.is_a?(Hash) && raw.key?("link")
        raise "Invalid config data: #{raw}. 'link' block is missing."
    end

    targets = []
	
    # Validate entries and create objects
    raw["link"].map do |entry|
        validate_config_entry(entry[1])
        targets.append(LinkTarget.new(entry[0], entry[1], abs_path))
    end

    return { 
        root: root,
        link: targets
    }

rescue Psych::SyntaxError => e
	warn "YAML syntax error: #{e.message}"
	exit 1
end

def validate_config_entry(entry)
    unless entry.is_a?(Hash) && entry.key?("paths")
        raise "Invalid config entry: #{entry.inspect}. Each entry must include 'paths'."
    end

    unless entry.key?("target")
        raise "Invalid config entry: #{entry.inspect}. Each entry must include 'target'."
    end

    unless entry["paths"].is_a?(Array) && entry["paths"].all? { |p| p.is_a?(String) }
        raise "Invalid 'paths' in config entry: #{entry.inspect}. Must be an array of strings."
    end

    if entry.key?("conflict") && !%w[skip force].include?(entry["conflict"])
        raise "Invalid 'conflict' value in config entry: #{entry.inspect}. Must be 'skip' or 'force'."
    end

    if entry.key?("ignore") && ![true, false].include?(entry["ignore"])
        raise "Invalid 'ignore' value in config entry #{entry.inspect}. Must be either true or false."
    end

    if entry.key?("ignore-empty") && ![true, false].include?(entry["ignore-empty"])
        raise "Invalid 'ignore-empty' value in config entry #{entry.inspect}. Must be either true or false."
    end
end