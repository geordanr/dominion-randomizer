require 'rubygems'
require 'sinatra/base'
require 'lib/card'

class Array
  def draw(n)
    # Draw n cards from the deck.
    slice!(0, n)
  end
end

class DominionApp < Sinatra::Base
  SPREAD_SIZE = 10

  use Rack::Static, :urls => ['/images'], :root => 'public'

  enable :sessions

  helpers do
    def starting_player(n)
      1 + rand(n)
    end

    def shape(deck)
      # Remove any banned things
      @banned_sources.each do |source|
        deck -= Card.by_source(:key => source)
      end
      deck -= @banned_cards
    end
  end

  before do
    session[:spread] ||= []
    session[:banned_sources] ||= []
    @banned_sources = session[:banned_sources]
    session[:banned_card_ids] ||= []
    @banned_cards = session[:banned_card_ids].map{|c_id|Card.get(c_id)}
  end

  get '/' do
    @title = 'Dominion Randomizer'
    @css_path = '/css/iphone.css'
    @use_jquery = true

    if session[:spread].empty?
      deck = shape(Card.all)
      deck.shuffle!
      # Take the first 10 cards as the prospective deck.
      spread = deck.draw(SPREAD_SIZE)
    else
      spread = session[:spread].map{|c_id|Card.get(c_id)}

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

    # Do we care about potions?
    if session[:min_alchemy_cards]
      # Is there at least one potion card in the spread?
      potion_cards = spread.select {|card| card.cost and card.cost.has_key?('potions') and card.cost['potions'] > 0}
      if potions_cards.size < session[:min_alchemy_cards]
        diff = session[:min_alchemy_cards] - potions_cards.size
        # Randomly throw out the right number of cards from the leftover
        rejectable = spread - potion_cards
        rejectable.draw(diff)
        # Add eligible cards from the rest of the deck
        spread += deck.select{|card|card.source == 'Alchemy'}.draw(diff)
      end
    end

    # Save the spread (as card IDs)
    session[:spread] = spread.map{|c|c.id}

    @cards = spread.sort_by {|c| c.name}
    @sources = Card.by_source(:reduce=>true, :group_level=>1)['rows'].map{|h|h['key']} - @banned_sources

    haml :index
  end

  get '/refresh' do
    session[:spread] = []
    redirect '/'
  end

  get '/cards/?' do
    redirect '/'
  end

  get '/cards/ban/:card_id' do |banned|
    session[:banned_card_ids] << banned
    redirect '/'
  end

  get '/cards/unban/:card_id' do |unbanned|
    session[:banned_card_ids].delete(unbanned)
    redirect '/'
  end

  get '/expansions/?' do
    redirect '/'
  end

  get '/expansions/ban/:source' do |banned|
    session[:banned_sources] << banned
    redirect '/'
  end

  get '/expansions/unban/:source' do |unbanned|
    session[:banned_sources].delete(unbanned)
    redirect '/'
  end

  get '/css/?' do
    redirect '/'
  end

  get '/css/:style.css' do |style|
    sass style.to_sym
  end

end
