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

# These are the perms given to people for a associated voice-channel
TEXT_PERMS = Discordrb::Permissions.new
TEXT_PERMS.can_read_message_history = true
TEXT_PERMS.can_read_messages = true
TEXT_PERMS.can_send_messages = true

NEW_ROOM_NAME = '[New Room]'

bot = Discordrb::Bot.new token: ARGV.first, client_id: ARGV[1] 

bot.ready do
  bot.servers.each do |server_id, server|
    puts "Setting up [#{server.name}]"
    server.text_channels.select { |vc| vc.name == 'voice-channel' }.map(&:delete) # Remove previous text voice-channel's that are abandoned
    server.voice_channels.each { |vc| associate(vc) }
    OLD_VOICE_STATES[server_id] = server.voice_states.clone
  end
end

def simplify_voice_states(voice_states)
  clone = voice_states.clone
  clone.each { |user_id, state| clone[user_id] = state.voice_channel }
  
  return clone
end

def associate(voice_channel)
  server = voice_channel.server
  return if voice_channel == server.afk_channel # No need for AFK channel to have associated text-channel

  puts "Associating '#{voice_channel.name} / #{server.name}'"
  text_channel = server.text_channels.find { |tc| tc.id == ASSOCIATIONS[voice_channel.id] }

  if ASSOCIATIONS[voice_channel.id].nil? || text_channel.nil?
    text_channel = server.create_channel('voice-channel', 0) # Creates a matching text-channel called 'voice-channel'
    text_channel.topic = "Private chat for all those in the voice-channel [**#{voice_channel.name}**]."
    
    ASSOCIATIONS[voice_channel.id] = text_channel.id # Associate the two 
  end

  text_channel
end

def handle_user_change(action, voice_channel, user)
  puts "Handling user #{action} for '#{voice_channel.name} / #{voice_channel.server.name}' for #{user.distinct}"
  text_channel = associate(voice_channel) # This will create it if it doesn't exist. Pretty cool!

  # For whatever reason, maybe is AFK channel
  return if text_channel.nil?

  if action == :join
    text_channel.send_message("**#{user.display_name}** joined the voice-channel.")
  else
    text_channel.send_message("**#{user.display_name}** left the voice-channel.")
  end
end

# VOICE-CHANNEL CREATED
bot.channel_create(type: 2, name: not!(NEW_ROOM_NAME)) do |event|
  associate(event.channel)
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
  old = simplify_voice_states(OLD_VOICE_STATES[event.server.id])
  current = simplify_voice_states(event.server.voice_states)
  member = event.user.on(event.server)

  if event.server.voice_states != old || current[member.id].voice_channel != old[member.id].voice_channel
    # Something has happened
    handle_user_change(:leave, event.old_channel, member) unless event.old_channel.nil?
    handle_user_change(:join, event.channel, member) unless event.channel.nil?
  end

  OLD_VOICE_STATES[event.server.id] = event.server.voice_states.clone
end

bot.run