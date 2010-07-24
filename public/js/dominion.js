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
    return this;
  };
}

var cardbuf = new DoubleBuffer('cards');
var banbuf = new DoubleBuffer('ban');
$(document).ready(function(){
    update_spread();
    update_banlist();
    update_expansions();
    set_handlers();
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

function update_expansions() {
  $.getJSON('/dominion/expansions', {}, function(expansions, status) {
      for (var expansion in expansions) {
        $('#exp_'+expansion)[0].checked = expansions[expansion];
      }
  });
}

function set_handlers() {
  $('#refresh a').tap(function (e) {
    update_spread(true);
  });
  $('#spread a').tap(function (e) {
    var card = e.target.innerHTML;
    if (card == 'Saboteur' || confirm('Really ban '+card+'?')) {
      $.ajax({
        url: '/dominion/cards/ban/' + e.target.id,
        type: 'POST',
        complete: function (xhr, stat) {
          update_spread();
          update_banlist();
        },
      });
    }
  });
  $('#banned-cards a').tap(function (e) {
    var card = e.target.innerHTML;
    if (card != 'Saboteur' || confirm("Are you ABSOLUTELY SURE you want to unban Saboteur?  Do you not want to have friends?")) {
      $.ajax({
        url: '/dominion/cards/unban/' + e.target.id,
        type: 'POST',
        complete: update_banlist,
      });
    }
  });
  $('#expansions input[type="checkbox"]').bind('change', function(e){
    var action = (e.target.checked) ? 'unban' : 'ban';
    $.ajax({
      url: '/dominion/expansions/'+action+'/' + e.target.id.split('_')[1],
      type: 'POST',
      complete: function () {
        update_spread();
      },
    });
  });
}
