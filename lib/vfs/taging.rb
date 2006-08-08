#!/usr/bin/env ruby
#
#  Created by Brian Olsen on 2006-08-03.
#  Copyright (c) 2006. All rights reserved.
require 'vfs'
require 'active_record'

module VFS
    module Tagging
        class BaseNode < VFS::BaseNode
            def resolve( name )
                Node.new( @fs, name, self )
            end
        end
    
        class Node  < VFS::BaseNode
        end
        
        class Root < VFS::BaseNode
            include VFS::Root
            
            def initialize( filespath )
                @filespath = filespath
            end
            
            def directory?() true end
            def exists?() true end
            def each
                super
                yield 'files'
#                yield 'tags'
            end
            
            def meta() VirtualMeta.new() end
            
            def resolve( name )
                if name == 'files'
                    FilesFO.new( name, self )
                else
                    super
                end
            end
            
            def fs_filepath() @parent.fs_filepath end
        end 
        
        class FilesFO < VFS::BaseNode
            def each
                super
                File.find(:all).each{ |f| yield f.name }
            end
            
            def resolve( name )
                FileFO.new( name, self )
            end
            
            def exists?() File.exists?( fs_filepath ) end
                
            def directory?() File.directory?( fs_filepath ) end
            
            def meta() VFS::File::Meta.new( self ) end
            
            def fs_filepath() @parent.fs_filepath end
        end
        
        class FileFO < VFS::BaseNode
            def loadData
                @file = File.find_by_name(@name) unless @file
                @file
            end
            
            def file?() true end
            def meta() VFS::File::Meta.new( self ) end
            
            def open( mode="r", &block )
                File.open( fs_filepath, mode, &block )
            end
            
            def fs_filepath
                loc_path = @parent.fs_filepath # + ::File::SEPARATOR + @name
                loc_path += ::File::SEPARATOR unless %r{File::SEPARATOR$} =~ loc_path
                loc_path + @name
            end
        end

        class File < ActiveRecord::Base
            has_many :fileproperties
            validates_uniqueness_of :name
        end

        class FileProperty < ActiveRecord::Base
            belongs_to :file
            belongs_to :property
            validates_uniqueness_of :property_id, :scope => :file_id
        end
        
        class Property < ActiveRecord::Base
            has_many :fileproperties
            validates_uniqueness_of :name
        end
    end
end
    
def create_schema
    ActiveRecord::Schema.define do

      create_table :files, :force => true do |t|
        t.column :id, :integer
        t.column :name, :string
      end

      create_table :fileproperties, :force => true do |t|
        t.column :file_id, :integer
        t.column :property_id, :integer
        t.column :value, :string
      end
      
      create_table :properties, :force => true do |t|
          t.column :id, :integer
          t.column :name, :string
          t.column :value?, :boolean
      end
    end
end
