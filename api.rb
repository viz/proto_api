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
    result[:users] << { :id => user["data"]["userid"],
    	                :name => user["data"]["name"],
                        :self => "http://localhost:5000/users/"+ /\d+$/.match(user["self"])[0]}
  end
  result.to_json

end

get '/users/:userid' do
@logger = Logger.new(STDOUT)
@logger.level = Logger::INFO

  @neo = Neography::Rest.new
  user = Neography::Node.load(4)
 result = { :users => []}
  result[:users] << { :id => user.userid,
    	                :name => user.name,
                        :self => "http://localhost:5000/users/" + user.neo_id}
  result.to_json

end

get '/users/:userid/items' do

end

get 'users/:userid/items?rel=:relationship' do

end

get 'users/:userid/items?coll=:collectionid' do

end

get 'users/:userid/items?tags=:tags' do

end

get '/users/:userid/items/:itemid' do

end

get '/items' do

end

get '/items/:id' do

end


