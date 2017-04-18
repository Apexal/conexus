if ARGV.length != 2
  puts 'Usage: ruby bot.rb <token> <client_id>'
  exit
end

require 'discordrb'

# This hash will store voice channel_ids mapped to text_channel ids
# {
#   "267526886454722560": "295714345344565249",
#   etc.
# }
ASSOCIATIONS = Hash.new
OLD_VOICE_STATES = Hash.new

NEW_ROOM_NAME = '[New Room]'

bot = Discordrb::Bot.new token: ARGV.first, client_id: ARGV[1] 

bot.ready do
  bot.servers.each do |server_id, server|
    puts "Setting up [#{server.name}]"
    server.text_channels.select { |vc| vc.name == 'voice-channel' }.map(&:delete) # Remove previous text voice-channel's that are abandoned
    server.voice_channels.each { |vc| associate(server, vc) }
    OLD_VOICE_STATES[server_id] = server.voice_states.clone
  end
end

def associate(server, voice_channel)
  return if voice_channel == server.afk_channel # No need for AFK channel to have associated text-channel

  puts "Associating [#{server.name}]>#{voice_channel.name}"

  if ASSOCIATIONS[voice_channel.id].nil? || server.text_channels.find { |tc| tc.id == ASSOCIATIONS[voice_channel.id] }.nil?
    text_channel = server.create_channel('voice-channel', 0) # Creates a matching text-channel called 'voice-channel'
    text_channel.topic = "Private chat for all those in the voice-channel [**#{voice_channel.name}**]."
    
    ASSOCIATIONS[voice_channel.id] = text_channel.id # Associate the two

    return text_channel  
  end

  nil
end

def handle_user_change(voice_channel, user)

end

# VOICE-CHANNEL CREATED
bot.channel_create(type: 2, name: not!(NEW_ROOM_NAME)) do |event|
  associate(event.server, event.channel)
  #event.server.create_channel(NEW_ROOM_NAME, 2)
end

# VOICE-CHANNEL DELETED
bot.channel_delete(type: 2, name: not!(NEW_ROOM_NAME)) do |event|
  event.server.text_channels.select { |tc| tc.id == ASSOCIATIONS[event.id] }.map(&:delete)
end


# TEXT-CHANNEL CREATED
bot.channel_create(type: 0) do |event|
  #puts "new tc"
end

# TEXT-CHANNEL DELETED
bot.channel_delete(type: 0) do |event|
  #puts "bye bye tc"
end

bot.voice_state_update do |event|
  old = OLD_VOICE_STATES[event.server.id]

  if event.server.voice_states != old
    # Something has happened

    #puts "I sense a change"

    handle_user_change(event.old_channel, event.user) unless event.old_channel.nil?
    handle_user_change(event.channel, event.user)
  end

  OLD_VOICE_STATES[event.server.id] = event.server.voice_states.clone
end

bot.run