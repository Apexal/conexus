SCHWERN_UID = 288_032_693_164_310_528

require 'rubygems'

require 'bundler/setup'
Bundler.setup(:default)

require 'fileutils'
require 'yaml'
require 'discordrb'
require 'pry'

ASSOCIATIONS_FILE = 'local/associations.yaml'.freeze
SERVER_NAMINGS_FILE = 'local/server_namings.yaml'.freeze

REQUIRED_ENVS = %w[CONEXUS_TOKEN CONEXUS_CLIENT_ID].freeze

OWNER_PM_MESSAGE = <<~MESSAGE.freeze
  Thank you for using **Conexus**!
  To change the name of associated text-channels, type **IN THE SERVER**: `set-name 'new-name-here'`
MESSAGE

module MoreStrings
  refine String do    
    def blank?
      empty? || /\A[[:space:]]*\z/.match?(self)
    end
  end
  
  refine NilClass do
    def blank?
      true
    end
  end
end

using MoreStrings

def check_args
  if !ARGV.empty?
    puts <<~USAGE
      Usage: ruby bot.rb
      
      Environment variables:
        CONEXUS_TOKEN - Your Discord API token
        CONEXUS_CLIENT_ID - Your Discord API client ID
    USAGE
    exit
  end
  
  REQUIRED_ENVS.each do |name|
    raise "Environment variable #{name} not set" if ENV[name].blank?
  end
end

def run
  check_args
  
  @bot = Discordrb::Commands::CommandBot.new(
    token: ENV["CONEXUS_TOKEN"],
    client_id: ENV["CONEXUS_CLIENT_ID"],
    prefix: '!',
    advanced_functionality: true
  )

  @bot.ready do |_|
    @bot.servers.each do |_, server|
      setup_server(server)
    end
    @bot.set_user_permission(SCHWERN_UID, 3)
  end

  @bot.server_create do |event| 
    event.server.member(event.BOT.profile.id).nick = "🔗"
    event.server.owner.pm(OWNER_PM_MESSAGE)
    setup_server(event.server)
  end
  
  # VOICE-CHANNEL CREATED
  @bot.channel_create(type: 2) do |event|
    associate(event.channel)
  end

  # VOICE-CHANNEL DELETED
  @bot.channel_delete(type: 2) do |event|
    event.server.text_channels.select { |tc| tc.id == @associations[event.id] }.map(&:delete)
    trim_associations
  end

  @bot.voice_state_update do |event|
    # old = simplify_voice_states(OLD_VOICE_STATES[event.server.id])
    # current = simplify_voice_states(event.server.voice_states)
    member = event.user.on(event.server)

    if event.old_channel != event.channel # current[member.id] != old[member.id]
      # Something has happened
      handle_user_change(:leave, event.old_channel, member) unless event.old_channel.nil?
      handle_user_change(:join, event.channel, member) unless event.channel.nil?
    end
  end

  @bot.command(:creator, description: 'Open console.', permission_level: 3) do |event|
    binding.pry

    nil
  end

  @bot.command(:conexus,
    description: 'Set the name of the text-channels created for each voice-channel.',
    usage: '`!conexus "new-name"`',
    min_args: 1,
    max_args: 1,
    permission_level: 2
  ) do |event, new_name|
    new_name.downcase!
    new_name.strip!
    new_name.gsub!(/\s+/, '-')
    new_name.gsub!(/[^a-zA-Z0-9_-]/, '')
    new_name = new_name[0..30]

    # Make sure channel doesn't already exist
    unless event.server.text_channels.find { |tc| tc.name == new_name }.nil?
      return event.user.pm "Invalid name! `##{new_name}` is already used on the server."
    end

    old_name = @server_namings[event.server]
    @server_namings[event.server.id] = new_name
    save_local_files

    # Rename all the old channels to the new name
    event.server.text_channels.select { |tc| tc.name == old_name }.each do |tc|
      tc.name = new_name
    end

    event.user.pm "Set text-channel name to `##{new_name}`."
    nil
  end

  @bot.command(:rename,
    description: 'Set the name of **ONE** text-channel created for a voice-channel.',
    usage: '`!rename "new-name"` in the special text-channel you want to rename',
    min_args: 1,
    max_args: 1,
    permission_level: 2
  ) do |event, new_name|
    new_name.downcase!
    new_name.strip!
    new_name.gsub!(/\s+/, '-')
    new_name.gsub!(/[^a-zA-Z0-9_-]/, '')
    new_name = new_name[0..30]

    ids = @associations.values

    # Make sure channel doesn't already exist
    unless event.server.text_channels.find { |tc| tc.name == new_name && !ids.include?(tc.id) }.nil?
      return event.user.pm "Invalid name! `##{new_name}` is already used on the server."
    end

    # Make sure is associated channel
    unless ids.include?(event.channel.id)
      return event.channel.send_message('You must use this in the special text-channel!')
    end

    # Rename all the old channels to the new name
    event.channel.name = new_name

    'Renamed channel!'
  end
  
  # BOT.invisible
  puts "Oauth url: #{@bot.invite_url}+&permissions=8"

  @bot.run :async
  @bot.dnd
  @bot.profile.name = 'conexus'
  @bot.sync
