require "http/parser"

class ParserDemo
  def initialize
    @parser = Http::Parser.new(self)
  end

  def on_message_complete
    puts "Method: " + @parser.http_method
    puts "Path: " + @parser.request_path
  end

  def parse
    @parser << "GET / HTTP/1.1\r\n"
    @parser << "Host: localhost:3000\r\n"
    @parser << "Accept: */*\r\n"
    @parser << "\r\n"    
  end
end

ParserDemo.new.parse