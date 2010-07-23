#log = File.new('log/sinatra.log', 'a')
#STDOUT.reopen(log)
#STDERR.reopen(log)

require 'dominion'
run DominionApp
