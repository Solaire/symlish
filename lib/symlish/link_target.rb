class LinkTarget
    attr_reader :name, :rel_path, :abs_path, :link_target, :child

    def initialize(target_dir, child)
        @child = child 
        @name = File.join(File.basename(target_dir), child)
        @rel_path = File.join(target_dir, child)
        @abs_path = File.realpath(@rel_path)
        @link_target = File.join(Dir.home, child)
    end

    def directory?
        return File.directory?(@abs_path)
    end

    def zero?
        return File.zero?(@abs_path)
    end

    def starts_with_dot?
        return @child[0,1] == "."
    end

    def link_target_exists?
        File.file?(@link_target)
    end

    def backup_path
        return "#{@link_target}.bak"
    end

    def backup_exists?
        return File.file?(backup_path)
    end

    def symlink?
        File.symlink?(@link_target)
    end

    def points_here?
        return false unless symlink?
        File.readlink(@link_target) == @abs_path
    end

    def create_backup(dry_run = false)
        return unless link_target_exists?

        if dry_run
            puts "🔁     Would make backup: #{@link_target} ~> #{backup_path}"
        else
            File.rename(@link_target, backup_path)
            puts "🔁     Moved existing file to: #{backup_path}"
        end
    end

    def restore_backup(dry_run = false)
        return unless backup_exists?

        if dry_run
            puts "🔁     Would restore backup: #{backup_path} ~> #{@link_target}"
        else
            File.rename(backup_path, @link_target)
            puts "🔁     Restored backup: #{backup_path}.bak ~> #{@link_target}"
        end
    end

    def create_symlink(dry_run = false)
        if dry_run
            puts "📝     Would link: #{@name} ~> #{@link_target}"
        else
            File.symlink(@abs_path, @link_target)
            puts "✅     Linked: #{@abs_path} → #{@link_target}"
        end
    end

    def remove_symlink(dry_run = false)
        if dry_run
            puts "🗑️     Would unlink: #{@link_target}"
        else
            File.delete(@link_target)
            puts "🗑️     Unlinked: #{@link_target}"
        end
    end

    def readlink
        return File.readlink(@link_target) if symlink?
    end
end