require 'yaml'

def load_config(root)
	config_path = File.join(root, "symlish.conf.yaml")

	unless File.exist?(config_path)
		warn "Config file #{config_path} does not exist"
		return { ignore: [] }
	end

    raw = YAML.load_file(config_path)
    unless raw.is_a?(Hash) && raw.key?("ignore")
        return { ignore: [] }
    end
	
    # Normalise all ignored paths
    ignore_list = raw["ignore"].map do |entry|
        File.join(root, entry)
    end

    { ignore: ignore_list }

rescue Psych::SyntaxError => e
	warn "YAML syntax error: #{e.message}"
	exit 1
end