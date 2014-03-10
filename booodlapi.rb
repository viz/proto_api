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
              :login => { :href => "/login" },
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


    # querystring = params[:q] || "*"
    # uri = URI.parse("http://ec2-54-81-13-149.compute-1.amazonaws.com:9200/users/user/_search?q=" + querystring)
    # res = api_request(:get, uri, nil)

    # map into hypermedia response


    @neo = Neography::Rest.new
    # users = @neo.get_nodes_labeled("User")
    # need to sanitise parameters to prevent DB Injection
    start = params[:start] || "0"
    num = params[:num] || "50"

    users_result = @neo.execute_query("match (u:User) return u skip " + start + " limit " + num)
    @@logger.info("params: " + params.to_s)
    result = { :users => [],
               :@links => {
                 :self => { :href => "http://localhost:5000/users?start=" + start + "&num=" + num}
    }}
    users_result["data"].each do |user|
      # need to be able to include links for pagination and page number that aren't in the users array
      result[:users] << { :id => user[0]["data"]["id"],
                          :name => user[0]["data"]["display_name"],
                          :@links => {
                            :self => { :href => "http://localhost:5000/users/"+ user[0]["data"]["id"]}
                          }
                          }
    end
    unless start.to_i < num.to_i then
      result[:@links][:prev] = { :href => "http://localhost:5000/users?start=" + (start.to_i - num.to_i).to_s + "&num=" + num}
    else if start.to_i > 0 then
      result[:@links][:prev] = { :href => "http://localhost:5000/users?start=0&num=" + num}
    end
    end
  # not yet handling how many results there are
  result[:@links][:next] = { :href => "http://localhost:5000/users?start=" + (start.to_i + num.to_i).to_s + "&num=" + num}
  result.to_json


  # res.body

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
  @@logger.info(@neo.list_node_indexes)
  @@logger.info("Userid: " + params[:userid] + " of type " + params[:userid].class.to_s)
  res = Neography::Node.find("user_index", "id", params[:userid])
  unless res.instance_of?(Array) then user = [res] end
  @@logger.info("Found: " + user.to_s)
  result = { :users => []}
  result[:users] << { :id => user[0].id,
                      :name => user[0].display_name,
                      :@links => {
                        :self => { :href => "http://localhost:5000/users/" + user[0].id}
                      }
                      }
  result.to_json
end

get '/users/:userid/recommendations' do
  # set of recemmended cards for a known user
  @neo = Neography::Rest.new
  recs_result = @neo.execute_query( "match (u1:User{id:\"" + params[:userid] + "\"})-[:collected|created]->(c1:Card) match (c1)-[:describes*]-(c2:Card) match (c2)<-[:collected|created]-(u2:User) with u1,u2,count(c1) as intersection order by intersection desc limit 5 match (u2)-[:collected|created]->(c3:Card) where not (u1)-[:collected|created]->()-[:describes*]-(c3) return c3 limit 10")
  @@logger.info("recommended cards: " + recs_result["data"].to_s)
  result = { :recommended_cards => []}
  recs_result["data"].each do |card|
    # need to be able to include links for pagination and page number that aren't in the users array
    result[:recommended_cards] << { :id => card[0]["data"]["id"],
                                    :title => card[0]["data"]["title"],
                                    :description => card[0]["data"]["description"],
                                    :@links => {
                                      :self => { :href => "http://localhost:5000/cards/"+ card[0]["data"]["id"]}
                                    }
                                    }
  end
  result.to_json
end

get '/users/:userid/cards' do
  @neo = Neography::Rest.new
  recs_result = @neo.execute_query( "match (u1:User{id:\"" + params[:userid] + "\"})-[:collected|created]->(c1:Card)  return c1 ")
  @@logger.info("user's cards: " + recs_result.to_s)
  result = { :cards => []}
  recs_result["data"].each do |card|
    # need to be able to include links for pagination and page number that aren't in the users array
    result[:cards] << { :id => card[0]["data"]["id"],
                        :title => card[0]["data"]["title"],
                        :description => card[0]["data"]["description"],
                        :@links => {
                          :self => { :href => "http://localhost:5000/cards/"+ card[0]["data"]["id"]}
                        }
                        }
  end
  result.to_json

  # "cards for user"

end

get '/cards/:cardid' do

  @neo = Neography::Rest.new
  # user = Neography::Node.load(4)
  res = Neography::Node.find("card_index", "id", params[:cardid])
  unless res.instance_of?(Array) then card = [res] end
  @@logger.info("Found: " + card.to_s)
  result = { :cards => []}
  result[:cards] << { :id => card[0].id,
                      :title => card[0].title,
                      :description => card[0].description,
                      :@links => {
                        :self => { :href => "http://localhost:5000/cards/" + card[0].id}
                      }
                      }
  result.to_json
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
