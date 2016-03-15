# console.log 'weblab running in background'

root = exports ? this

execute_content_script = (tabid, options, callback) ->
  if not options.run_at?
    options.run_at = 'document_end' # document_start
  if not options.all_frames?
    options.all_frames = false
  #chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
  if not tabid?
    if callback?
      callback()
    return
  chrome.tabs.executeScript tabid, {file: options.path, allFrames: options.all_frames, runAt: options.run_at}, ->
    if callback?
      callback()

insert_css = (css_path, callback) ->
  # todo does not do anything currently
  if callback?
    callback()

load_experiment = (experiment_name, callback) ->
  console.log 'start load_experiment ' + experiment_name
  all_experiments <- get_experiments()
  experiment_info = all_experiments[experiment_name]
  tabs <- chrome.tabs.query {active: true, lastFocusedWindow: true}
  tabid = tabs[0].id
  <- async.eachSeries experiment_info.scripts, (options, ncallback) ->
    if typeof options == 'string'
      options = {path: options}
    if options.path[0] == '/'
      options.path = 'experiments' + options.path
    else
      options.path = "experiments/#{experiment_name}/#{options.path}"
    execute_content_script tabid, options, ncallback
  # <- async.eachSeries experiment_info.css, (css_name, ncallback) ->
  #   insert_css "experiments/#{experiment_name}/#{css_name}", ncallback
  console.log 'done load_experiment ' + experiment_name
  if callback?
    callback()

load_experiment_for_location = (location, callback) ->
  possible_experiments <- list_available_experiments_for_location(location)
  errors, results <- async.eachSeries possible_experiments, (experiment, ncallback) ->
    load_experiment experiment, ncallback
  if callback?
    callback()

getLocation = (callback) ->
  #sendTab 'getLocation', {}, callback
  console.log 'calling getTabInfo'
  getTabInfo (tabinfo) ->
    console.log 'getTabInfo results'
    console.log tabinfo
    console.log tabinfo.url
    callback tabinfo.url

getTabInfo = (callback) ->
  chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
    console.log 'getTabInfo results'
    console.log tabs
    if tabs.length == 0
      return
    chrome.tabs.get tabs[0].id, callback

sendTab = (type, data, callback) ->
  chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
    console.log 'sendTab results'
    console.log tabs
    if tabs.length == 0
      return
    chrome.tabs.sendMessage tabs[0].id, {type, data}, {}, callback

message_handlers = {
  'setvars': (data, callback) ->
    <- async.forEachOfSeries data, (v, k, ncallback) ->
      <- setvar k, v
      ncallback()
    callback()
  'getfield': (name, callback) ->
    getfield name, callback
  'getfields': (namelist, callback) ->
    getfields namelist, callback
  'requestfields': (info, callback) ->
    {fieldnames} = info
    getfields fieldnames, callback
  'getvar': (name, callback) ->
    getvar name, callback
  'getvars': (namelist, callback) ->
    output = {}
    <- async.eachSeries namelist, (name, ncallback) ->
      val <- getvar name
      output[name] = val
      ncallback()
    callback output
  'addtolist': (data, callback) ->
    {list, item} = data
    addtolist list, item, callback
  'getlist': (name, callback) ->
    getlist name, callback
  'getLocation': (data, callback) ->
    getLocation (location) ->
      console.log 'getLocation background page:'
      console.log location
      callback location
  'load_experiment': (data, callback) ->
    {experiment_name} = data
    load_experiment experiment_name, ->
      callback()
  'load_experiment_for_location': (data, callback) ->
    {location} = data
    load_experiment_for_location location, ->
      callback()
  'send_stored_events': (data, callback) ->
    log_mdata data
    callback()
}

ext_message_handlers = {
  # 'getfields': message_handers.getfields
  'requestfields': (info, callback) ->
    confirm_permissions info, (accepted) ->
      if not accepted
        return
      getfields info.fieldnames, (results) ->
        console.log 'getfields result:'
        console.log results
        callback results
  'get_field_descriptions': (namelist, callback) ->
    field_info <- get_field_info()
    output = {}
    for x in namelist
      if field_info[x]? and field_info[x].description?
        output[x] = field_info[x].description
    callback output
}

confirm_permissions = (info, callback) ->
  {pagename, fieldnames} = info
  field_info <- get_field_info()
  field_info_list = []
  for x in fieldnames
    output = {name: x}
    if field_info[x]? and field_info[x].description?
      output.description = field_info[x].description
    field_info_list.push output
  sendTab 'confirm_permissions', {pagename, fields: field_info_list}, callback

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

