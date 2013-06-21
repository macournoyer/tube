class Builder
  def run
    puts "You called run!"
  end
end

builder = Builder.new
builder.instance_eval "run"