require 'rubygems'
require 'sinatra/base'
require 'lib/card'

class DominionApp < Sinatra::Base
  set :sessions, true

  helpers do
    def starting_player(n)
      1 + rand(n)
    end
  end

  get '/' do
    @title = 'Dominion Randomizer'
    @css_path = '/css/iphone.css'
    @banned_sources = session[:banned_sources] || []
    @banned_cards = session[:banned_card_ids] || []

    if session[:spread] and not session[:spread].empty?
      spread = session[:spread].map{|c_id|Card.get(c_id)}
    else
      deck = Card.all

      # Remove any banned things
      @banned_sources.each do |source|
        deck -= Card.by_source(:key => source)
      end
      @banned_cards.map!{|c_id|Card.get(c_id)}
      deck -= @banned_cards

      deck.shuffle!

      # Take the first 10 cards as the prospective deck.
      spread = deck.slice!(0, 10)

      # Do we care about potions?
      if session[:min_alchemy_cards]
        requires_potion = Proc.new {|card| card.cost and card.cost.has_key?('potions') and card.cost['potions'] > 0}
        # Is there at least one potion card in the spread?
        potion_cards = spread.select(&requires_potion)
        if potions_cards.size < session[:min_alchemy_cards]
          diff = session[:min_alchemy_cards] - potions_cards.size
          # Randomly throw out the right number of cards from the leftover
          rejectable = spread - potion_cards
          rejectable.slice!(0, diff)
          # Add eligible cards from the rest of the deck
          spread += deck.select(&requires_potion).slice(0,diff)
        end
      end

      session[:spread] = spread.map{|c|c.id}
    end

    @cards = spread.sort_by {|c| c.name}
    @sources = Card.by_source(:reduce=>true, :group_level=>1)['rows'].map{|h|h['key']} - @banned_sources

    haml :index
  end

  get '/refresh' do
    session[:spread] = []
    redirect '/'
  end

  get '/ban_card/:card_id' do |banned|
    redirect '/'
  end

  get '/unban_card/:card_id' do |unbanned|
    redirect '/'
  end

  get '/ban_source/:source' do |banned|
    redirect '/'
  end

  get '/unban_source/:source' do |unbanned|
    redirect '/'
  end

end
