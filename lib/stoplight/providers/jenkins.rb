#
# Stoplight Provider for Jenkins CI (http://jenkinsci.org)
#
# Jenkis inherits from the MultProjectStandard
#

module Stoplight::Providers
  class Jenkins < MultiProjectStandard
    def provider
      'jenkins'
    end

    def projects
      if @response.nil? || @response.parsed_response.nil? || @response.parsed_response['Projects'].nil?
        @projects ||= []
      else
        # Jenkins doesn't return an array when there's only one job...
        @projects ||= [@response.parsed_response['Projects']['Project']].flatten.collect do |project|
          Stoplight::Project.new({
           :name => project['name'],
           :build_url => project['webUrl'],
           :last_build_id => project['lastBuildLabel'],
           :last_build_time => project['lastBuildTime'],
           :last_build_status => status_to_int(project['lastBuildStatus']),
           :current_status => activity_to_int(project['activity']),
           :culprits => @options['culprits'] ? get_culprits(project['name']) : []
          })
        end
      end
    end

    private
    def get_culprits(name)
    	# grab fullName, and the address property from the users who are culprits on the last build
      response = load_server_data(:path => "/job/#{name}/lastBuild/api/json?tree=culprits[fullName,property[address]]")

      return [] if response.nil? || response.parsed_response.nil? || response.parsed_response['culprits'].nil?

      # for each culprit in culprits get their fullName and email and store it as a hash
      culprits = response.parsed_response['culprits'].collect do |culprit|
        user = { 'name' => culprit['fullName'] }

        culprit['property'].each do |property|
          unless property['address'].nil?
          	# create a hash of users email to use for their gravatar
            hash = Digest::MD5.hexdigest(property['address'].downcase)
            user['gravatar'] = "http://www.gravatar.com/avatar/#{hash}.jpg"
          end
        end
        # reuse culprit object
        culprit = user
      end

      culprits.uniq
    end
  end
end
