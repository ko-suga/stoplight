
# Stoplight Provider for Monit
#
# - limit matched: Displays the tile as red
# - unmonitored: Displays the tile as yellow
#
# Configuration example
#
#  -
#    type: 'monit'
#    url: http://monit.example.com
#    username: admin
#    password: monit
#
module Stoplight::Providers
  class Monit < Provider

    def projects
      if @response.nil? || @response.parsed_response.nil? || @response.parsed_response['monit']['service'].nil?
        @projects ||= []
      else
        host = @response.parsed_response['monit']['server']['localhostname']
        @projects ||= [@response.parsed_response['monit']['service']].flatten.collect do |project|
          Stoplight::Project.new({
           :name => "#{host}:#{project['name']}",
           :build_url => '',
           :last_build_id => '',
           :last_build_time => project['collected_sec'],
           :last_build_status => tile_status(project),
           :current_status => activity_status(project),
           :culprits => []
          })
        end
      end
    end

    protected
    def builds_path
      '/_status?format=xml'
    end

    private
    def tile_status(project)
      return 1 if activity_status(project) == 1
      case project['status'].to_i
      when 2 then 1
      else project['status'].to_i
      end
    end

    def activity_status(project)
      case project['monitor'].to_i
      when 1 then 0 # monitoring
      when 0 then 1 # unmonitored
      else -1       # unknown case
      end
    end

  end

end

