require 'sinatra/base'
require 'net/http'
require 'neography'
require 'json'
require 'logger'


class BooodlApi < Sinatra::Base


  configure do
    @@logger = Logger.new(STDERR)
    @@logger.level = Logger::INFO

    Neography.configure do |config|
      config.protocol           = "http://"
      config.server             = "localhost"
      config.port               = 7474
      config.directory          = ""  # prefix this path with '/'
      config.cypher_path        = "/cypher"
      config.gremlin_path       = "/ext/GremlinPlugin/graphdb/execute_script"
      config.log_file           = "neography.log"
      config.log_enabled        = false
      config.slow_log_threshold = 0    # time in ms for query logging
      config.max_threads        = 20
      config.authentication     = nil  # 'basic' or 'digest'
      config.username           = nil
      config.password           = nil
      config.parser             = MultiJsonParser
    end
  end

  get '/' do
    # return json-api document containing links for root resources

    res = { :@links => {
              :self => { :href => "/" },
              :login => { :href => "/users" },
              :users => { :href => "/users" },
              :cards => { :href => "/cards" },
              :things => { :href => "/things" },
              :platform => { :href => "/platform" }
            }
            }.to_json


    #    "reached /"
  end

  get '/users' do
    # default response - proxy request to Elastic Search

    
    querystring = params[:q] || "*"
    uri = URI.parse("http://ec2-54-81-13-149.compute-1.amazonaws.com:9200/users/user/_search?q=" + querystring)
    res = api_request(:get, uri, nil)

    # map into hypermedia response


    # @neo = Neography::Rest.new
    # users = @neo.get_nodes_labeled("User")
    # result = { :users => []}
    # users.each do |user|
    #   result[:users] << { :id => user["data"]["id"],
    #                       :name => user["data"]["display_name"],
    #                       :@links => {
    #                         :self => { :href => "http://localhost:5000/users/"+ user["data"]["id"]}
    #                       }
    #                       }
    # end
     res.body
    
  end

  post '/users' do 

    request.body.rewind
    ud = JSON.parse(request.body.read,{:symbolize_names => true})
    # TODO: validate ud contains required fields
    
    # wrap this is a try block?
    user_node = Neography::Node.create( "id" => ud[:id],
                                        "username" => ud[:username],
                                        "display_name" => ud[:display_name],
                                        "profile_photo_s3id" => ud[:profile_photo_s3id],
                                        "bio_statement" => ud[:bio_statement],
                                        "location" => ud[:location],
                                        "user_type" => ud[:user_type] )
    user_node.add_to_index("user_index", "id", ud[:id])
    @neo.add_label(user_node, "User")


    add_node_to_graph("User", "")
    publish(BooodlEvent.new('created_user'))

    201

  end

  get 'users/recommendations' do
    # return a set of recommended cards for anonymous users
    "set of recommended cards for anonymous users"
  end

  get '/users/:userid' do

    @neo = Neography::Rest.new
    # user = Neography::Node.load(4)
    BoodlAPI.logger.info(@neo.list_node_indexes)
    BoodlAPI.logger.info("Userid: " + params[:userid] + " of type " + params[:userid].class.to_s)
    res = Neography::Node.find("user_index", "id", params[:userid])
    unless res.instance_of?(Array) then user = [res] end
    BoodlAPI.logger.info("Found: " + user.to_s)
    result = { :users => []}
    result[:users] << { :id => user[0].id,
                        :name => user[0].display_name,
                        :@links => {
                          :self => { :href => "http://localhost:5000/users/" + user[0].id}
                        }
                        }
    result.to_json

  end

  get 'users/:userid/recommendations' do
    # set of recemmended cards for a known user
    "set of recmmended cards for a known user"
  end

  get '/users/:userid/cards' do

  end

  def api_request(method, uri, body)

    req = nil
    case method
    when :get
      req = Net::HTTP::Get.new(uri)
    when :put
      req = Net::HTTP::Put.new(uri)
    when :post
      req = Net::HTTP::Post.new(uri)
    else
      return :error
    end
    req.body = body
    req.set_content_type("application/json")

    if req.uri.scheme == "https" then
      res = Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.ssl_version = :SSLv3
        http.request req
      end
    else
      res = Net::HTTP.start(uri.host, uri.port, :use_ssl => false) do |http|
        http.request req
      end
    end



  end

end
