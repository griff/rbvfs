#!/usr/bin/env ruby
#
#  Created by Brian Olsen on 2006-08-03.
#  Copyright (c) 2006. All rights reserved.
require 'active_record'

module VFS
    module Tagging
        class TagBaseFileObject < BaseFileObject
            def resolve( name )
                TagFileObject.new( @fs, name, self )
            end
        end
    
        class TagFileObject  < TagBaseFileObject
        end
        
        class FilesFO 
            def entries
                File.find(:all).map! {|file| file.name }
            end
            
            def resolve( name )
                FileFO.new( name, self )
            end
        end
        
        class FileFO
            def entries() [] end
            
            def loadData
                @file = File.find_by_name(@name)
            end
        end

        class File < ActiveRecord::Base
            has_many :tags
            validates_uniqueness_of :name
        end

        class Tag < ActiveRecord::Base
            belongs_to :file
            validates_uniqueness_of :name, :scope => :file_id
        end
    end
end
    
def create_schema
    ActiveRecord::Schema.define do

      create_table :files, :force => true do |t|
        t.column :id, :integer
        t.column :name, :string
      end

      create_table :tags, :force => true do |t|
        t.column :file_id, :integer
        t.column :name, :string
        t.column :value, :string
      end
    end
end