end

def setup_local_files
  FileUtils.touch(ASSOCIATIONS_FILE)
  @associations = YAML.load_file(ASSOCIATIONS_FILE) || {}

  FileUtils.touch(SERVER_NAMINGS_FILE)
  @server_namings = YAML.load_file(SERVER_NAMINGS_FILE) || {}
  @server_namings.default = 'voice-channel'
  
  return
end

def setup_text_permissions
  @text_perms = Discordrb::Permissions.new
  @text_perms.can_read_message_history = true
  @text_perms.can_read_messages = true
  @text_perms.can_send_messages = true
end

def setup_server(server)
  puts "Setting up [#{server.name}]"
  setup_local_files
  setup_text_permissions
  puts 'Trimming associations'
  trim_associations
  puts 'Cleaning up after restart'
  server.text_channels.select { |tc| tc.name == @server_namings[server.id] }.each do |tc|
    unless @associations.values.include?(tc.id)
      tc.delete
      next
    end
    voice_channel = server.voice_channels.find { |vc| vc.id == @associations.key(tc) }
    tc.users.reject { |u| voice_channel.users.include?(u) }.each do |u|
      tc.define_overwrite(u, 0, 0)
    end
  end

  server.voice_channels.each { |vc| associate(vc) }

  @bot.set_user_permission(server.owner.id, 2)
  puts "Done\n"
end

def simplify_voice_states(voice_states)
  clone = voice_states.clone
  clone.each { |user_id, state| clone[user_id] = state.voice_channel }
  
  return clone
end

def trim_associations
  ids = @bot.servers.map { |_, s| s.voice_channels.map(&:id) }.flatten
  @associations.delete_if { |vc_id, _| !ids.include?(vc_id) }

  save_local_files
end

def default_text_channel_name(voice_channel_name)
  voice_channel_name.downcase.strip.gsub(/\s+/, '-') + "-text"
end

def associate(voice_channel)
  server = voice_channel.server

  # No need for AFK channel to have associated text-channel
  return if voice_channel == server.afk_channel

  puts "Associating '#{voice_channel.name} / #{server.name}'"
  text_channel = server.text_channels.find { |tc| tc.id == @associations[voice_channel.id] }

  if text_channel.nil?
    puts "Not found... creating..."
    @server_namings[server.id] = default_text_channel_name(voice_channel.name)
    # Creates a matching text-channel called 'voice-channel'
    text_channel = server.create_channel(@server_namings[server.id], 0)
    text_channel.topic = "Private chat for all in [**#{voice_channel.name}**]."
    
    voice_channel.users.each do |u|
      text_channel.define_overwrite(u, @text_perms, 0)
    end

    # Set default perms as invisible
    text_channel.define_overwrite(
      voice_channel.server.roles.find { |r| r.id == voice_channel.server.id }, 0, @text_perms
    )
    @associations[voice_channel.id] = text_channel.id
    save_local_files
  end

  text_channel
end

def handle_user_change(action, voice_channel, user)
  puts "Handling user #{action} for '#{voice_channel.name} / #{voice_channel.server.name}' for #{user.distinct}"
  # This will create it if it doesn't exist.
  text_channel = associate(voice_channel)

  # For whatever reason, maybe is AFK channel
  return if text_channel.nil?

  if action == :join
    text_channel.send_message("**#{user.display_name}** joined the voice-channel.")
    text_channel.define_overwrite(user, @text_perms, 0)
  else
    text_channel.send_message("**#{user.display_name}** left the voice-channel.")
    text_channel.define_overwrite(user, 0, 0)
  end
end

def save_local_files
  File.open(ASSOCIATIONS_FILE, 'w') {|f| f.write @associations.to_yaml }
  File.open(SERVER_NAMINGS_FILE, 'w') {|f| f.write @server_namings.to_yaml }
end

run