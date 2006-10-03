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
            
            def meta() VirtualMeta.new(self) end
            
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
            
            def exists?() ::File.exists?( fs_filepath ) end
                
            def directory?() ::File.directory?( fs_filepath ) end
            
            def meta() VFS::File::Meta.new( self ) end
            
            def fs_filepath() @parent.fs_filepath end
        end
        
        class FileFO < VFS::BaseNode
            def loadData
                @file = File.find_by_name(@name) unless @file
                @file
            end
            
            def exists?
                loadData.nil?
            end
            
            def delete
                if loadData
                    @file.destroy
                    @file = nil
                end
            end
            
            def file?() exists? end
            def meta() VFS::File::Meta.new( self ) end
            
            def open( mode="r", &block )
                ::File.open( fs_filepath, mode, &block )
            end

            def blksize
                ::File.blksize( fs_filepath )
            end
            
            def fs_filepath
                VFS.fs_filepath( @parent, @name )
            end
        end
        
        class NopNS < VFS::Meta::Namespace
            attr_reader :namespace, :prefix
            def initialize( prefix, ns, meta )
                super(meta)
                @prefix = prefix
                @namespace = ns
            end
        end
        
        class FileMeta < VFS::BaseMeta
            def loadData
                if !@properties
                    @properties = @owner.loadData.fileproperties.map{ |p| 
                        property = p.property
                        namespace = property.namespace
                        [ namespace.alias, namespace.uri, property.name, property.value? ? p.value : nil  ]
                    }
                end
                @properties
            end
            
            def namespaces
                super | #Loaded from db
            end
            
            def dynamic_properties( ns )
                ns = ns.to_s
                ret = []
                @owner.loadData.fileproperties.each do |p|
                    property = p.property
                    ret << property.name.to_sym if property.namespace.uri == ns
                end
                ret
            end

            def namespace_missing( prefix, ns )
                if prefix
                    namespace = Namespace.find_by_alias( prefix )
                else
                    namespace = Namespace.find_by_uri( ns )
                end
                if namespace
                    prefix = namespace.alias.to_sym unless prefix
                    ns = namespace.uri.to_sym unless ns
                else
                    raise NameError unless ns
                    #TODO auto generate prefix
                end
                NopNS.new( prefix, ns, self )
            end
            
            def property_checker_missing( ns, prop )
                namespace = Namespace.find_by_uri( ns )
                return super unless namespace
            end

            def property_reader_missing( ns, prop )
            end
            
            def property_writer_missing( ns, prop, value )
            end
            
            def property_remover_missing( ns, prop )
            end
        end

        class File < ActiveRecord::Base
            has_many :fileproperties
            validates_uniqueness_of :name
            before_destroy { |record| FileProperty.destroy_all "file_id = #{record.id}"   }
        end

        class FileProperty < ActiveRecord::Base
            belongs_to :file
            belongs_to :property
            validates_uniqueness_of :property_id, :scope => :file_id
        end
        
        class Property < ActiveRecord::Base
            has_many :fileproperties
            belongs_to :namespace
            validates_uniqueness_of :name
        end
        
        class Namespace < ActiveRecord::Base
            has_many :properties
            validates_uniqueness_of :alias
            validates_uniqueness_of :uri
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
            t.column :namespace_id, :integer
            t.column :name, :string
            t.column :value?, :boolean
        end
      
        create_table :namespaces, :force => true do |t|
            t.column :id, :integer
            t.column :alias, :string
            t.column :uri, :string
        end
    end
end
# vim: sts=4:sw=4:ts=4:et