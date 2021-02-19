require 'net/http'
require 'uri'
require 'oj'
#require 'mime/types'

class FlareSolverr
  class FlareSolverrError < StandardError; end
  attr_accessor :session_id
  def initialize(port, api_ver=1)
    @port = port
    @api_ver = api_ver
    @session_id = nil
    @uri = URI("http://localhost:#{@port}/v#{api_ver}")
  end

  def get(url)
    params = { 'url' => url }
    params['session'] = @session_id unless session_id.nil?
    response = send_command('request.get', **params)
    solution = handle_response(response)['solution']
    
    # TODO: Robust response rather than just body
    return solution['response']
  end

  def list_sessions
    response = send_command('sessions.list')
    body = handle_response(response)
    body['sessions']
  end

  def create_session
    handle_response(send_command('sessions.create'))['session']
  end

  def destroy_session(id)
    handle_response(send_command('sessions.destroy', 'session' => id))
  end

  def open!
    @session_id = create_session
  end

  def close!
    destroy_session(@session_id)
  end

  private
  def handle_response(response)
    if response.code != '200'
      raise FlareSolverrError.new('FlareSolverr is either not running or is misconfigured.')
    end

    body = Oj.load(response.body)
    if body['status'] != 'ok'
      raise FlareSolverrError.new("FlareSolverr encountered a problem: #{body['message']}")
    end

    return body
  end

  def send_command(cmd, **params)
    header = { 'Content-Type' => 'application/json' }
    data = {
      'cmd' => cmd,
      'userAgent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleW...',
    }.merge(params)
    Net::HTTP.post(@uri, Oj.dump(data), header)
  end
end