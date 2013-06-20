require "socket"
require "http/parser"
require "stringio"
require "thread"

class Tube
  def initialize(app)
    @app = app
  end

  def start(port)
    server = TCPServer.new(port)

    loop do
      socket = server.accept
      Thread.new do
        connection = Connection.new(socket, @app)

        until socket.closed? || socket.eof?
          data = socket.readpartial(1024)
          connection << data
        end
      end
    end
  end

  class Connection
    def initialize(socket, app)
      @socket = socket
      @app = app
      @parser = HTTP::Parser.new(self)
    end

    def <<(data)
      @parser << data
    end

    def on_message_complete
      puts "#{@parser.http_method} #{@parser.request_path}"
      puts "  " + @parser.headers.inspect
      puts

      env = {}
      @parser.headers.each_pair do |name, value|
        # User-Agent => HTTP_USER_AGENT
        name = "HTTP_" + name.upcase.tr('-', '_')
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
      404 => "Not found"
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
      body.close if body.respond_to? :close

      @socket.close
    end
  end

  class Builder
    attr_reader :app

    def run(app)
      @app = app
    end

    def self.parse_file(file)
      config = File.read(file)
      builder = new
      builder.instance_eval(config)
      builder.app
    end
  end
end

app = Tube::Builder.parse_file("config.ru")
server = Tube.new(app)
puts "Plugging the tube to port 3000"
server.start 3000