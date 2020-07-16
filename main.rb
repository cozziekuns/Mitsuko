require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'

get '/' do
  haml :index
end

post '/' do
  @hand_string = params["hand"]
  @call_string = params["calls"]
  @dora_string = params["dora"]
  @yaku_string = params["yaku"]

  haml :result
end