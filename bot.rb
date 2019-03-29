require 'dotenv/load'
require 'discordrb'

CATEGORY_PERMS = Discordrb::Permissions.new
CATEGORY_PERMS.can_read_messages = true

# Make sure environment variables are set
vars = %w(DISCORD_BOT_TOKEN DISCORD_CLIENT_ID DISCORD_COMMAND_PREFIX)
vars.each do |var|
    if !ENV.key?(var) then
        puts "Missing environment variable #{var}"
        exit(1)
    end
end

BOT = Discordrb::Commands::CommandBot.new token: ENV['DISCORD_BOT_TOKEN'], client_id: ENV['DISCORD_CLIENT_ID'], prefix: ENV['DISCORD_COMMAND_PREFIX']

def create_category(server)
    category = server.channels.find { |c| c.name == 'Current Voice Channel'}
    
    if category.nil? then
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
    name = event.channel.name
    category = event.server.channels.find { |c| c.type == 4 && c.name == 'Current Voice Channel' }
    event.server.create_channel(name, 0, parent: category, topic: "Discussion room for the voice channel #{name}")
end

puts "Bot invite url: #{BOT.invite_url}+&permissions=8"
BOT.run