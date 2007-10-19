require 'taglib'

#  Created by Brian Olsen on 2007-03-14.
#  Copyright (c) 2007. All rights reserved.
module VFS
    module Taglib
        include MetaNamespaceProxyModule
        PROPERTIES = %w( title artist album comment genre year track length bitrate samplerate channels )

        attr_reader :taglib
        set_proxy :taglib
        
        def open_taglib
            taglibtype = nil
            if @meta.owner.respond_to? :taglib_type
                taglibtype = @meta.owner.taglib_type
            elsif @meta.owner.respond_to? :mimetype
                taglibtype = TagLib::File.taglibForMime( @meta.owner.mimetype )
            end
            @taglib = TagLib::File.new(@meta.file_path, taglibtype)
            ret = @taglib
            if block_given?
                begin
                    ret = yield self
                ensure
                    @taglib.close unless @taglib.nil?
                    @taglib = nil
                end
            end
            ret
        end
        
        def close_taglib
            @taglib.close unless @taglib.nil?
        end
    end
end
