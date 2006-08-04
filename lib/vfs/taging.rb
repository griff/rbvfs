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
    
        class Node  < BaseNode
        end
        
        class FilesFO < BaseNode 
            def each(&block)
                File.find(:all).each(&block)
            end
            
            def resolve( name )
                FileFO.new( name, self )
            end
        end
        
        class FileFO
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
