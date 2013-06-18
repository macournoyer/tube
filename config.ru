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

run App.new