chrome.runtime.onMessageExternal.addListener (request, sender, sendResponse) ->
  console.log 'onMessageExternal'
  console.log request
  console.log 'sender for onMessageExternal is:'
  console.log sender
  {type, data} = request
  message_handler = ext_message_handlers[type]
  if type == 'requestfields'
    # do not prompt for permissions for these urls
    whitelist = [
      'http://localhost:8080/previewdata.html'
      'http://tmi.netlify.com/previewdata.html'
      'https://tmi.netlify.com/previewdata.html'
      'https://tmi.stanford.edu/previewdata.html'
      'https://tmisurvey.herokuapp.com/'
      'https://localhost:8081/'
      'https://tmi.stanford.edu/'
    ]
    for whitelisted_url in whitelist
      if sender.url.indexOf(whitelisted_url) == 0
        message_handler = message_handlers.requestfields
        break
  if not message_handler?
    return
  #tabId = sender.tab.id
  message_handler data, (response) ~>
    console.log 'response is:'
    console.log response
    response_string = JSON.stringify(response)
    console.log 'turned into response_string:'
    console.log response_string
    if sendResponse?
      sendResponse response
  return true # async response

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  {type, data} = request
  console.log type
  console.log data
  message_handler = message_handlers[type]
  if not message_handler?
    return
  # tabId = sender.tab.id
  message_handler data, (response) ->
    console.log 'message handler response:'
    console.log response
    #response_data = {response}
    #console.log response_data
    # chrome bug - doesn't seem to actually send the response back....
    #sendResponse response_data
    if sendResponse?
      sendResponse response
    # {requestId} = request
    # if requestId? # response requested
    #  chrome.tabs.sendMessage tabId, {event: 'backgroundresponse', requestId, response}
  return true

export page_to_time_spent_info = {}

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

#setInterval ->
#  console.log current_page_info
#, 2000

make_string_safe_for_mongodb = (input) ->
  if input[0] == '$'
    input = '＄' + input.slice(1)
  #if input.indexOf('.') != -1
  #  input = input.replace(/\./g, '。')
  if !input.includes('.')
    return input
  while true
    newinput = input.replace('.', '。')
    if newinput == input
      return input
    input = newinput

make_safe_for_mongodb = (input) ->
  #if typeof(input) == 'string'
  #  return make_string_safe_for_mongodb(input)
  if (input instanceof Array)
    return [make_safe_for_mongodb(x) for x in input]
  if (input instanceof Object)
    return {[make_string_safe_for_mongodb(k),make_safe_for_mongodb(v)] for k,v of input}
  return input

post_data_url = localStorage.getItem('post_data_url')
if not post_data_url?
  post_data_url = 'https://tmi.stanford.edu:3000'
  #post_data_url = 'http://localhost:3001'
post_log_url = post_data_url + '/addlog'
post_mlog_url = post_data_url + '/addmlog'
post_hist_url = post_data_url + '/addhist'

post_hist = (data, callback) ->
  $.ajax {
    type: 'POST'
    url: post_hist_url
    contentType: 'text/plain'
    data: JSON.stringify(data)
    complete: ->
      if callback?
        callback()
  }

post_data = (data) ->
  # some post request occurs here
  console.log data
  $.ajax {
    type: 'POST'
    url: post_log_url
    contentType: 'text/plain'
    data: JSON.stringify(data)
  }

post_mdata = (data) ->
  # some post request occurs here
  $.ajax {
    type: 'POST'
    url: post_mlog_url
    contentType: 'text/plain'
    data: JSON.stringify(data)
  }

username = localStorage.getItem('username')
if not username?
  username = randstr(10)
  localStorage.setItem('username', username)

log_hist = (data, callback) !->
  data.time = Date.now()
  data.user = username
  data.ver = '1'
  post_hist(make_safe_for_mongodb(data), callback)

log_data = (data) !->
  data.time = Date.now()
  data.user = username
  data.ver = '1'
  post_data(make_safe_for_mongodb(data))

log_mdata = (data) !->
  data.time = Date.now()
  data.user = username
  data.ver = '1'
  post_mdata(make_safe_for_mongodb(data))

chrome.tabs.onZoomChange.addListener (zoomchangeinfo) ->
  send_window_info_with_data {evt: 'tab_zoomchange', zoomchangeinfo}

chrome.tabs.onReplaced.addListener (addedtabid, removedtabid) ->
  send_window_info_with_data {evt: 'tab_replaced', addedtabid, removedtabid}

chrome.tabs.onRemoved.addListener (tabid, removeinfo) ->
  send_window_info_with_data {evt: 'tab_removed', tabid, removeinfo}

chrome.tabs.onAttached.addListener (tabid, attachinfo) ->
  send_window_info_with_data {evt: 'tab_attached', tabid, attachinfo}

chrome.tabs.onDetached.addListener (tabid, detachinfo) ->
  send_window_info_with_data {evt: 'tab_detached', tabid, detachinfo}

chrome.tabs.onHighlighted.addListener (highlightinfo) ->
  send_window_info_with_data {evt: 'tab_highlighted', highlightinfo}

