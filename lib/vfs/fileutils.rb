module VFS
    class BaseNode
        def rm_rf
        end
        
        def cp( dest )
            fu_each_src_dest( dest) do |d|
              copy_file d
            end
        end
        
        def cp_r( dest )
            fu_each_src_dest(src, dest) do |s, d|
              copy_entry s, d, options[:preserve], options[:dereference_root]
            end
        end
        
        def copy_file( dest )
            dest = fs.lookup( dest, self ) unless dest.respond_to? :open
            open( 'rb' ) { |r|
                dest.open( 'wb' ) { |w|
                    blksize = self.blksize
                    while s = src.read(blksize)
                      dest.write s
                    end
                }
            }
        end
        
        def copy( dest )
            case
            when file?
              copy_file dest
            when directory?
              begin
                Dir.mkdir dest
              rescue
                raise unless File.directory?(dest)
              end
          else
            raise "unknown file type: #{path}"
          end
        end
        
        def fu_each_src_dest(dest)   #:nodoc:
            dest = fs.lookup(dest) unless dest.respond_to? :directory?
            if dest.directory
                yield dest + name
            else
                yield dest
            end
          end
        end
    end
end