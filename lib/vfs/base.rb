module VFS
    # The basic implementation for meta information objects. This class is meant to be extended or included
    # as a mixin and expects there to be implemented a file_path method returning the path to a valid file on
    # the normal file system.
    # See <tt>VFS::File::BaseNode.meta</tt>.
    # See <tt>VFS::File::Meta.file_path</tt>.
    # See <tt>VFS::NopMeta.file_path</tt>.
    class BaseMeta
        # See <tt>File.atime</tt>.
        def atime() File.atime( file_path ) end 
	alias :lastaccessed :atime
	alias :getlastaccessed :atime
        
        # See <tt>File.ctime</tt>.
        def ctime() File.ctime( file_path ) end
        alias :creationdate :ctime
            
        # See <tt>File.mtime</tt>.
        def mtime() File.mtime( file_path ) end
        alias :lastmodified :mtime
        alias :getlastmodified :mtime
            
        def mtime=( other )
            File.utime( Time.now, other, file_path )
            other
        end
        alias :lastmodified= :mtime=
        alias :getlastmodified= :mtime=
            
        # See <tt>File.size</tt>.
        def size() File.size( file_path ) end
        alias :contentlength :size
        alias :getcontentlength :size
            
        # See <tt>File.size?</tt>.
        def size?() File.size?( file_path ) end
            
        # See <tt>File.zero</tt>.
        def zero() File.zero( file_path ) end

        def etag
            st = File.stat( file_path )
            sprintf('%x-%x-%x', st.ino, st.size, st.mtime.to_i )
        end
        alias :getetag :etag
        
        def contenttype
            "httpd/unix-directory"
        end
        alias :getcontenttype :contenttype
        
        #resourcetype - defines if it is a collection
    end
    
    class BaseNode
        include Enumerable
        
        def path( end_slash=false )
            if @name
                parentpath + @name + (end_slash ? '/' : '')
            else
                parentpath
            end
        end
        alias :to_str :path
        alias :to_s :path

        def parentpath
            if @parent
                loc_path = @parent.path
                loc_path += '/' unless /\/$/ =~ loc_path
                loc_path
            else
                '/'
            end
        end
        
        def +(other)
            @fs.lookup( other, self )
        end
        
        def ==( other )
            #other = other.to_str if other.respond_to? :str
            self.path == other
        end
        alias === ==
        alias eq? == 
        
        def <=>(other)
          self.path.tr('/', "\0") <=> other.to_s.tr('/', "\0")
        end

        def hash # :nodoc:
          self.path.hash
        end
        
        def exists?() false end
        
        def file?() false end
            
        def directory?() false end
            
        def each # :yield: filename
            yield "."
            yield ".."
        end
    end
    
    class NopNode < BaseNode
        def initialize( name, parent )
            @name = name
            @parent = parent
        end
        
        def meta() NopMeta.new() end
            
        def open( mode="r" )
            throw Errno::ENOENT
        end
        
        def resolve( name )
            NopNode.new( name, self )
        end
    end
    
    class NopMeta < BaseMeta
        def file_path
            throw Errno::ENOENT
        end
    end
        
    # The Root mixin module gives you an easy way to get methods common to all root nodes.
    # This is mainly the assignpath method.
    module Root
        def assignpath( fs, name, parent )
            @fs = fs
            @name = name
            @parent = parent
        end
    end
end
