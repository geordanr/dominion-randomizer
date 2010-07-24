var ev = null;

function DoubleBuffer(name) {
  this.name = name;
  this.active = 0;
  this.inactive = 1;

  this.getActive = function () {
    return $('#' + this.name + this.active);
  };

  this.getInactive = function () {
    return $('#' + this.name + this.inactive);
  };

  this.swap = function () {
    this.active ^= 1;
    this.inactive ^= 1;
    this.getInactive().hide();
    this.getActive().show();
  };
}

var cardbuf = new DoubleBuffer('cards');
var banbuf = new DoubleBuffer('ban');
$(document).ready(function(){
    set_handlers();
    update_spread();
    update_banlist();
});

function update_spread(refresh) {
  var url = '/dominion/cards';
  if (refresh) {
    url += '?refresh=1'
  }
  $.getJSON(url, {}, function(spread, status) {
      var inac = cardbuf.getInactive();
      spread.forEach(function(card) {
        var id = card['_id'];
        inac.append('<li><a id="'+id+'">'+card.name+'</a></li>');
      });

      cardbuf.swap();

      inac = cardbuf.getInactive();
      inac.empty();
  });
}

function update_banlist() {
  $.getJSON('/dominion/cards/bans', {}, function(bans, status) {
      var inac = banbuf.getInactive();
      bans.forEach(function(card) {
        var id = card['_id'];
        inac.append('<li><a id="'+id+'">'+card.name+'</a></li>');
      });

      banbuf.swap();

      inac = banbuf.getInactive();
      inac.empty();
  });
}

function set_handlers() {
  $('ul.rounded#refresh').tap(function (e) {
    update_spread(true);
  });
  $('#spread a').tap(function (e) {
    $.ajax({
      url: '/dominion/cards/ban/' + e.target.id,
      type: 'POST',
      complete: function (xhr, stat) {
        update_spread();
        update_banlist();
      },
    });
  });
  $('#banned-cards a').tap(function (e) {
    $.ajax({
      url: '/dominion/cards/unban/' + e.target.id,
      type: 'POST',
      complete: update_banlist,
    });
  });
}
