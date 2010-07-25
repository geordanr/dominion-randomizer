require 'rubygems'
require 'sinatra/base'
require 'lib/card'
require 'haml'
require 'json'

class Array # I ought to subclass this into a deck but eh
  def draw(n)
    # Draw n cards from the deck.
    slice!(0, n)
  end

  def require_potions!(min_alchemy_cards, deck)
    # Returns set of cards required to satisfy this requirement.

    return [] unless min_alchemy_cards and min_alchemy_cards > 0

    # Is there at least one potion card in the spread?
    potion_cards = select {|card| card.cost and card.cost.has_key?('potions') and card.cost['potions'] > 0}
    if potions_cards.size < min_alchemy_cards
      diff = min_alchemy_cards - potions_cards.size
      # Randomly throw out the right number of cards from the leftover
      rejectable = self - potion_cards
      rejectable.draw(diff)
      # Add eligible cards from the rest of the deck
      new_alchemy_cards = deck.select{|card|card.source == 'Alchemy'}.draw(diff)
      push(*new_alchemy_cards)
    end
    potion_cards + new_alchemy_cards
  end
end

class DominionApp < Sinatra::Base
  SPREAD_SIZE = 10

  use Rack::Static, :urls => ['/images', '/js', '/jqtouch', '/themes'], :root => 'public'

  enable :sessions

  helpers do
    def starting_player(n)
      1 + rand(n)
    end

    def shape(deck)
      # Remove any banned things
      @sources.each_pair do |source, allow|
        deck -= Card.by_source(:key => source) unless allow
      end
      deck -= @banned_cards
    end

    def ban_card_id(c_id)
      session[:banned_card_ids] << c_id
    end

    def unban_card_id(c_id)
      session[:banned_card_ids].delete(c_id)
    end

    def ban_source(source)
      session[:sources][source] = false
    end

    def unban_source(source)
      session[:sources][source] = true
    end

    def spread_cards
      session[:spread].map{|c_id|Card.get(c_id)}
    end
  end

  before do
    # Hack: ensure /dominion is in the PATH_INFO, since we're serving from
    # Passenger's RackBaseURI.
    request.env['PATH_INFO'].sub!(/^/, '/dominion') unless request.env['PATH_INFO'] =~ /^\/dominion/
    session[:spread] ||= []
    unless session[:sources]
      session[:sources] = {}
      Card.by_source(:reduce=>true, :group_level=>1)['rows'].map{|h|h['key']}.each do |source|
        unban_source(source)
      end
    end
    @sources = session[:sources]
    session[:banned_card_ids] ||= []
    @banned_cards = session[:banned_card_ids].map{|c_id|Card.get(c_id)}
  end

  get '/dominion/?' do
    @title = 'Dominion Randomizer'
    haml :index
  end

  get '/dominion/cards/?', :layout => false do
    session[:spread] = [] if params[:refresh]

    if session[:spread].empty?
      deck = shape(Card.all)
      deck.shuffle!
      # Take the first 10 cards as the prospective deck.
      spread = deck.draw(SPREAD_SIZE)
    else
      spread = spread_cards

      # Remove any newly banned cards.
      spread = shape(spread)

      if spread.size < SPREAD_SIZE
        # Only create and shape the deck if we actually need to draw cards.
        deck = shape(Card.all)
        # Remove existing cards from the deck.
        deck -= spread
        deck.shuffle!
        spread += deck.draw(SPREAD_SIZE - spread.size)
      end
    end

    required_cards = []
    required_cards += spread.require_potions!(session[:min_alchemy_cards], deck)

    # Save the spread (as card IDs)
    session[:spread] = spread.map{|c|c.id}

    @spread = spread.sort_by {|c| c.name}
    spread_cards.sort_by {|c| c.name}.to_json
  end

  get '/dominion/cards/bans/?', :layout => false do
    @banned_cards.sort_by{|c| c.name}.to_json
  end

  post '/dominion/cards/ban/:card_id', :layout => false do |banned|
    ban_card_id(banned)
    {'status' => 'OK', 'banned' => Card.get(banned)}.to_json
  end

  post '/dominion/cards/unban/:card_id', :layout => false do |unbanned|
    unban_card_id(unbanned)
    {'status' => 'OK', 'unbanned' => Card.get(unbanned)}.to_json
  end

  get '/dominion/expansions/?', :layout => false do
    @sources.to_json
  end

  post '/dominion/expansions/ban/:source', :layout => false do |banned|
    ban_source(banned)
    {'status' => 'OK', 'banned' => banned}.to_json
  end

  post '/dominion/expansions/unban/:source', :layout => false do |unbanned|
    unban_source(unbanned)
    {'status' => 'OK', 'unbanned' => unbanned}.to_json
  end

end
