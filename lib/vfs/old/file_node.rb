#  Created by Brian Olsen on 2007-03-16.
#  Copyright (c) 2007. All rights reserved.
module VFS
    class FileNode < BaseNode
        class << self
            def define_meta( sym = :Meta )
                module_eval <<-end_eval
                    class #{sym} < ::VFS::Meta
                    end
                end_eval
                const_get(sym)
            end
            
            def meta( sym = :Meta, &block )
                m = define_meta(sym)
                m.module_eval(&block)
            end
        end
        
        def meta
            @meta = Meta.new( self ) unless @meta
            @meta
        end
        
        include File
    end
end
