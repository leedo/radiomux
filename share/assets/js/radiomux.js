radiomux = {
  playing: null,

  add_play: function (station, plays) {
    var container = $('#station-' + station);
    var list = container.find("ol.plays");
    var html = "";

    $(plays).each(function(i, play) {
      var id = "play-" + play.hash;
      if ($(id).length) return;
      var date = new Date(play.timestamp * 1000);
      var info = [];
      $(["artist", "title"]).each(function(i,field) {
        if (play[field]) info.push(play[field]);
      });

      html += sprintf("<li id='%s'>", id);
      if (play.timestamp) {
        html += sprintf("<span class='timestamp'>%02d:%02d</span>", date.getHours(), date.getMinutes());
      }
      html += sprintf(" %s</li>", info.join(" – "));
    });

    list.html(html);
  },

  init: function(data) {
    $(data).each(function(i, update) {
      radiomux.add_play(update.station, update.plays);
    });

    var plays = new EventSource("/plays");
    plays.addEventListener("message", function(e) {
      var data = JSON.parse(e.data);
      radiomux.add_play(data.station, data.plays);
    });
  },

  audio_ready: function() {
    $('.station').on('click', '.paused,.error', function(e) {
      e.preventDefault();
      if (radiomux.playing) radiomux.playing.pause();
      $('.playing').removeClass('playing').addClass("paused");
      $('.active').removeClass('active');
      var button = $(this);
      var station = button.parents(".station");
      var name = station.attr('data-station');

      button.removeClass("paused playing error").addClass("loading");

      $.ajax({
        url: "/token",
        type: "GET",
        data: { station: name },
        success: function(token) {
          var src = sprintf("/play?token=%s&station=%s", token, name);
          var record = $('<span/>',{
            'class': 'button record',
            'data-listen-token': token
          });

          radiomux.playing = soundManager.createSound({
            url: src,
            autoplay: true,
            onplay: function() {
              button.removeClass("paused loading error").addClass("playing");
              button.before(record);
              station.addClass("active");
            },
            onerror: function(e) {
              record.remove();
              button.removeClass("playing loading").addClass("error");
            }
          });
        }
      });
    });

    $('.station').on('click', '.recording', function(e) {
      var button = $(this);
      button.removeClass("recording").addClass("record");
      $.ajax({
        url: "/record/stop",
        type: "GET",
        data: {
          station: button.parents(".station").attr("data-station"),
          token: button.attr('data-listen-token')
        },
        success: function (download) {
          if (!download) return;
          $('body').append($('<iframe/>', {
            'src': download,
            'class': 'download'
          }));
        }
      });
    });

    $('.station').on('click', '.record', function(e) {
      var button = $(this);
      button.removeClass("record").addClass("recording");
      $.ajax({
        url: "/record/start",
        type: "GET",
        data: {
          station: button.parents(".station").attr("data-station"),
          token: button.attr('data-listen-token')
        }
      });
    });

    $('.station').on('click', '.playing,.loading', function(e) {
      e.preventDefault();
      if (radiomux.playing) {
        radiomux.playing.unload();
        $(this).removeClass("playing error loading").addClass("paused");
        $(this).parents('.station').removeClass('active');
        $(this).parents('.station').find('.recording').trigger('click');
      }
    });

    $('.station').on('mousedown', '.button', function(e) {
      $(this).addClass("active");
    });

    $('.station').on('mouseup', '.button', function(e) {
      $(this).removeClass("active");
    });
  }
};

