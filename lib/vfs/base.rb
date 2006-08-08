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
        
        def atime=( other )
            File.utime( other, File.mtime( file_path ), file_path )
        end
        alias :lastaccessed= :atime=
        
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
        def size?() size unless zero end
            
        # See <tt>File.zero</tt>.
        def zero() size() == 0 end

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
        
        def initialize( name, parent )
            @name = name
            @parent = parent
        end
        
        def fs() @parent.fs() end
            
        def mkdir
            if exists?
                raise Errno::EEXIST
            else
                raise Errno::EACCES
            end
        end

        def open( mode="r" )
            throw Errno::EACCES
        end        
        
        def path( trail_slash=false )
            if @parent
                parentpath = @parent.path
                parentpath += '/' unless /\/$/ =~ parentpath
            else
                parentpath = '/'
            end
            if @name
                parentpath + @name + (trail_slash ? '/' : '')
            else
                parentpath
            end
        end
        alias :to_str :path
        alias :to_s :path

        def +(other)
            other = other.to_str if other.respond_to? :to_str
            @fs.lookup( self.path(true) + other )
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
        
        def resolve( name ) NopNode.new( name, self ) end
    end
    
    class NopNode < BaseNode
        def meta() NopMeta.new() if exists? end
            
        def resolve( name ) NopNode.new( name, self ) end
    end
    
    class NopMeta < BaseMeta
        def file_path
            throw Errno::ENOENT
        end
    end
    
    class VirtualMeta < NopMeta
        # See <tt>File.atime</tt>.
        def atime() Time.now end
        
        # See <tt>File.ctime</tt>.
        def ctime() Time.now end
            
        # See <tt>File.mtime</tt>.
        def mtime() Time.now end
            
        # See <tt>File.size</tt>.
        def size() 0 end
    end
        
    # The Root mixin module gives you an easy way to get methods common to all root nodes.
    # This is mainly the assignpath method.
    module Root
        def assignpath( fs, name, parent )
            @fs = fs
            @name = name
            @parent = parent
        end
        
        def fs() @fs end
    end
end
# vim: sts=4:sw=4:ts=4:et