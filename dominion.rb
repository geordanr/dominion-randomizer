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
    #warn "Requiring #{min_alchemy_cards} Alchemy cards"

    # Is there at least one potion card in the spread?
    potion_cards = select {|card| card.cost and card.cost.has_key?('potions') and card.cost['potions'] > 0}
    #warn "Potion cards in spread:\n#{potion_cards.map{|c|c.name}.join("\n")}"
    alchemy_cards = select {|card| card.source == 'Alchemy'}
    #warn "Alchemy cards in spread:\n#{alchemy_cards.map{|c|c.name}.join("\n")}"
    kept_cards = Set.new(potion_cards + alchemy_cards).to_a
    #warn "Keeping cards in spread:\n#{kept_cards.map{|c|c.name}.join("\n")}"
    replacements = []
    if not potion_cards.empty? and (kept_cards.size < min_alchemy_cards)
      # Need this many cards, potentially.
      diff = min_alchemy_cards - kept_cards.size
      #warn "Need #{diff} new Alchemy cards"

      # Get as many eligible new cards as possible (some may have been banned)
      eligible = deck.select{|card|card.source == 'Alchemy'}
      #warn "#{eligible.size} Alchemy cards remain in the deck"

      num_new_cards = (eligible.size < diff) ? eligible.size : diff
      #warn "#{num_new_cards} available for us to draw"
      new_alchemy_cards = eligible.draw(num_new_cards)
      #warn "New alchemy cards:\n#{new_alchemy_cards.map{|c|c.name}.join("\n")}"

      # Throw out as many rejectable cards as we can
      rejectable = self - kept_cards
      #warn "Eligible for discard from spread:\n#{rejectable.map{|c|c.name}.join("\n")}"
      rejectable.shuffle!
      rejected = rejectable.draw(num_new_cards)
      rejected.each {|card| delete(card)} # wish I could -= in here
      #warn "Discarded from spread:\n#{rejected.map{|c|c.name}.join("\n")}"

      # Replace them
      replacements = new_alchemy_cards.draw(rejected.size)
      #warn "Replaced with:\n#{replacements.map{|c|c.name}.join("\n")}"

      push(*replacements)
    end
    kept_cards + replacements
  end
end

class DominionApp < Sinatra::Base
  SPREAD_SIZE = 10

  use Rack::Static, :urls => ['/images', '/js', '/jqtouch', '/themes'], :root => 'public'

  use Rack::Session::Cookie, :key => 'rack.session.dominion',
                             :domain => 'wuut.net',
                             :path => '/dominion',
                             :expire_after => 10*365*24*60*60 # 10 years!

  helpers do
    def starting_player(n)
      1 + rand(n)
    end

    def shape(deck)
      # Remove any banned things
      @sources.each_pair do |source, allow|
        unless allow
          Card.by_source(:key => source).each do |card|
            deck.reject!{|c|c.id == card.id}
          end
        end
      end
      @banned_cards.each do |card|
        deck.reject!{|c|c.id == card.id}
      end
      deck
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

    deck = shape(Card.all)

    if session[:spread].empty?
      deck.shuffle!
      # Take the first 10 cards as the prospective deck.
      spread = deck.draw(SPREAD_SIZE)
    else
      spread = spread_cards
      deck -= spread

      # Remove any newly banned cards.
      spread = shape(spread)

      if spread.size < SPREAD_SIZE
        # Remove existing cards from the deck.
        deck.shuffle!
        spread += deck.draw(SPREAD_SIZE - spread.size)
      end
    end

    required_cards = []
    required_cards += spread.require_potions!(session[:min_alchemy_cards], deck)

    # Save the spread (as card IDs)
    session[:spread] = spread.map{|c|c.id}

    @spread = spread.sort_by {|c| c.name}
    if session[:spread_sort] == 'expansion'
      spread_cards.sort_by {|c| c.source + c.name}.to_json
    else
      spread_cards.sort_by {|c| c.name}.to_json
    end
  end

  post '/dominion/cards/sort/:by', :layout => false do |by|
    case by
    when 'expansion'
      session[:spread_sort] = 'expansion'
    when 'name'
      session[:spread_sort] = 'name'
    else
      session[:spread_sort] = 'name'
    end
    {'status' => 'OK', 'sort' => session[:spread_sort]}.to_json
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

  post '/dominion/alchemy/min/:n', :layout => false do |n|
    session[:min_alchemy_cards] = n.to_i
    {'status' => 'OK', 'min_alchemy_cards' => n.to_i}.to_json
  end

  get '/dominion/config', :layout => false do
    {
      'alchemy_min_cards' => session[:min_alchemy_cards],
      'sort_by' => session[:spread_sort],
    }.to_json
  end

end
