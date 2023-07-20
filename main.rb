require 'kubeclient'
require 'openid_connect'
require 'yaml'
require './lib/kube_replay'
require './lib/request'

Thread.abort_on_exception = true

def main
  opts = YAML.parse_file('kube_replay_conf.yaml').to_ruby.symbolize_keys

  kube_replay = KubeReplay.new(opts)
  kube_replay.start
end

main
