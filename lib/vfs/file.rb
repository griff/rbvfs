require 'vfs/file_handler'

module VFS
  class File
    include FileHandlerModule

    def initialize( rootpath )
      @rootpath = VFS.to_path( rootpath )
      self.taint if @rootpath.tainted?
    end
    
    def resolve( name )
      File.new( ::File.join(@rootpath, name ) )
    end
    
    def fs_filepath
      @rootpath
    end

    def eql?(other)
      other.kind_of?(File) && self.fs_filepath.eql?(other.fs_filepath)
    end
    
    def ==(other)
      other.respond_to?(:fs_filepath) && self.fs_filepath == other.fs_filepath
    end
  end
end

# vim: sts=4:sw=4:ts=4:et
