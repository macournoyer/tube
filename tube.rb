require "socket"
require "http/parser"
require "stringio"

class Tube
  def initialize(port, app)
    @server = TCPServer.new(port)
    @app = app
  end

  def start
    loop do
      socket = @server.accept
      connection = Connection.new(socket, @app)
      connection.process
    end
  end

  class Connection
    def initialize(socket, app)
      @socket = socket
      @app = app
      @parser = Http::Parser.new(self)
    end

    def process
      until @socket.closed? || @socket.eof?
        data = @socket.readpartial(1024)
        @parser << data
      end
    end

    def on_message_complete
      puts "#{@parser.http_method} #{@parser.request_path}"
      puts "  " + @parser.headers.inspect
      puts

      env = {}
      @parser.headers.each_pair do |name, value|
        # User-Agent => HTTP_USER_AGENT
        name = "HTTP_" + name.upcase.tr("-", "_")
        env[name] = value
      end
      env["PATH_INFO"] = @parser.request_path
      env["REQUEST_METHOD"] = @parser.http_method
      env["rack.input"] = StringIO.new

      send_response env
    end

    def send_response(env)
      status, headers, body = @app.call(env)

      @socket.write "HTTP/1.1 200 OK\r\n"
      @socket.write "\r\n"
      @socket.write "hello\n"

      close
    end

    def close
      @socket.close
    end
  end
end

class App
  def call(env)
    message = "Hello from the tube.\n"
    [
      200,
      { 'Content-Type' => 'text/plain', 'Content-Length' => message.size.to_s },
      [message]
    ]
  end
end

app = App.new
server = Tube.new(3000, app)
puts "Plugging tube into port 3000"
server.start