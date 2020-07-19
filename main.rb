#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require
require 'pp'


App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on :message do |event|
      p ws.methods
      ws.send(event.data)
    end

    ws.on :close do |event|
      p [:close, event.code, event.reason]
      ws = nil
    end

    # Return async Rack response
    ws.rack_response

  else
    # Normal HTTP request
    [200, { 'Content-Type' => 'text/plain' }, ['Hello']]
  end
end
