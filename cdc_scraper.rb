require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'elasticsearch'

module Cdc

  module Common

    def initialize(args)
      args.each{|k,v| instance_variable_set("@#{k}",v) }
    end

    def attributes
      Hash[instance_variables.map { |var| [var[1..-1].to_sym, instance_variable_get(var)] }]
    end

    def indexer
      @destination_index ||= DestinationIndexer.new
    end

    def index_name
      self.class.name.downcase
    end
  end

  class Scraper
    include Common
    ROOT_PATH = "http://wwwnc.cdc.gov/travel/"
    DESTINATION_PATH_PREFIX = 'destinations/traveler/children.chronic.cruise_ship.extended_student.immune_compromised.pregnant.mission_disaster.vfr/'

    def self.fetch_travel_notices!
      raise 'unimplemented'
      #RSS: http://wwwnc.cdc.gov/travel/rss/notices.xml
      # EXAMPLE:
      # <title>Alert - MERS in the Arabian Peninsula</title>
      # <description><![CDATA[Cases of MERS (Middle East Respiratory Syndrome) have been identified in multiple countries in the Arabian Peninsula. There have also been cases in several other countries in travelers who have been to the Arabian Peninsula and, in some instances, their close contacts. If you are traveling to countries in or near the Arabian Peninsula,* CDC recommends that you pay attention to your health during and after your trip.]]></description>
      # <link>http://wwwnc.cdc.gov/travel/notices/alert/coronavirus-arabian-peninsula-uk</link>
      # <pubDate>Mon, 12 May 2014 04:00:00 GMT</pubDate>
      # <guid>http://wwwnc.cdc.gov/travel/notices/alert/coronavirus-arabian-peninsula-uk</guid>

      # <link> body includes countries list: "Countries considered in the Arabian Peninsula and neighboring include: Bahrain, Iraq, Iran..."

    end

    def self.fetch_updated_destinations!
      raise 'unimplemented'
      #updated_destinations = something from http://wwwnc.cdc.gov/travel/yellowbook/2014/updates/rss
      # updated_destinations.each do |destination|
      #   fetch_destination_info(destination_name)
      #end
    end

    def self.fetch_all_destinations!
      destinations.each do |destination_name|
        fetch_destination_info(destination_name)
      end
    end

    private

    def self.destinations
      @destinations ||= fetch_destination_list
    end

    def self.fetch_destination_list
      fetch_doc('destinations/list').css('#traveler_destination option').map do |option|
        option.attr('value')
      end
    end

    def self.fetch_doc(document_path)
      Nokogiri::HTML(open(ROOT_PATH + document_path))
    end

    def self.fetch_destination_info(destination_name)
      doc = fetch_doc(DESTINATION_PATH_PREFIX + destination_name)
      destination = Destination.new name: destination_name
      destination.last_updated = Date.parse(doc.css('li.last-updated span').text.strip)
      doc.css('.disease tr').each do |node|
        disease = Disease.new(
          id:      name = node.css('.traveler-disease').text.strip,
          name:    name,
          content: node.css('.traveler-findoutwhy > p').text.strip
        )
        disease.conditions = node.css('.traveler-findoutwhy .population').map do |condition_node|
          {
            population: condition_node.css('.population-header').text.strip,
            content:    condition_node.css('.population-content').text.strip
          }
        end
        disease.index!
        disease.add_destination!(destination)
        destination.index!
      end
    end

  end #Scraper

  class Destination
    include Common
    attr_accessor :id, :name, :last_updated

    def index!
      indexer.index index: DestinationIndexer::ES_INDEX_NAME, type: self.index_name, body: attributes
    end
  end


  class Disease
    include Common
    attr_accessor :id, :name, :content, :conditions

    def indexed?
      indexer.exists index: DestinationIndexer::ES_INDEX_NAME, type: self.index_name, id: id
    end

    def index!
      indexer.index(index: DestinationIndexer::ES_INDEX_NAME, type: self.index_name, body: attributes) unless indexed?
    end

    def add_destination!(destination)
      indexer.update index: DestinationIndexer::ES_INDEX_NAME, type: self.index_name, id: id,
                    body: { script: 'ctx._source.destinations += destination', params: { destination: destination } }
    end
  end


  class DestinationIndexer
    include Elasticsearch::API

    CONNECTION = ::Faraday::Connection.new url: 'http://localhost:9200'
    ES_INDEX_NAME = 'immune_traveler'

    def perform_request(method, path, params, body)
      puts "--> #{method.upcase} #{path} #{params} #{body}"

      CONNECTION.run_request \
        method.downcase.to_sym,
        path,
        ( body ? MultiJson.dump(body): nil ),
        {'Content-Type' => 'application/json'}
    end

    def create_indices!(force)
      puts 'Index already exists' if self.exists(index: ES_INDEX_NAME)
      self.indices.create \
        index: ES_INDEX_NAME,
        body: {
          diseases:{
            properties: {
              name: {type:'string'},
              content: {type:'string'},
              conditions: {
                properties:{
                  name: {type:'string'},
                  content: {type:'string'},
                }
              },
              destinations: {
                properties:{
                  id: {type: 'string'},
                  name: {type:'string'},
                  last_updated: {type:'date'},
                }
              }
            }
          },
          destinations: {
            properties:{
              id: {type: 'string'},
              name: {type:'string'},
              last_updated: {type:'date'},
            }
          },
          log: true
        }
    end
  end

end