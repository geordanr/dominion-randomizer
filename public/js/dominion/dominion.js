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
    update_settings();
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
        var img = card.source == 'Boardgamegeek' ? 'ferris-wheel' : card.source.toLowerCase();
        inac.append('<li><a id="'+id+'" name="'+card.name+'">'+card.name+'<small><img src="/images/dominion/'+img+'.svg" height="20" alt="'+card.source+'"/></small></a></li>');
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

      if (bans.length == 0) {
        $('#banned-cards').hide();
      } else {
        $('#banned-cards').show();
      }
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
    var card = e.target.name;
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
  $('#expansions input[type="checkbox"]').bind('click', function(e){
    var action = (e.target.checked) ? 'unban' : 'ban';
    var expansion = e.target.id.split('_')[1]
    $.ajax({
      url: '/dominion/expansions/'+action+'/' + expansion,
      type: 'POST',
      dataType: 'json',
      success: function (data, status, xhr) {
        update_spread();
        if (data.banned) $('#exp_'+data.banned)[0].checked = false;
        if (data.unbanned) $('#exp_'+data.unbanned)[0].checked = true;
      },
    });
    return false;
  });
  $('input#pacifist').bind('click', function(e){
    var pacifist = (e.target.checked) ? 1 : 0;
    $.ajax({
      url: '/dominion/config/pacifist/'+pacifist,
      type: 'POST',
      dataType: 'json',
      success: function (data, status, xhr) {
        update_spread();
        $('input#pacifist')[0].checked = (parseInt(data.pacifist) == 1);
      },
    });
    return false;
  })
  $('select#alchemy-min-cards').bind('change', function(e) {
    $.ajax({
      url: '/dominion/config/min_alchemy_cards/' + $(e.target).val(),
      type: 'POST',
      complete: function () {
        update_spread();
      },
    });
  });
  $('select#spread-sort').bind('change', function(e) {
    $.ajax({
      url: '/dominion/config/spread_sort/' + $(e.target).val(),
      type: 'POST',
      complete: function () {
        update_spread();
      },
    });
  });
}

function update_settings() {
  $.getJSON('/dominion/config', {}, function (config, status) {
    if (config.min_alchemy_cards != null) $('select#alchemy-min-cards').val(config.min_alchemy_cards);
    if (config.spread_sort != null) $('select#spread-sort').val(config.spread_sort);
    if (config.pacifist == 1) $('input#pacifist')[0].checked = true;
  });
}
