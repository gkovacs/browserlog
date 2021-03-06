// Generated by LiveScript 1.4.0
(function(){
  var root, execute_content_script, insert_css, load_experiment, load_experiment_for_location, getLocation, getTabInfo, sendTab, message_handlers, ext_message_handlers, confirm_permissions, page_to_time_spent_info, make_string_safe_for_mongodb, make_safe_for_mongodb, post_data_url, post_log_url, post_mlog_url, post_hist_url, post_hist, post_data, post_mdata, mturkid, get_mturk_id, get_mturk_id_process, username, dataver, log_hist, log_data, log_mdata, current_idlestate, last_sent_window_info, send_window_info_with_data, browser_focus_changed, prev_browser_focused, time_history_sent, get_chrome_history_pages, get_chrome_history_visits, history_pages_to_url_list, split_list_by_length, send_history_now, send_history_if_needed, out$ = typeof exports != 'undefined' && exports || this;
  root = typeof exports != 'undefined' && exports !== null ? exports : this;
  execute_content_script = function(tabid, options, callback){
    if (options.run_at == null) {
      options.run_at = 'document_end';
    }
    if (options.all_frames == null) {
      options.all_frames = false;
    }
    if (tabid == null) {
      if (callback != null) {
        callback();
      }
      return;
    }
    return chrome.tabs.executeScript(tabid, {
      file: options.path,
      allFrames: options.all_frames,
      runAt: options.run_at
    }, function(){
      if (callback != null) {
        return callback();
      }
    });
  };
  insert_css = function(css_path, callback){
    if (callback != null) {
      return callback();
    }
  };
  load_experiment = function(experiment_name, callback){
    console.log('start load_experiment ' + experiment_name);
    return get_experiments(function(all_experiments){
      var experiment_info;
      experiment_info = all_experiments[experiment_name];
      return chrome.tabs.query({
        active: true,
        lastFocusedWindow: true
      }, function(tabs){
        var tabid;
        tabid = tabs[0].id;
        return async.eachSeries(experiment_info.scripts, function(options, ncallback){
          if (typeof options === 'string') {
            options = {
              path: options
            };
          }
          if (options.path[0] === '/') {
            options.path = 'experiments' + options.path;
          } else {
            options.path = "experiments/" + experiment_name + "/" + options.path;
          }
          return execute_content_script(tabid, options, ncallback);
        }, function(){
          console.log('done load_experiment ' + experiment_name);
          if (callback != null) {
            return callback();
          }
        });
      });
    });
  };
  load_experiment_for_location = function(location, callback){
    return list_available_experiments_for_location(location, function(possible_experiments){
      return async.eachSeries(possible_experiments, function(experiment, ncallback){
        return load_experiment(experiment, ncallback);
      }, function(errors, results){
        if (callback != null) {
          return callback();
        }
      });
    });
  };
  getLocation = function(callback){
    return getTabInfo(function(tabinfo){
      return callback(tabinfo.url);
    });
  };
  getTabInfo = function(callback){
    return chrome.tabs.query({
      active: true,
      lastFocusedWindow: true
    }, function(tabs){
      if (tabs.length === 0) {
        return;
      }
      return chrome.tabs.get(tabs[0].id, callback);
    });
  };
  sendTab = function(type, data, callback){
    return chrome.tabs.query({
      active: true,
      lastFocusedWindow: true
    }, function(tabs){
      if (tabs.length === 0) {
        return;
      }
      return chrome.tabs.sendMessage(tabs[0].id, {
        type: type,
        data: data
      }, {}, callback);
    });
  };
  message_handlers = {
    'setvars': function(data, callback){
      return async.forEachOfSeries(data, function(v, k, ncallback){
        return setvar(k, v, function(){
          return ncallback();
        });
      }, function(){
        return callback();
      });
    },
    'getfield': function(name, callback){
      return getfield(name, callback);
    },
    'getfields': function(namelist, callback){
      return getfields(namelist, callback);
    },
    'requestfields': function(info, callback){
      var fieldnames;
      fieldnames = info.fieldnames;
      return getfields(fieldnames, callback);
    },
    'getvar': function(name, callback){
      return getvar(name, callback);
    },
    'getvars': function(namelist, callback){
      var output;
      output = {};
      return async.eachSeries(namelist, function(name, ncallback){
        return getvar(name, function(val){
          output[name] = val;
          return ncallback();
        });
      }, function(){
        return callback(output);
      });
    },
    'addtolist': function(data, callback){
      var list, item;
      list = data.list, item = data.item;
      return addtolist(list, item, callback);
    },
    'getlist': function(name, callback){
      return getlist(name, callback);
    },
    'getLocation': function(data, callback){
      return getLocation(function(location){
        return callback(location);
      });
    },
    'load_experiment': function(data, callback){
      var experiment_name;
      experiment_name = data.experiment_name;
      return load_experiment(experiment_name, function(){
        return callback();
      });
    },
    'load_experiment_for_location': function(data, callback){
      var location;
      location = data.location;
      return load_experiment_for_location(location, function(){
        return callback();
      });
    },
    'send_stored_events': function(data, callback){
      log_mdata(data);
      return callback();
    }
  };
  ext_message_handlers = {
    'requestfields': function(info, callback){
      return confirm_permissions(info, function(accepted){
        if (!accepted) {
          return;
        }
        return getfields(info.fieldnames, function(results){
          return callback(results);
        });
      });
    },
    'get_field_descriptions': function(namelist, callback){
      return get_field_info(function(field_info){
        var output, i$, ref$, len$, x;
        output = {};
        for (i$ = 0, len$ = (ref$ = namelist).length; i$ < len$; ++i$) {
          x = ref$[i$];
          if (field_info[x] != null && field_info[x].description != null) {
            output[x] = field_info[x].description;
          }
        }
        return callback(output);
      });
    }
  };
  confirm_permissions = function(info, callback){
    var pagename, fieldnames;
    pagename = info.pagename, fieldnames = info.fieldnames;
    return get_field_info(function(field_info){
      var field_info_list, i$, ref$, len$, x, output;
      field_info_list = [];
      for (i$ = 0, len$ = (ref$ = fieldnames).length; i$ < len$; ++i$) {
        x = ref$[i$];
        output = {
          name: x
        };
        if (field_info[x] != null && field_info[x].description != null) {
          output.description = field_info[x].description;
        }
        field_info_list.push(output);
      }
      return sendTab('confirm_permissions', {
        pagename: pagename,
        fields: field_info_list
      }, callback);
    });
  };
  /*
  chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
    if tab.url
      #console.log 'tabs updated!'
      #console.log tab.url
      possible_experiments <- list_available_experiments_for_location(tab.url)
      if possible_experiments.length > 0
        chrome.pageAction.show(tabId)
      send_pageupdate_to_tab(tabId)
      # load_experiment_for_location tab.url
  */
  chrome.runtime.onMessageExternal.addListener(function(request, sender, sendResponse){
    var type, data, message_handler, whitelist, i$, len$, whitelisted_url, this$ = this;
    type = request.type, data = request.data;
    message_handler = ext_message_handlers[type];
    if (type === 'requestfields') {
      whitelist = ['http://localhost:8080/previewdata.html', 'http://tmi.netlify.com/previewdata.html', 'https://tmi.netlify.com/previewdata.html', 'https://tmi.stanford.edu/previewdata.html', 'https://tmisurvey.herokuapp.com/', 'https://localhost:8081/', 'https://tmi.stanford.edu/'];
      for (i$ = 0, len$ = whitelist.length; i$ < len$; ++i$) {
        whitelisted_url = whitelist[i$];
        if (sender.url.indexOf(whitelisted_url) === 0) {
          message_handler = message_handlers.requestfields;
          break;
        }
      }
    }
    if (message_handler == null) {
      return;
    }
    message_handler(data, function(response){
      var response_string;
      response_string = JSON.stringify(response);
      if (sendResponse != null) {
        return sendResponse(response);
      }
    });
    return true;
  });
  chrome.runtime.onMessage.addListener(function(request, sender, sendResponse){
    var type, data, message_handler;
    type = request.type, data = request.data;
    message_handler = message_handlers[type];
    if (message_handler == null) {
      return;
    }
    message_handler(data, function(response){
      if (sendResponse != null) {
        return sendResponse(response);
      }
    });
    return true;
  });
  out$.page_to_time_spent_info = page_to_time_spent_info = {};
  /*
  add_time_spent = (url, time) ->
    if not page_to_time_spent[url]?
      page_to_time_spent[url] = time
    else
      page_to_time_spent[url] += time
  */
  /*
  current_page_info = {url: '', start: Date.now()}
  
  add_new_session = (url) ->
    if not page_to_time_spent_info[url]?
      page_to_time_spent_info[url] = []
    page_to_time_spent_info[url].push {url, start: Date.now()}
    current_page_info := page_to_time_spent_info[url][*-1]
  
  chrome.idle.onStateChanged.addListener (newstate) ->
    console.log 'idle stateChanged: ' + newstate
    if newstate == 'idle'
      current_page_info.idle = Date.now()
    else if newstate == 'locked'
      current_page_info.locked = Date.now()
    else if newstate == 'active'
      add_new_session current_page_info.url
  
  activate_url = (url) ->
    if url == current_page_info.url
      if is_page_info_active(current_page_info)
        return
    add_new_session url
  
  total_time_spent_page_info = (page_info) ->
    end_types = <[idle locked unfocused]>
    end_time = Date.now()
    for x in end_types
      if page_info[x]?
        end_time = Math.min(end_time, page_info[x])
    return end_time
  
  is_page_info_active = (page_info) ->
    end_types = <[idle locked unfocused]>
    for x in end_types
      if page_info[x]?
        return false
    return true
  
  chrome.tabs.onUpdated.addListener (tabid, changeinfo, tab) ->
    console.log 'tabs updated: ' + tabid
    console.log changeinfo
    console.log tab
    {url} = tab
    activate_url url
  
  chrome.tabs.onActivated.addListener (tabinfo) ->
    console.log 'active tabs changed:'
    console.log tabinfo
    tab <- chrome.tabs.get tabinfo.tabId
    activate_url tab.url
  
  chrome.windows.onFocusChanged.addListener (windowid) ->
    console.log 'focused window is:'
    console.log windowid
    active_tabs <- chrome.tabs.query {active: true, lastFocusedWindow: true}
    console.log active_tabs
    if active_tabs.length == 0
      current_page_info.unfocused = Date.now()
    else
      url = active_tabs[0].url
      add_new_session url
    # Will be chrome.windows.WINDOW_ID_NONE if all chrome windows have lost focus.
  */
  make_string_safe_for_mongodb = function(input){
    var newinput;
    if (input[0] === '$') {
      input = '＄' + input.slice(1);
    }
    if (!input.includes('.')) {
      return input;
    }
    for (;;) {
      newinput = input.replace('.', '。');
      if (newinput === input) {
        return input;
      }
      input = newinput;
    }
  };
  make_safe_for_mongodb = function(input){
    var x, k, v;
    if (input instanceof Array) {
      return (function(){
        var i$, ref$, len$, results$ = [];
        for (i$ = 0, len$ = (ref$ = input).length; i$ < len$; ++i$) {
          x = ref$[i$];
          results$.push(make_safe_for_mongodb(x));
        }
        return results$;
      }());
    }
    if (input instanceof Object) {
      return (function(){
        var ref$, resultObj$ = {};
        for (k in ref$ = input) {
          v = ref$[k];
          resultObj$[make_string_safe_for_mongodb(k)] = make_safe_for_mongodb(v);
        }
        return resultObj$;
      }());
    }
    return input;
  };
  post_data_url = localStorage.getItem('post_data_url');
  if (post_data_url == null) {
    post_data_url = 'https://tmi.stanford.edu:3000';
  }
  post_log_url = post_data_url + '/addlog';
  post_mlog_url = post_data_url + '/addmlog';
  post_hist_url = post_data_url + '/addhist';
  post_hist = function(data, callback){
    return $.ajax({
      type: 'POST',
      url: post_hist_url,
      contentType: 'text/plain',
      data: JSON.stringify(data),
      complete: function(){
        if (callback != null) {
          return callback();
        }
      }
    });
  };
  post_data = function(data){
    return $.ajax({
      type: 'POST',
      url: post_log_url,
      contentType: 'text/plain',
      data: JSON.stringify(data)
    });
  };
  post_mdata = function(data){
    return $.ajax({
      type: 'POST',
      url: post_mlog_url,
      contentType: 'text/plain',
      data: JSON.stringify(data)
    });
  };
  mturkid = localStorage.getItem('mturkid');
  if (mturkid == null) {
    get_mturk_id = function(){
      return chrome.history.search({
        text: 'https://tmi.stanford.edu/mturk3.html?username=',
        startTime: 0
      }, function(results){
        var urlstring;
        if (results.length > 0) {
          urlstring = results[0].url;
          mturkid = urlstring.split('https://tmi.stanford.edu/mturk3.html?username=').join('').trim();
          localStorage.setItem('mturkid', mturkid);
          return clearInterval(get_mturk_id_process);
        }
      });
    };
    get_mturk_id_process = setInterval(get_mturk_id, 1000 * 60);
    get_mturk_id();
  }
  username = localStorage.getItem('username');
  if (username == null) {
    username = randstr(10);
    localStorage.setItem('username', username);
  }
  dataver = '2';
  log_hist = function(data, callback){
    data.time = Date.now();
    data.user = username;
    if (mturkid != null) {
      data.mturkid = mturkid;
    }
    data.ver = dataver;
    post_hist(make_safe_for_mongodb(data), callback);
  };
  log_data = function(data){
    data.time = Date.now();
    data.user = username;
    if (mturkid != null) {
      data.mturkid = mturkid;
    }
    data.ver = dataver;
    post_data(make_safe_for_mongodb(data));
  };
  log_mdata = function(data){
    data.time = Date.now();
    data.user = username;
    if (mturkid != null) {
      data.mturkid = mturkid;
    }
    data.ver = dataver;
    post_mdata(make_safe_for_mongodb(data));
  };
  chrome.tabs.onZoomChange.addListener(function(zoomchangeinfo){
    return send_window_info_with_data({
      evt: 'tab_zoomchange',
      zoomchangeinfo: zoomchangeinfo
    });
  });
  chrome.tabs.onReplaced.addListener(function(addedtabid, removedtabid){
    return send_window_info_with_data({
      evt: 'tab_replaced',
      addedtabid: addedtabid,
      removedtabid: removedtabid
    });
  });
  chrome.tabs.onRemoved.addListener(function(tabid, removeinfo){
    return send_window_info_with_data({
      evt: 'tab_removed',
      tabid: tabid,
      removeinfo: removeinfo
    });
  });
  chrome.tabs.onAttached.addListener(function(tabid, attachinfo){
    return send_window_info_with_data({
      evt: 'tab_attached',
      tabid: tabid,
      attachinfo: attachinfo
    });
  });
  chrome.tabs.onDetached.addListener(function(tabid, detachinfo){
    return send_window_info_with_data({
      evt: 'tab_detached',
      tabid: tabid,
      detachinfo: detachinfo
    });
  });
  chrome.tabs.onHighlighted.addListener(function(highlightinfo){
    return send_window_info_with_data({
      evt: 'tab_highlighted',
      highlightinfo: highlightinfo
    });
  });
  chrome.tabs.onActivated.addListener(function(activeinfo){
    return send_window_info_with_data({
      evt: 'tab_activated',
      activeinfo: activeinfo
    });
  });
  chrome.tabs.onMoved.addListener(function(tabid, moveinfo){
    return send_window_info_with_data({
      evt: 'tab_moved',
      tabid: tabid,
      moveinfo: moveinfo
    });
  });
  chrome.tabs.onUpdated.addListener(function(tabid, changeinfo, tab){
    return send_window_info_with_data({
      evt: 'tab_updated',
      tabid: tabid,
      changeinfo: changeinfo,
      tab: tab
    });
  });
  chrome.tabs.onCreated.addListener(function(newtab){
    return send_window_info_with_data({
      evt: 'tab_created',
      newtab: newtab
    });
  });
  chrome.windows.onRemoved.addListener(function(closedwindow){
    return send_window_info_with_data({
      evt: 'window_closed',
      closedwindow: closedwindow
    });
  });
  chrome.windows.onCreated.addListener(function(newwindow){
    return send_window_info_with_data({
      evt: 'window_created',
      newwindow: newwindow
    });
  });
  chrome.windows.onFocusChanged.addListener(function(windowid){
    return send_window_info_with_data({
      evt: 'window_focus_changed',
      windowid: windowid
    });
  });
  current_idlestate = 'active';
  chrome.idle.onStateChanged.addListener(function(idlestate){
    current_idlestate = idlestate;
    return send_window_info_with_data({
      evt: 'idle_changed',
      idlestate: idlestate
    });
  });
  setInterval(function(){
    if (!prev_browser_focused) {
      return;
    }
    if (current_idlestate !== 'active') {
      return;
    }
    if (Date.now() > last_sent_window_info + 30000) {
      return send_window_info_with_data({
        evt: 'still_browsing'
      });
    }
  }, 15000);
  last_sent_window_info = 0;
  send_window_info_with_data = function(data){
    last_sent_window_info = Date.now();
    return chrome.windows.getAll({
      populate: true
    }, function(windows){
      var curwindows;
      curwindows = LZString.compressToBase64(JSON.stringify(windows));
      data.windows = curwindows;
      /*
      if curwindows == prev_compressed_windows
        data.windowsid = windowsid
      else
        data.windows = curwindows
        windowsid := windowsid + 1
        data.windowsid = windowsid
        prev_compressed_windows := curwindows
      */
      return log_data(data);
    });
  };
  browser_focus_changed = function(new_focused){
    return send_window_info_with_data({
      evt: 'browser_focus_changed',
      isfocused: new_focused
    });
  };
  prev_browser_focused = false;
  setInterval(function(){
    return chrome.windows.getCurrent(function(browser){
      var focused;
      focused = browser.focused;
      if (focused !== prev_browser_focused) {
        prev_browser_focused = focused;
        return browser_focus_changed(focused);
      }
    });
  }, 500);
  time_history_sent = localStorage.getItem('time_history_sent');
  if (time_history_sent == null) {
    time_history_sent = 0;
  }
  time_history_sent = parseInt(time_history_sent);
  if (!isFinite(time_history_sent)) {
    time_history_sent = 0;
  }
  get_chrome_history_pages = function(callback){
    return chrome.history.search({
      text: '',
      startTime: 0,
      maxResults: Math.pow(2, 31) - 1
    }, function(results){
      return callback(results);
    });
  };
  get_chrome_history_visits = function(url_list, callback){
    var url_to_visits;
    url_to_visits = {};
    return async.eachSeries(url_list, function(url, donecb){
      return chrome.history.getVisits({
        url: url
      }, function(visits){
        url_to_visits[url] = visits;
        return donecb();
      });
    }, function(){
      return callback(url_to_visits);
    });
  };
  history_pages_to_url_list = function(results){
    var url_list, seen_urls, i$, len$, x, url;
    url_list = [];
    seen_urls = {};
    for (i$ = 0, len$ = results.length; i$ < len$; ++i$) {
      x = results[i$];
      if (x == null) {
        continue;
      }
      url = x.url;
      if (url == null || url === '') {
        continue;
      }
      if (seen_urls[url] != null) {
        continue;
      }
      seen_urls[url] = true;
      url_list.push(url);
    }
    return url_list;
  };
  out$.split_list_by_length = split_list_by_length = function(list, len){
    var output, curlist, i$, len$, x;
    output = [];
    curlist = [];
    for (i$ = 0, len$ = list.length; i$ < len$; ++i$) {
      x = list[i$];
      curlist.push(x);
      if (curlist.length === len) {
        output.push(curlist);
        curlist = [];
      }
    }
    if (curlist.length > 0) {
      output.push(curlist);
    }
    return output;
  };
  out$.send_history_now = send_history_now = function(){
    console.log('sending history now');
    return get_chrome_history_pages(function(chrome_history_pages){
      var history_id;
      history_id = Date.now();
      return log_hist({
        evt: 'history_pages',
        hid: history_id,
        data: LZString.compressToBase64(JSON.stringify(chrome_history_pages))
      }, function(){
        var url_list_full, url_list_split, num_parts;
        url_list_full = history_pages_to_url_list(chrome_history_pages);
        url_list_split = split_list_by_length(url_list_full, 100);
        num_parts = url_list_split.length;
        return async.forEachOf(url_list_split, function(url_list, idx, donecb){
          console.log(idx);
          return get_chrome_history_visits(url_list, function(url_to_visits){
            return log_hist({
              evt: 'history_visits',
              idx: idx,
              totalparts: num_parts,
              hid: history_id,
              data: LZString.compressToBase64(JSON.stringify(url_to_visits))
            }, donecb);
          });
        }, function(){
          console.log('done sending history');
          localStorage.setItem('time_history_sent', history_id);
          return time_history_sent = history_id;
        });
      });
    });
  };
  out$.send_history_if_needed = send_history_if_needed = function(){
    if (Date.now() > time_history_sent + 24 * 3600 * 1000) {
      return send_history_now();
    }
  };
  send_history_if_needed();
  setInterval(function(){
    return send_history_if_needed();
  }, 15 * 60 * 1000);
  /*
  setInterval ->
    chrome.windows.getCurrent (browser) ->
      console.log 'is browser focused: ' + browser.focused
      console.log browser
      #chrome.tabs.query {windowId: browser.id}, (tabs) ->
      #  console.log tabs
  , 1000
  */
}).call(this);
