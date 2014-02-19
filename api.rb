require 'sinatra'
require 'neography'
require 'json'
require 'logger'

@logger = Logger.new(STDOUT)
@logger.level = Logger::INFO



configure do
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
	"reached /"
end
	
get '/users' do
  @neo = Neography::Rest.new
  users = @neo.get_nodes_labeled("User")
  result = { :users => []}
  users.each do |user|
    result[:users] << { :id => user["data"]["id"],
    	                :name => user["data"]["display_name"],
                        :@links => {
                        :self => { :href => "http://localhost:5000/users/"+ user["data"]["id"]}
                        }
                      }
  end
  result.to_json
end

post '/users' do
  @logger = Logger.new(STDERR)
  @logger.level = Logger::INFO
  @neo = Neography::Rest.new

  request.body.rewind
  ud = JSON.parse(request.body.read,{:symbolize_names => true})
 user_node = Neography::Node.create( "id" => ud[:id],
                                      "username" => ud[:username],
                                      "display_name" => ud[:display_name],
                                      "profile_photo_s3id" => ud[:profile_photo_s3id],
                                      "bio_statement" => ud[:bio_statement],
                                      "location" => ud[:location],
                                      "user_type" => ud[:user_type] )
 user_node.add_to_index("user_index", "id", ud[:id])
 @neo.add_label(user_node, "User")
 "posted user"
end

get '/users/index' do
  @neo = Neography::Rest.new
  @neo.create_schema_index("User","id")
  "I think I created an index"
end


get '/users/:userid' do
@logger = Logger.new(STDERR)
@logger.level = Logger::INFO

  @neo = Neography::Rest.new
 # user = Neography::Node.load(4)
  @logger.info(@neo.list_node_indexes)
  @logger.info("Userid: " + params[:userid] + " of type " + params[:userid].class.to_s)
  res = Neography::Node.find("user_index", "id", params[:userid])
  unless res.instance_of?(Array) then user = [res] end
  @logger.info("Found: " + user.to_s)
  result = { :users => []}
  result[:users] << { :id => user[0].id,
    	                :name => user[0].display_name,
                        :@links => {
                          :self => { :href => "http://localhost:5000/users/" + user[0].id}
                        }
                      }
  result.to_json

end

get '/users/:userid/cards' do

end

