class App
  def call(env)
    sleep 5 if env["PATH_INFO"] == "/sleep"

    message = "Hello from the #{Process.pid}.\n"
    [
      200,
      { 'Content-Type' => 'text/plain', 'Content-Length' => message.size.to_s },
      [message]
    ]
  end
end

run App.new