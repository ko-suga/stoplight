require 'cgi'

# Stoplight Provider for Icinga (Using Icinga Web REST API)
#
# - critical host/service: Displays the tile as red
# - warning host/service: Displays the tile as yellow
# - notification disabled host/service: Behave as disabled
# - acknowledged service/host: Behave as disabled
#
# Configuration example
#
#  -
#    type: 'icinga'
#    url: http://icinga.example.com
#    kind: service # or host
#    apikey: stoplight
#
module Stoplight::Providers
  class Icinga < Provider

    INFO_KEYS = %w(name current_state last_check notifications_enabled problem_has_been_acknowledged).freeze

    def initialize(options ={})
      raise ArgumentError, "'kind' must be supplied to the Provider. Please add 'kind' => '...' to your hash." unless options['kind']
      raise ArgumentError, "'kind' must be the one of 'host' or 'service' to the Provider: #{options['kind']}" unless options['kind'] =~ /host|service/
      raise ArgumentError, "'apikey' must be supplied as an option to the Provider. Please add 'apikey' => '...' to your hash." unless options['apikey']
      super(options)
    end

    def projects
      if @response.nil? || @response.parsed_response.nil? || @response.parsed_response['result'].nil?
        @projects ||= []
      else
        @projects ||= [@response.parsed_response['result']].flatten.collect do |project|
          Stoplight::Project.new({
           :name => kind == 'host' ? project['HOST_NAME'] : "#{project['HOST_NAME']}:#{project['SERVICE_NAME']}",
           :build_url => '',
           :last_build_id => '',
           :last_build_time => project["#{attr_prefix}_LAST_CHECK"],
           :last_build_status => tile_status(project),
           :current_status => activity_status(project),
           :culprits => []
          })
        end
      end
    end

    protected
    def builds_path
      "/icinga-web/web/api/service/#{columns}/authkey=#{apikey}/json"
    end

    private
    def tile_status(project)
      return -1 if disabled?(project)
      return 1 if activity_status(project) == 1 # warning
      project["#{attr_prefix}_CURRENT_STATE"] == '2' ? 1 : 0 # critical or nothing
    end

    def activity_status(project)
      return -1 if disabled?(project)
      project["#{attr_prefix}_CURRENT_STATE"] == '1' ? 1 : 0
    end

    # Returns whether the host or the service disabled
    def disabled?(project)
      project["#{attr_prefix}_NOTIFICATIONS_ENABLED"] == '0' or project["#{attr_prefix}_PROBLEM_HAS_BEEN_ACKNOWLEDGED"] == '1'
    end

    def kind
      @kind ||= options['kind']
    end

    def apikey
      @apikey ||= options['apikey']
    end

    def attr_prefix
      @attr_prefix ||= kind.upcase
    end

    def columns
      @columns ||= begin
                     cols = INFO_KEYS.map {|attr| "#{attr_prefix}_#{attr.upcase}" }
                     cols << 'HOST_NAME' if kind == 'service'
                     CGI.escape("columns[#{cols.join('|')}]")
                   end
    end

  end

end

