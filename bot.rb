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

NEW_ROOM_NAME = '[New Room]'

bot = Discordrb::Bot.new token: ARGV.first, client_id: ARGV[1] 

bot.ready do
  bot.servers.each do |server_id, server|
    puts "Setting up [#{server.name}]"
    server.text_channels.select { |vc| vc.name == 'voice-channel' }.map(&:delete) # Remove previous text voice-channel's that are abandoned
    server.voice_channels.each { |vc| associate(server, vc) }
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

bot.run