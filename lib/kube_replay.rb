Thread.abort_on_exception = true

class KubeReplay
  attr_accessor :context, :namespace, :pod, :container, :log_regex_pattern, :target_url, :context, :output,
                :target_client

  def initialize(opts)
    @namespace = opts[:namespace]
    @pod = opts[:pod]
    @container = opts[:container]
    @log_regex_pattern = opts[:log_regex_pattern]
    @target_url = opts[:target_url]

    kube_config = Kubeclient::Config.read(opts[:kube_config_file] || "#{ENV['HOME']}/.kube/config")
    @context = kube_config.context
    @heap = []
    @output = { requests: [], processed: 0, failed: 0 }
    @target_client = Faraday.new(url: @target_url)
  end

  def start
    Thread.new { watch_requests }
    Thread.new { process_requests }

    print_info

    loop do
      next if @output[:processed].zero?

      print_info
      puts format_line('PATH', 'STATUS', 'RESPONSE STATUS', 'SUCCESS')
      puts @output[:requests].last(15)
      sleep(1)
    end
  end

  def kube_client
    Kubeclient::Client.new(
      @context.api_endpoint,
      'v1',
      ssl_options: @context.ssl_options,
      auth_options: @context.auth_options
    )
  end

  def watch_requests
    kube_client.watch_pod_log(@pod, @namespace, container: @container) do |line|
      match = line.match(/(\S+)\s+(\S+)\s+(\S+)\s+(\[.*?\])\s+"(?<VERB>\S+)\s+(?<PATH>\S+)\s+(\S+)"\s+(?<CODE>\S+)\s+(?<SIZE>\S+)\s+(\S+)\s+(\S+)/)
      if match && match['VERB'].eql?('GET')
        path = match['PATH']
        status = match['CODE']

        @heap.append(Request.new(path, status))
      end
    end
  end

  def process_requests
    loop do
      r = @heap.shift
      next unless r

      r.verify_response(@target_client)
      @output[:requests] << r
      @output[:processed] += 1
      @output[:failed] += 1 unless r.response.success? # r.success?
    end
  end

  def failure_percent
    return 0.0 if @output[:processed].zero?

    (100 * @output[:failed].to_f / @output[:processed]).round(1)
  end

  def format_line(a, b, c, d)
    "#{a.ljust(80)} #{b.ljust(10)} #{c.ljust(20)} #{d.to_s.ljust(10)}"
  end

  def print_info
    system('clear') || system('cls')
    puts "#{'CLUSTER:'.ljust(50)} #{'NAMESPACE:'.ljust(20)} #{'POD:'.ljust(30)} #{'CONTAINER:'.ljust(30)}"
    puts "#{@context.api_endpoint.ljust(50)} #{@namespace.ljust(20)} #{@pod.ljust(30)} #{@container.ljust(30)}"
    puts "\nReplaying GET requests to #{@target_url}"
    puts "#{@output[:failed]} (#{failure_percent}%) invalid requests of #{@output[:processed]} replays\n\n"
  end
end
