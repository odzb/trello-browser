Promise    = require 'lie'
extend     = require 'xtend'
superagent = (require 'superagent-promise')((require 'superagent'), Promise)

class Trello
  constructor: (@key) ->
    @get = @req.bind @, 'get'
    @post = @req.bind @, 'post'
    @put = @req.bind @, 'put'
    @del = @req.bind @, 'del'
    @delete = @req.bind @, 'del'

  setToken: (token) -> @token = token

  auth: (opts) ->
    self = @
    defaults =
      type: 'popup'
      name: 'My App'
      scope:
        read: true
        write: true
        account: false
      expiration: '1hour'
    opts = extend defaults, opts

    return new Promise (resolve, reject) ->
      popup = window.open "https://trello.com/1/authorize?response_type=token&key=#{self.key}&return_url=#{location.protocol}//#{location.host}#{location.pathname}#{location.search}&callback_method=postMessage&scope=#{(k for k, e of opts.scope when e).join(',')}&expiration=#{opts.expiration}&name=#{opts.name.replace(/ /g, '+')}", 'trello', "height=606,width=405,left=#{window.screenX + (window.innerWidth - 420)/2},right=#{window.screenY + (window.innerHeight - 470)/2}"

      window.addEventListener 'message', (e) ->
        if typeof e.data == 'string'
          clearTimeout timeout
          popup.close()
          self.token = e.data
          resolve()

      timeout = setTimeout (->
        popup.close()
        reject()
      ), 60000

  req: (method, path, data) ->
    self = @
    Promise.resolve().then(->
      req = superagent[method]('https://api.trello.com' + path)

      if method in ['get', 'del']
        req = req
          .query(key: self.key, token: self.token)
          .query(data)
      else if data.file and -1 != path.indexOf 'attachments'
        req = req
          .field('name', data.name)
          .field('mimeType', data.mimeType)
          .field('key', self.key)
          .field('token', self.token)
        if typeof data.file == 'string'
          if window.Blob
            req = req.attach('file', new File([data.file], data.name, {type: data.mimeType}), data.name)
          else
            # this does not work. need help.
            req = req
              .set('Content-Type': 'boundary=----WebKitFormBoundarygZLBN6gxSW5OC5W1')
              .send("""------WebKitFormBoundarygZLBN6gxSW5OC5W1\r\nContent-Disposition: form-data; name="name"\r\n\r\n#{data.name}\r\n------WebKitFormBoundarygZLBN6gxSW5OC5W1\r\nContent-Disposition: form-data; name="mimeType"\r\n\r\n#{data.mimeType}\r\n------WebKitFormBoundarygZLBN6gxSW5OC5W1\r\nContent-Disposition: form-data; name="key"\r\n\r\n#{self.key}\r\n------WebKitFormBoundarygZLBN6gxSW5OC5W1\r\nContent-Disposition: form-data; name="token"\r\n\r\n#{self.token}\r\n------WebKitFormBoundarygZLBN6gxSW5OC5W1\r\nContent-Disposition: form-data; name="file"; filename="#{data.name}"\r\nContent-Type: application/octet-stream\r\n\r\n#{data.file}\r\n------WebKitFormBoundarygZLBN6gxSW5OC5W1--\r\n""")
        else if typeof data.file == 'object' and data.size
          req = req.attach('file', data.file, data.name)
      else
        req = req
          .send(key: self.key, token: self.token)
          .send(data)
          .set('Content-type': 'application/x-www-form-urlencoded')

      req.end()
    ).then((res) -> res.body)

module.exports = Trello
module.exports.superagent = superagent
