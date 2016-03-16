#active_experiments = {
#  'www.google.com': 'google_alert'
#}

textToHtml = (str) ->
  tmp = document.createElement('span')
  tmp.innerText = str
  return tmp.innerHTML

chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  {type, data} = req
  if type == 'confirm_permissions'
    permissions_list = []
    {fields, pagename} = data
    for x in fields
      if x.description?
        permissions_list.push x.description
      else
        permissions_list.push x.name
    pagehtml = ''
    if pagename?
      pagehtml = '<b>(' + textToHtml(pagename) + ')</b>'
    swal {
      title: 'This page needs your data'
      type: 'info'
      showCancelButton: true
      allowEscapeKey: false
      confirmButtonText: 'Approve'
      cancelButtonText: 'Deny'
      html: true
      text: 'This page ' + pagehtml + ' wants to access the following data <a target="_blank" href="https://tmi.netlify.com/previewdata.html?fields=' + [x.name for x in fields].join(',') + '">(details)</a>:<br><br>' + permissions_list.join('<br>')
    }, (accepted) ->
      sendResponse accepted
    #accepted = confirm 'Would you like to grant the following permissions:\n\n' + data.join('\n')
    #if sendResponse?
    #  sendResponse accepted
  return true # async response

do ->
  ndiv = document.createElement('div')
  ndiv.id = 'autosurvey_content_script_loaded'
  document.body.appendChild(ndiv)

console.log 'content_script loaded'

sendBackground = (type, data, callback) ->
  chrome.runtime.sendMessage {type, data}, (response) ->
    if callback?
      callback response

simpleKeys = (original) ->
  output = {}
  for k,v of original
    vt = typeof v
    if vt == 'number' or vt == 'string'
      output[k] = v
  return output

copy_clientrect_to_object = (rect, output) ->
  for x in <[bottom height left right top width]>
    output[x] = rect[x]
  return

clientrect_to_object = (rect) ->
  output = {}
  for x in <[bottom height left right top width]>
    output[x] = rect[x]
  return output

getElemPath = (elem) ->
  output = []
  while elem != null
    eleminfo = {
      id: elem.id
      tag: elem.tagName
      class: elem.className
    }
    if elem.getBoundingClientRect?
      copy_clientrect_to_object(elem.getBoundingClientRect(), eleminfo)
    output.push eleminfo
    elem = elem.parentNode
  return output

stored_events = {
  'mousedown': []
  'mouseup': []
  'mousemove': []
  'mousewheel': []
  'keydown': []
  'keyup': []
}

have_new_events = ->
  for evtn in <[mousedown mouseup mousemove mousewheel keydown keyup]>
    if stored_events[evtn].length > 0
      return true
  return false

clear_stored_events = !->
  stored_events := {
    'mousedown': []
    'mouseup': []
    'mousemove': []
    'mousewheel': []
    'keydown': []
    'keyup': []
  }

video_tag_to_object = (vid) ->
  output = {}
  if vid.getBoundingClientRect?
    output.pos = clientrect_to_object(vid.getBoundingClientRect())
  for attr in <[width height playbackRate paused duration ended src currentSrc muted currentTime tagName className id]>
    output[attr] = vid[attr]
  return output

iframe_to_object = (iframe) ->
  output = {}
  if iframe.getBoundingClientRect?
    output.pos = clientrect_to_object(iframe.getBoundingClientRect())
  for attr in <[width height src id tagName className]>
    output[attr] = iframe[attr]
  return output

get_all_iframes = ->
  all_iframes = document.querySelectorAll('iframe')
  return [iframe_to_object(x) for x in all_iframes]

get_all_video_tags = ->
  all_video_tags = document.querySelectorAll('video')
  # note: will miss things like iframe embeds on facebook (ie, youtube videos)
  return [video_tag_to_object(x) for x in all_video_tags]

send_stored_events = !->
  output = {
    windowwidth: document.documentElement.clientWidth
    windowheight: document.documentElement.clientHeight
    screenwidth: screen.width
    screenheight: screen.height
    location: window.location.href
    scrollleft: document.body.scrollLeft
    scrolltop: document.body.scrollTop
    scrollwidth: document.body.scrollWidth
    scrollheight: document.body.scrollHeight
    pageheight: document.body.clientHeight
    pagewidth: document.body.clientWidth
    videos: get_all_video_tags()
    iframes: get_all_iframes()
  } <<< stored_events
  sendBackground 'send_stored_events', {data: LZString.compressToBase64(JSON.stringify(output))}

setInterval !->
  if have_new_events()
    send_stored_events()
    clear_stored_events()
, 1000

document.addEventListener 'mousedown', (evt) !->
  output = simpleKeys evt
  output.target = getElemPath(evt.target)
  output.srcElement = getElemPath(evt.srcElement)
  stored_events.mousedown.push output

document.addEventListener 'mousemove', (evt) !->
  output = simpleKeys evt
  stored_events.mousemove.push output

document.addEventListener 'mousewheel', (evt) !->
  output = simpleKeys evt
  stored_events.mousewheel.push output

document.addEventListener 'keydown', (evt) !->
  output = {
    timeStamp: evt.timeStamp
    target: getElemPath(evt.target)
    srcElement: getElemPath(evt.srcElement)
  }
  stored_events.keydown.push output

document.addEventListener 'keyup', (evt, obj) !->
  output = {
    timeStamp: evt.timeStamp
    target: getElemPath(evt.target)
    srcElement: getElemPath(evt.srcElement)
  }
  stored_events.keyup.push output

#load_experiment_for_location = (location) ->
#  sendBackground 'load_experiment_for_location', {location}

#load_experiment_for_location window.location.href
