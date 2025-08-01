require_relative "utils"
require "pathname"

class LinkItem
    attr_accessor :root, :source, :abs_source, :target, :backup, :type

    def initialize(root, source, target)
        @rel_source = Pathname.new(source).relative_path_from(root)

        @root = Pathname.new(root)
        @source = source
        @target = File.join(target, @rel_source.to_s.split(File::SEPARATOR).drop(1).join(File::SEPARATOR)) # Need to exclude the first directory
        @backup = "#{@target}.bak"
        @type   = File.directory?(@source) ? "directory" : "file"
    end

    # <!--
    #   - LinkItem.here? -> true or false
    # -->
    # Returns `true` if @target is a symbolic link that points to @source, `false` otherwise.
    #
    def here?
        return File.symlink?(@target) && File.readlink(@target) == @source
    end

    # <!--
    #   - LinkItem.backup? -> true or false
    # -->
    # Returns `true` if file named `"#{@target}.bak"` exists in the target directory, `false` otherwise.
    #
    def backup?
        puts "backup?: #{@backup}"
        return File.file?(@backup)
    end

    # <!--
    #   - LinkItem.can_backup? -> true or false
    # -->
    # Returns `true` if @target exists as a file which can be backed up, `false` otherwise.
    #
    def can_backup?
        return File.file?(@target) && !File.symlink?(@target)
    end

    # <!--
    #   - LinkItem.create_backup -> 0
    # -->
    # Create a backup by renaming `@target` to `"#{@target}.bak"`.
    # Early exit if either target does not exist _or_ the backup exists.
    #
    def create_backup
        return unless file_dir?(@target) && !backup?

        File.rename(@target, @backup)
    end

    # <!--
    #   - LinkItem.restore_backup -> 0
    # -->
    # Restore the backup by renaming `"#{@target}.bak"` to `@target`.
    # Early exit if either target exists _or_ the backup does not exist.
    # 
    def restore_backup
        return if file_dir?(@target) || !backup?

        File.rename(@backup, @target)
    end

    # <!--
    #   - LinkItem.symlink? -> true or false
    # -->
    # Returns `true` if `@target` points to a symbolic link, `false` otherwise.
    # 
    def symlink?
        return File.symlink?(@target)
    end
    
    # <!--
    #   - LinkItem.symlink -> file_name
    # -->
    # Returns the name of the file referenced by the given link.
    # 
    def symlink
        return File.readlink(@target)
    end

    # <!--
    #   - LinkItem.create_symlink -> 0
    # -->
    # Creates a symbolic link on @target for the existing file @source.
    # Early exit if @target exists as a file or symbolic link
    # 
    def create_symlink
        return if file_dir?(@target) || File.symlink?(@target) || here?
        File.symlink(@source, @target)
    end

    # <!--
    #   - LinkItem.remove_symlink -> 0
    # -->
    # Removes the symbolic link for @target.
    # Early exit if @target is not a symbolic link or it does not point to @source.
    # 
    def remove_symlink
        return unless symlink? && here?
        File.delete(@target)
    end
end