require "socket"
require "http/parser"

class Tube
  attr_accessor :app

  def start(port)
    server = TCPServer.new(port)

    loop do
      socket = server.accept
      connection = Connection.new(socket, app)

      until socket.closed?
        data = socket.readpartial(1024)
        # puts data
        connection << data
      end
      # puts "done"
      # socket.close
    end
  end

  class Connection
    def initialize(socket, app)
      @socket = socket
      @app = app
      @parser = Http::Parser.new(self)
    end

    def <<(chunk)
      @parser << chunk
    end

    def on_message_complete
      # puts @parser.headers
      # @socket.close

      env = {}
      @parser.headers.each_pair do |name, value|
        name = "HTTP_" + name.upcase.tr('-', '_') # User-Agent => HTTP_USER_AGENT
        env[name] = value
      end
      env["PATH_INFO"] = @parser.request_path
      env["REQUEST_METHOD"] = @parser.http_method
      env["QUERY_STRING"] = @parser.query_string
      env["rack.input"] = StringIO.new

      process env
    end

    REASONS = {
      200 => "OK",
      404 => "Not Found"
    }

    def process(env)
      status, headers, body = @app.call(env)
      reason = REASONS[status]

      @socket.write "HTTP/1.1 #{status} #{reason}\r\n"
      headers.each_pair do |name, value|
        @socket.write "#{name}: #{value}\r\n"
      end
      @socket.write "\r\n"
      body.each do |chunk|
        @socket.write chunk
      end
      body.close

      @socket.close
    end
  end

  class Builder
    attr_reader :app

    def run(app)
      @app = app
    end
  end
end

# class App
#   def call(env)
#     message = "Hello from the tube.\n"
#     [
#       200,
#       { 'Content-Type' => 'text/plain', 'Content-Length' => message.size.to_s },
#       [message]
#     ]
#   end
# end

config = File.read("config.ru")
builder = Tube::Builder.new
builder.instance_eval config

server = Tube.new
server.app = builder.app
puts "Plugging tube to port 3000"
server.start 3000
