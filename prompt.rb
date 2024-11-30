#!/usr/bin/env ruby
# frozen_string_literal: true

require 'tty-prompt'
require 'tty-spinner'
require 'date'
require 'colorize'
require 'open-uri'
require 'httparty'

spinner = TTY::Spinner.new('[:spinner] Loading :title')
promptty = TTY::Prompt.new
ROOT_DIR = File.expand_path(File.dirname(__FILE__))

def display_banner
  terminal_width = IO.console.winsize[1]
  banner_path = File.join(ROOT_DIR, "module/banner")
  if File.exist?(banner_path)
    message = File.open(banner_path, 'r', &:read)
  else
    puts "Banner not found".red
    return
  end

  message.split("\n").each do |line|
    padding = [(terminal_width - line.length) / 2, 0].max
    puts ' ' * padding + line
  end
end

spinner.update(title: 'Prompt')
spinner.auto_spin
sleep 3
class Prompt
  def initialize(prompt, spinner)
    @commands = {
      'help' => [method(:help), false],
      'exit' => [method(:exit), false],
      'quote' => [method(:quote), false],
      'spotify' => [method(:spotify), true]
    }
    @promptty = prompt
    @spin = spinner
  end

  def valid_shell_command?(cmd)
    # Check if the command exists in the shell
    system("command -v #{cmd} > /dev/null 2>&1")
  end

  def start
    display_banner

    loop do
      input = @promptty.ask("#{Date.today} \\>")
      break if input.nil?

      input.strip!
      exec_command(input)
    end
  end

  def requires_arguments?(command)
    return true if @commands[command][1]

    false
  end

  def exec_command(input)
    command, *args = input.split
    if @commands.key?(command)
      @commands[command][0].call(*args)
    elsif valid_shell_command?(command)
      if command == 'cd'
        Dir.chdir(args[0] || Dir.name)
        @promptty.ok("shell::#{command} (executed)")
      elsif command == 'clear'
        system('clear')
        display_banner
      else
        system(input)
        @promptty.ok("shell::#{command} (executed)")
      end
    else
      @promptty.error("Unknown Command: #{command}, Type 'help' for a list of commands")
    end
  end

  def help
    puts '[Available Commands]'
    @commands.each_key { |command| puts requires_arguments?(command) ? "-> #{command} [arg]" : "-> #{command}" }
  end

  def exit
    if @promptty.yes?('Exit?')
      3.downto(0) do |i|
        print "Exiting program in #{i}...".yellow+"\r"

        print 'Exiting program successfully.'.red if i < 1
        $stdout.flush
        sleep 1
      end
      exit!
    else
      @promptty.ok('Running the program')
    end
  end

  def resolve_api(method, args = nil)
    url_api = 'https://api-mininxd.vercel.app/'
    headers = {
      "accept": 'application/json'
    }
    case method
    when 'quotes'
      responses = HTTParty.get(url_api + method, headers: headers)
    when 'spotify'
      responses = HTTParty.get("#{url_api}#{method}?url=https://open.spotify.com/intl-id/track/#{args}",
                               headers: headers)
    else
      return nil
    end
    if responses.code == 400 || responses.code != 200 || responses["statusCode"] == 400 || responses["statusCode"] != 200
      nil
    else
      responses.to_h
    end
  end

  def quote
    @spin.update(title: 'quotes API')
    @spin.auto_spin
    quotes = resolve_api('quotes')
    if quotes.nil?
      @spin.error('(undone api)')
      @promptty.error('Error resolving api...')
    else
      @spin.success('(done)')

      puts "\n\"#{quotes['text']}\"\n— #{quotes['author']}\n\n"
    end
  end

  def spotify(code = nil)
    if code.nil?
      @promptty.error("Error: please provide track code to fetch (e.g.. 'spotify 61mWefnWQOLf90gepjOCb3')")
    else
      @spin.update(title: "spotify API (#{code})")
      @spin.auto_spin
      spot = resolve_api('spotify', code)
      Dir.mkdir("saved_images") unless Dir.exist?("saved_images")
      if spot.nil?
        @spin.error('(undone api)')
        @promptty.error('Error: Invalid track code given.')
      else
        @spin.success('(done)')
        URI.open(spot['cover_url']) do |image|
          File.open("saved_images/#{spot['name']}.jpg", 'wb') { |file| file.write(image.read) }
        end
        puts "
        Name : #{spot['name']}
        Artists : #{spot['artists'].join(', ')}
        Album Name : #{spot['album_name']}
        Release Date : #{spot['release_date']}
        Cover URL : #{spot['cover_url']}\n\n"
      end
    end
  end
end

b_prompt = Prompt.new(promptty, spinner)

spinner.success('(done)')

sleep 0.5

b_prompt.start
