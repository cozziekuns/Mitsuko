require 'sinatra'
require 'sinatra/reloader' if development?

get '/' do
  return "Hello World!"
end