chrome.tabs.onActivated.addListener (activeinfo) ->
  send_window_info_with_data {evt: 'tab_activated', activeinfo}

chrome.tabs.onMoved.addListener (tabid, moveinfo) ->
  send_window_info_with_data {evt: 'tab_moved', tabid, moveinfo}

chrome.tabs.onUpdated.addListener (tabid, changeinfo, tab) ->
  send_window_info_with_data {evt: 'tab_updated', tabid, changeinfo, tab}

chrome.tabs.onCreated.addListener (newtab) ->
  send_window_info_with_data {evt: 'tab_created', newtab}

chrome.windows.onRemoved.addListener (closedwindow) ->
  send_window_info_with_data {evt: 'window_closed', closedwindow}

chrome.windows.onCreated.addListener (newwindow) ->
  send_window_info_with_data {evt: 'window_created', newwindow}

chrome.windows.onFocusChanged.addListener (windowid) ->
  send_window_info_with_data {evt: 'window_focus_changed', windowid}

current_idlestate = 'active'

chrome.idle.onStateChanged.addListener (idlestate) ->
  current_idlestate := idlestate
  send_window_info_with_data {evt: 'idle_changed', idlestate}


setInterval ->
  if !prev_browser_focused
    return
  if current_idlestate != 'active'
    return
  if Date.now() > last_sent_window_info + 30000 # 30 seconds since no message
    send_window_info_with_data {evt: 'still_browsing'}
, 15000

last_sent_window_info = 0
#windowsid = 0
#prev_compressed_windows = ''
send_window_info_with_data = (data) ->
  last_sent_window_info := Date.now()
  chrome.windows.getAll {populate: true}, (windows) ->
    curwindows = LZString.compressToBase64(JSON.stringify(windows))
    data.windows = curwindows
    /*
    if curwindows == prev_compressed_windows
      data.windowsid = windowsid
    else
      data.windows = curwindows
      windowsid := windowsid + 1
      data.windowsid = windowsid
      prev_compressed_windows := curwindows
    */
    log_data data

browser_focus_changed = (new_focused) ->
  send_window_info_with_data {evt: 'browser_focus_changed', isfocused: new_focused}

prev_browser_focused = false
setInterval ->
  chrome.windows.getCurrent (browser) ->
    focused = browser.focused
    if focused != prev_browser_focused
      prev_browser_focused := focused
      browser_focus_changed(focused)
, 500



time_history_sent = localStorage.getItem('time_history_sent')
if not time_history_sent?
  time_history_sent = 0

get_chrome_history_pages = (callback) ->
  results <- chrome.history.search {text: '', startTime: 0, maxResults: 2**31-1}
  callback results

get_chrome_history_visits = (url_list, callback) ->
  url_to_visits = {}
  <- async.eachSeries url_list, (url, donecb) ->
    chrome.history.getVisits {url: url}, (visits) ->
      url_to_visits[url] = visits
      return donecb()
  callback url_to_visits

history_pages_to_url_list = (results) ->
  url_list = []
  seen_urls = {}
  for x in results
    if not x?
      continue
    url = x.url
    if not url? or url == ''
      continue
    if seen_urls[url]?
      continue
    seen_urls[url] = true
    url_list.push url
  return url_list

export split_list_by_length = (list, len) ->
  output = []
  curlist = []
  for x in list
    curlist.push x
    if curlist.length == len
      output.push curlist
      curlist = []
  if curlist.length > 0
    output.push curlist
  return output


export send_history_now = ->
  console.log 'sending history now'
  chrome_history_pages <- get_chrome_history_pages()
  history_id = Date.now()
  <- log_hist {evt: 'history_pages', hid: history_id, data: LZString.compressToBase64(JSON.stringify(chrome_history_pages))}
  url_list_full = history_pages_to_url_list(chrome_history_pages)
  url_list_split = split_list_by_length(url_list_full, 100)
  num_parts = url_list_split.length
  <- async.forEachOf url_list_split, (url_list, idx, donecb) ->
    console.log idx
    get_chrome_history_visits url_list, (url_to_visits) ->
      log_hist {evt: 'history_visits', idx, totalparts: num_parts, hid: history_id, data: LZString.compressToBase64(JSON.stringify(url_to_visits))}, donecb
  console.log 'done sending history'
  localStorage.setItem 'time_history_sent', history_id

export send_history_if_needed = ->
  if Date.now() > time_history_sent + 24*3600*1000 # a day since last history sent
    send_history_now()

send_history_if_needed()
setInterval ->
  send_history_if_needed()
, 15*60*1000 # every 15 minutes

/*
setInterval ->
  chrome.windows.getCurrent (browser) ->
    console.log 'is browser focused: ' + browser.focused
    console.log browser
    #chrome.tabs.query {windowId: browser.id}, (tabs) ->
    #  console.log tabs
, 1000
*/