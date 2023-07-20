class Request
  attr_accessor :path, :status, :response

  def initialize(path, status)
    @path = path
    @status = status
    @response = nil
  end

  def success?
    @response.status.to_s == @status
  end

  def failed?
    !success?
  end

  def verify_response(client)
    @response = client.get(@path)
  end

  def format_line(a, b, c, d)
    "#{a.ljust(80)} #{b.ljust(10)} #{c.ljust(20)} #{d.to_s.ljust(10)}"
  end

  def to_s
    format_line(@path, @status, @response.status.to_s, success?.to_s)
  end
end
