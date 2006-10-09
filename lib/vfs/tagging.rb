#!/usr/bin/env ruby
#
#  Created by Brian Olsen on 2006-08-03.
#  Copyright (c) 2006. All rights reserved.
require 'vfs'
require 'active_record'

module VFS
    module Tagging
        class Node  < VFS::BaseNode
            def initialize( fs, name, parent )
                @fs = fs
                super( name, parent )
            end

            def fs_filepath() @parent.fs_filepath end
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
                yield 'tags'
            end
            
            def meta() VFS::File::Meta.new(self) end
            
            def resolve( name )
                if name == 'files'
                    FilesFO.new( @fs, name, self )
                elsif name == 'tags'
                    TagsFO.new( @fs, name, self )
                else
                    super
                end
            end
            
            def fs_filepath() @filespath end
        end
        
        class TagsFO < Node
            def each
                super
                #TODO yield tags in this folder
            end
            
            def resolve( name )
            end
            
            def exists?() end
            
            def file?() end
            
            def directory?() end
            
            def meta() FileMeta.new( self ) end
        end
        
        class FilesFO < Node
            def each
                super
                File.find(:all).each{ |f| yield f.name }
            end
            
            def resolve( name )
                FileFO.new( @fs, name, self )
            end
            
            def exists?() ::File.exists?( fs_filepath ) end
                
            def directory?() ::File.directory?( fs_filepath ) end
            
            def meta() VFS::File::Meta.new( self ) end
        end
        
        class FileFO < Node
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
            def meta() FileMeta.new( self ) end
            
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
            def namespaces
                ret = super.to_set
                @owner.loadData.properties.find_all.each do |p|
                    namespace = p.namespace
                    ret << [namespace.alias.to_sym, namespace.uri.to_sym]
                end
                ret.to_a
            end
            
            def dynamic_properties( ns )
                ns = ns.to_s
                ret = []
                namespace = Namespace.find_by_uri( ns )
                if namespace
                    ret = @owner.loadData.properties.find_all_by_namespace_id( namespace.id ).map do |p|
                        p.name.to_sym
                    end
#                    ret = ret.to_set.to_a
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
                    create_namespace( ns )
                end
                NopNS.new( prefix, ns, self )
            end
            
            def create_namespace( ns )
                prefix = "Prefix" # TODO find better way to auto generate prefix
                namespace = Namespace.new( :uri => ns, :alias => prefix )
                namespace.save!
                namespace.prefix = "Prefix#{namespace.id}"
                namespace.save!
                return namespace
            end
            
            def lookup( ns, prop )
                namespace = Namespace.find_by_uri( ns )
                return [nil, nil, nil] unless namespace
                property = Property.find_by_name_and_namespace_id( prop, namespace.id )
                return [nil, nil, namespace] unless property
                file_property FileProperty.find_by_file_id_and_property_id( load.id, property.id )
                return [nil, property, namespace] unless file_property
                return [file_property, property, namespace]
            end
            
            def property_checker_missing( ns, prop )
                file_property, property, namespace = lookup( ns, prop )
                return !file_property.nil?
            end

            def property_reader_missing( ns, prop )
                file_property, property, namespace = lookup( ns, prop )
                return super unless file_property
                return file_property.value
            end
            
            def property_writer_missing( ns, prop, value )
                file_property, property, namespace = lookup( ns, prop )
                unless namespace
                    namespace = create_namespace( ns )
                end
                unless property
                    property = Property.new( :namespace_id => namespace.id, :name => prop, :value? => true )
                    property.save!
                end
                unless file_property
                    file_property = FileProperty.new( :file_id => owner.loadData.id, :property_id => property.id )
                end
                file_property.value = value
                file_property.save!
            end
            
            def property_remover_missing( ns, prop )
                file_property, property, namespace = lookup( ns, prop )
                file_property.detroy unless file_property
            end
        end

        class File < ActiveRecord::Base
            has_many :fileproperties
            has_many :properties, :through => :fileproperties
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
#            validates_uniqueness_of :alias
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
            t.column :id, :integer
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