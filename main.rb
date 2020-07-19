require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'

require_relative './parser.rb'
require_relative './simulate.rb'

get '/' do
  haml :index
end

post '/' do
  env_variables = {}

  begin
    hand = Parser.parse_hand_string(params["hand"])
  rescue Exception
    return "INVALID HAND INPUT"
  end

  begin
    calls = Parser.parse_hand_string(params["calls"])
  rescue Exception
    return "INVALID CALL INPUT"
  end

  begin
    dora = Parser.parse_hand_string(params["dora"])
  rescue Exception
    return "INVALID DORA INPUT"
  end

  env_variables[:hand] = params["hand"]
  env_variables[:calls] = params["calls"]
  env_variables[:dora] = params["dora"]
  env_variables[:yaku] = params["yaku"]

  results = get_results(hand, calls, dora, params["yaku"])
  env_variables.update(results)

  # perform_validation(hand, calls, dora)

  haml :result, locals: env_variables
end

def get_results(hand, calls, dora, yaku)
  results = {}

  # TODO: We're only doing chiitoi for now
  node = ConfigurationNode_Chiitoi.new(hand)

  results[:tsumo_rates] = get_tsumo_rates(node)
  results[:tenpai_rates] = get_tsumo_rates(node, 1)

  return results
end

def get_tsumo_rates(node, end_shanten = 0)
  memo = {}
  Simulator.simulate(node, 18, end_shanten, memo)

  normalized_values = memo[node][1..-1].reverse.map { |val| val.nil? ? 0 : val }
  percent_strings = normalized_values.map { |val| "%2.3f" % [val * 100] + "%" }

  return percent_strings
end