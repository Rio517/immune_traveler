require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'elasticsearch'


class CdcSpider

  DEFAULT_PATH = "http://wwwnc.cdc.gov/travel/"
  DESTINATION_SUB_PATH = 'destinations/traveler/children.chronic.cruise_ship.extended_student.immune_compromised.pregnant.mission_disaster.vfr/'

  def fetch_travel_notices!
    #RSS: http://wwwnc.cdc.gov/travel/rss/notices.xml
  end

  def fetch_updated_destinations!
    #http://wwwnc.cdc.gov/travel/yellowbook/2014/updates/rss
    # fetch_destination_info()
  end

  def fetch_all_destinations!
    destinations.each do |destination|
      fetch_destination_info(destination)
    end
  end

  private

  def indexer
    @destination_index ||= DestinationIndexer.new
  end

  def destinations
    @destinations ||= fetch_destination_list
  end

  def fetch_destination_list
    doc = fetch_doc('destinations/list')
    doc.css('#traveler_destination option').map do |option|
      option.attr('value')
    end
  end

  def fetch_doc(sub_path)
    Nokogiri::HTML(open(DEFAULT_PATH + sub_path))
  end

  def fetch_destination_info(destination)
    doc = fetch_doc(destination_SUB_PATH + destination)
    last_updated = Date.parse(doc.css('li.last-updated span').text.strip)
    diseases_collection = doc.css('.disease tr').each_with_object({}) do |node,diseases|
      diseases[:name] = node.css('.traveler-disease').text.strip
      diseases[:content] = node.css('.traveler-findoutwhy > p').text.strip
      diseases[:conditions] = node.css('.traveler-findoutwhy .population').each_with_object({}) do |inner_node,conditions|
        conditions[:population] = inner_node.css('.population-header').text.strip
        conditions[:content] = inner_node.css('.population-content').text.strip
      end
    end

    indexer.index! name: destination, diseases: diseases_collection, last_updated: last_updated
  end

end


class DestinationIndexer
  include Elasticsearch::API
  ES_INDEX_NAME = 'immune_traveler'

  CONNECTION = ::Faraday::Connection.new url: 'http://localhost:9200'

  def perform_request(method, path, params, body)
    puts "--> #{method.upcase} #{path} #{params} #{body}"

    CONNECTION.run_request \
      method.downcase.to_sym,
      path,
      ( body ? MultiJson.dump(body): nil ),
      {'Content-Type' => 'application/json'}
  end

  def create_index!
    self.indices.create \
      index: ES_INDEX_NAME,
      body: {
        destination: {
          properties:{
            name: {type:'string'},
            last_updated: {type:'datetime'},
            diseases:{
              properties: {
                name: {type:'string'},
                content: {type:'string'},
                conditions: {
                  properties:{
                    name: {type:'string'},
                    content: {type:'string'},
                  }
                }
              }
            }
          }
        },
        log: true
        }
      #unless already created
  end

  def index!(content)
    self.index index: ES_INDEX_NAME, type: 'destination', body: content
  end

end