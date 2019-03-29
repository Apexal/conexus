require 'dotenv/load'
require 'discordrb'

CATEGORY_PERMS = Discordrb::Permissions.new
CATEGORY_PERMS.can_read_messages = true

# Make sure environment variables are set
vars = %w(DISCORD_BOT_TOKEN DISCORD_CLIENT_ID DISCORD_COMMAND_PREFIX)
vars.each do |var|
    if !ENV.key?(var)
        puts "Missing environment variable #{var}"
        exit(1)
    end
end

BOT = Discordrb::Commands::CommandBot.new token: ENV['DISCORD_BOT_TOKEN'], client_id: ENV['DISCORD_CLIENT_ID'], prefix: ENV['DISCORD_COMMAND_PREFIX']

def create_category(server)
    category = server.channels.find { |c| c.name == 'Current Voice Channel'}
    
    if category.nil?
        category = server.create_channel('Current Voice Channel', 4, reason: "To hold text channels for each voice channel. DO NOT TOUCH")
        category.define_overwrite(server.id, 0, CATEGORY_PERMS)
        puts "'Current Voice Channel' category created on server #{server.name}"
    else
        puts "'Current Voice Channel' category already exists on server #{server.name}"
    end

    category
end

BOT.command :conexus do |event|
    create_category(event.server)
    "I am made and maintained by **Frank Matranga**: https://github.com/Apexal/conexus"
end

BOT.command :setup do |event|
    create_category(event.server)
    "Setup this server"
end


# When the bot is added to a server
BOT.server_create do |event| 
    create_category(event.server)
end

# When voice channel is created
BOT.channel_create(type: 2) do |event|
    associated_channel(event.channel)
end

def associated_channel(voice_channel)
    category = voice_channel.server.channels.find { |c| c.type == 4 && c.name == 'Current Voice Channel' }

    text_channel = voice_channel.server.text_channels.find { |c| !c.topic.nil? && c.topic.split(" | ").last.resolve_id == voice_channel.id }
    if text_channel.nil?
        text_channel = voice_channel.server.create_channel(voice_channel.name, 0, parent: category, topic: "🔗 Discussion room for the voice channel #{voice_channel.name}. | *Please do not edit this channel topic.* | #{voice_channel.id}")
        text_channel.send_message("This is an automated discussion room for the voice channel **#{voice_channel.name}**.")
    end
    text_channel
end

def member_joined_voice_channel(member, voice_channel)
    puts "#{member.display_name} joined voice channel \"#{voice_channel.name}\""

    text_channel = associated_channel(voice_channel)
    text_channel.define_overwrite(member, CATEGORY_PERMS, 0)
end

def member_left_voice_channel(member, voice_channel)
    puts "#{member.display_name} left voice channel \"#{voice_channel.name}\""

    text_channel = associated_channel(voice_channel)
    text_channel.delete_overwrite(member)
end

BOT.voice_state_update do |event|
    member = event.user.on(event.server)
  
    if event.old_channel != event.channel
        member_left_voice_channel(member, event.old_channel) unless event.old_channel.nil?
        member_joined_voice_channel(member, event.channel) unless event.channel.nil?
    end
end

puts "Bot invite url: #{BOT.invite_url}+&permissions=8"
BOT.run