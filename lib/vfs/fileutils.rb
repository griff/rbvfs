module VFS
    class BaseNode
        def cp( dest )
        end
        
        def cp_r( dest )
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
    end
end