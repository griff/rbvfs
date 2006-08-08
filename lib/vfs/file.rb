module VFS
    # Container module for classes implementing a filesystem based on the physical filesystem.
    # All the classes in this module are basicly wrappers that map the API of VFS into the file handeling
    # APIs made available by Ruby.
    #
    # Two kinds of file nodes exists; Node and Root. These share some common code implemented in the common
    # parent BaseNode. Root is the base of a file resolve and can be used as an argument to both a new 
    # VFS::FileSystem or to VFS::FileSystem.mount. Node are on the other hand child nodes with a Root object
    # further up the parent path.
    module File
        #
        #
        class BaseNode < VFS::BaseNode
            def file?() FileTest.file?( fs_filepath ) end
            def exists?() FileTest.exists?( fs_filepath ) end
            def directory?() FileTest.directory?( fs_filepath ) end

            def each( &block ) 
                FileTest.directory?(fs_filepath) ? Dir.foreach( fs_filepath, &block ) : super
            end

            def mkdir
                Dir.mkdir( fs_filepath )
            end

            def meta() Meta.new( self ) end

            def open( mode="r", &block )
                if block_given?
                    File.open( fs_filepath, mode, &block )
                else
                    File.new( fs_filepath, mode )
                end
            end

            def resolve( name )
                Node.new( @fs, name, self )
            end
        end

        class Node < BaseNode
            def initialize( fs, name, parent )
                @fs = fs
                super( name, parent )
            end

            def fs_filepath
                loc_path = @parent.fs_filepath # + ::File::SEPARATOR + @name
                loc_path += ::File::SEPARATOR unless %r{File::SEPARATOR$} =~ loc_path
                loc_path + @name
            end
        end

        class Root < BaseNode
            include VFS::Root

            def initialize( rootpath )
                @rootpath = VFS.to_path( rootpath )
                self.taint if @rootpath.tainted?
            end

            def fs_filepath
                @rootpath
            end
        end

        class Meta < VFS::BaseMeta
            def initialize( fileObject )
                @file = fileObject
            end

            def file_path() @file.fs_filepath end
        end
    end
end

# vim: sts=4:sw=4:ts=4:et
