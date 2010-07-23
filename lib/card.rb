require 'rubygems'
require 'couchrest'
require 'set'

DB = CouchRest.database!('http://127.0.0.1:5984/dominion')

class Card < CouchRest::ExtendedDocument
  use_database DB

  view_by :keywords,
    :map => %q{
      function (doc) {
        if (doc.keywords) {
          doc.keywords.forEach(function(k){
            emit(k, null);
          });
        }
      }
    }

  view_by :source,
    :map => %q{
      function (doc) {
        if (doc.source) {
          emit(doc.source, null);
        }
      }
    },
    :reduce => %q{
      function (keys, values, rereduce) {
        return true;
      }
    }
  view_by :cost
  view_by :name
  view_by :actions
  view_by :cards

  property :name
  property :keywords, :cast_as => ['String']
  property :cost # { coins, potions }
  property :actions
  property :cards
  property :coins
  property :buys
  property :text
  property :source

  def unique_keywords
    self['keywords'] = Set.new(keywords).to_a
  end

  before_save :unique_keywords
end

class Array
  def shuffle!
    size.downto(1) { |n| push delete_at(rand(n)) }
    self
  end
end

def setup_views
  Card.by_keywords
  Card.by_source
  Card.by_cost
  Card.by_name
  Card.by_actions
  Card.by_cards
end

def init_cards
  cards = {
    'Dominion' => {
      'Adventurer' => {:type => ['Action'],},
      'Bureaucrat' => {:type => ['Action'],},
      'Cellar' => {:type => ['Action'],},
      'Chancellor' => {:type => ['Action'],},
      'Chapel' => {:type => ['Action'],},
      'Council Room' => {:type => ['Action'],},
      'Feast' => {:type => ['Action'],},
      'Festival' => {:type => ['Action'],},
      'Gardens' => {:type => ['Victory'] },
      'Laboratory' => {:type => ['Action'],},
      'Library' => {:type => ['Action'],},
      'Market' => {:type => ['Action'],},
      'Militia' => {:type => ['Action', 'Attack']},
      'Mine' => {:type => ['Action'],},
      'Moat' => {:type => ['Action', 'Reaction', 'Defense']},
      'Monkeylender' => {:type => ['Action'],},
      'Remodel' => {:type => ['Action'],},
      'Smithy' => {:type => ['Action'],},
      'Spy' => {:type => ['Action', 'Attack']},
      'Thief' => {:type => ['Action', 'Attack']},
      'Throne Room' => {:type => ['Action'],},
      'Village' => {:type => ['Action'],},
      'Witch' => {:type => ['Action', 'Attack']},
      'Woodcutter' => {:type => ['Action'],},
      'Workshop' => {:type => ['Action'],},
    },
    'Intrigue' => {
      'Baron' => {:type => ['Action'],},
      'Bridge' => {:type => ['Action'],},
      'Conspirator' => {:type => ['Action'],},
      'Coppersmith' => {:type => ['Action'],},
      'Courtyard' => {:type => ['Action'],},
      'Duke' => {:type => ['Victory'] },
      'Great Hall' => {:type => ['Action', 'Victory']},
      'Harem' => {:type => ['Treasure','Victory']},
      'Ironworks' => {:type => ['Action'],},
      'Masquerade' => {:type => ['Action'],},
      'Mining Village' => {:type => ['Action'],},
      'Minion' => {:type => ['Action', 'Attack']},
      'Nobles' => {:type => ['Action', 'Victory']},
      'Pawn' => {:type => ['Action'],},
      'Saboteur' => {:type => ['Action', 'Attack']},
      'Scout' => {:type => ['Action'],},
      'Secret Chamber' => {:type => ['Action','Reaction','Defense']},
      'Shanty Town' => {:type => ['Action'],},
      'Steward' => {:type => ['Action'],},
      'Swindler' => {:type => ['Action', 'Attack']},
      'Torturer' => {:type => ['Action', 'Attack']},
      'Trading Post' => {:type => ['Action'],},
      'Tribute' => {:type => ['Action'],},
      'Upgrade' => {:type => ['Action'],},
      'Wishing Well' => {:type => ['Action'],},
    },
    'Seaside' => {
      'Ambassador' => {:type => ['Action', 'Attack']},
      'Bazaar' => {:type => ['Action'],},
      'Caravan' => {:type => ['Action','Duration']},
      'Cutpurse' => {:type => ['Action', 'Attack']},
      'Embargo' => {:type => ['Action']},
      'Explorer' => {:type => ['Action'],},
      'Fishing Village' => {:type => ['Action','Duration']},
      'Ghost Ship' => {:type => ['Action', 'Attack']},
      'Haven' => {:type => ['Action','Duration']},
      'Island' => {:type => ['Action','Victory']},
      'Lighthouse' => {:type => ['Action','Duration','Defense']},
      'Lookout' => {:type => ['Action'],},
      'Merchant Ship' => {:type => ['Action','Duration']},
      'Native Village' => {:type => ['Action'],},
      'Navigator' => {:type => ['Action'],},
      'Outpost' => {:type => ['Action','Duration']},
      'Pearl Diver' => {:type => ['Action'],},
      'Pirate Ship' => {:type => ['Action', 'Attack']},
      'Salvager' => {:type => ['Action'],},
      'Sea Hag' => {:type => ['Action', 'Attack']},
      'Smugglers' => {:type => ['Action'],},
      'Tactician' => {:type => ['Action','Duration']},
      'Treasure Map' => {:type => ['Action'],},
      'Treasury' => {:type => ['Action'],},
      'Warehouse' => {:type => ['Action'],},
      'Wharf' => {:type => ['Action','Duration']},
    },
    'Boardgamegeek' => {
      'Black Market' => {:type => ['Action'],},
      'Envoy' => {:type => ['Action'],},
      'Stash' => {:type => ['Treasure']},
    },
    'Alchemy' => {
      'Alchemist' => {:type => ['Action'],},
      'Apothecary' => {:type => ['Action'],},
      'Apprentice' => {:type => ['Action'],},
      'Familiar' => {:type => ['Action', 'Attack']},
      'Golem' => {:type => ['Action'],},
      'Herbalist' => {:type => ['Action'],},
      "Philosopher's Stone" => {:type => ['Treasure']},
      'Possession' => {:type => ['Action'],},
      'Scrying Pool' => {:type => ['Action', 'Attack']},
      'Transmute' => {:type => ['Action'],},
      'University' => {:type => ['Action'],},
      'Vineyard' => {:type => ['Victory']},
    },
  }

  cards.each_pair do |exp, names|
    names.each_pair do |card, info|
      c = Card.new(
        :name => card,
        :keywords => info[:type],
        :source => exp
      )
      c.save!
    end
  end
end
