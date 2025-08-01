require_relative 'link_item'

class LinkTarget
    attr_reader :key, :path, :ignore 
    attr_accessor :items, :ignore_empty, :conflict

    def initialize(key, data, abs_root)
        @key            = key
        @path           = nil
        @conflict       = data.key?("conflict")     ? data["conflict"]      : "skip"
        @ignore         = data.key?("ignore")       ? data["ignore"]        : false
        @ignore_empty   = data.key?("ignore-empty") ? data["ignore-empty"]  : true

        @items = Array.new

        # Apply default value to "conflict"
        unless ["skip", "force"].include? @conflict 
            @conflict = "skip"
        end

        # Look through data["paths"] to find the first valid target path.
        data["paths"].each do |path|
            candidate = path.gsub(/\$(\w+)/) do |match|
                env_var = match[1..] # Extract environment variable (using UNIX-style with the $)
                ENV[env_var] || ''
            end

            expanded = File.expand_path(candidate)
            if File.exist?(expanded)
                @path = expanded
                break
            end
        end

        return if @path.nil?

        
        # Find all files/directories that we need to target
        target_root = File.join(abs_root, data["target"])
        Dir.glob(target_root, File::FNM_DOTMATCH)
            .reject { |path| File.basename(path) == "." || File.basename(path) == ".."}
            .each { |item| @items.push LinkItem.new(abs_root, item, @path) }
    end

    # Check if the target is valid based on whether we have a target path
    def valid?
        return !@path.nil?
    end
end