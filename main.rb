#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require
require 'pp'
require 'json'
require 'securerandom'
require "./game_master"

class Faye::WebSocket
  attr_accessor :user_id, :user_name
end


gm = GameMaster.new()

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env, nil, {ping: 15})
    ws.on :open do |event|
      ## 新規接続処理
      p "connect!"
      new_user_id = SecureRandom.hex(8)
      p "generate new id: #{new_user_id}"
      # set id
      ws.user_id = new_user_id  
      gm.add_connection(new_user_id, ws)
      # set user name
      gm.set_user_name(new_user_id,"user_#{new_user_id.to_s[0..3]}")
      p "send log: "
      gm.send_log(new_user_id)
    end

    ws.on :message do |event|
      p "recieved from #{ws.user_id}"
      json = JSON.parse(event.data)
      action = OekakiAction.newFromJSON(json)
      p "message type: #{action.type}" 
      ##TODO こここの処理を後々game_master側に移す
      case action.type
      when ActionType::CLEAR then
        gm.clear_log
      when ActionType::WRITE then
        p action.color
        ## paint logを記録
        gm.record_log action
        gm.send_action_broadcast(action)
      when ActionType::CHAT then
        ## message logを記録
        ## 今は同じ場所に記録
        gm.record_log action
        # 答えをチャレンジしておく
        action.user_name = gm.id_to_name(ws.user_id)
        gm.challenge_answer(ws.user_id, action.message)
        gm.send_action_broadcast(action)
      else
      end
    end

    ws.on :close do |event|
      #p [:close, event.code, event.reason]
      p "disconnect #{ws.user_id}"
      gm.connection_pool.delete(ws.user_id)
      ws = nil
    end

    # Return async Rack response
    ws.rack_response

  else
    # Normal HTTP request
    p env["REQUEST_PATH"]
    path = env["REQUEST_PATH"]
    case path
    when /\/master\/start/
      gm.game_start()
    else
      p "else path: (#{path})"
    end
    
    [200, { 'Content-Type' => 'text/plain' }, ['Hello']]
  end
end


