module Agents
  class Teamspeak3VersionCheckerAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Teamspeak3 Version Checker Agent checks the last available version for a specific OS and arch and it can create event.

      `type` for checking server or client version.

      `os` for checking OS version like linux.

      `arch` for checking arch version like x86.

      `debug` is used for verbose mode.

      `decimal` for adding value with token decimal.

      The `changes only` option causes the Agent to report an event only when the status changes. If set to false, an event will be created for every check.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "version": "3.5.6",
            "checksum": "86381879a3e7dc7a2e90e4da1cccfbd2e5359b7ce6dd8bc11196d18dfc9e2abc",
            "mirrors": {
              "teamspeak.com": "https://files.teamspeak-services.com/releases/client/3.5.6/TeamSpeak3-Client-win64-3.5.6.exe"
            },
            "type": "client",
            "os": "windows",
            "arch": "x86_64"
          }
    MD

    def default_options
      {
        'type' => '',
        'os' => '',
        'arch' => '',
        'debug' => 'false',
        'emit_events' => 'true',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :emit_events, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :type, type: :array, values: ['server', 'client']
    form_configurable :os, type: :array, values: ['windows', 'linux', 'macos']
    form_configurable :arch, type: :array, values: ['x86', 'x86_64']
    def validate_options
      errors.add(:base, "type has invalid value: should be 'server' 'client'") if interpolated['type'].present? && !%w(server client).include?(interpolated['type'])

      errors.add(:base, "os has invalid value: should be 'windows' 'linux' 'macos'") if interpolated['type'].present? && !%w(windows linux macos).include?(interpolated['os'])

      errors.add(:base, "arch has invalid value: should be 'x86' 'x86_64'") if interpolated['type'].present? && !%w(x86 x86_64).include?(interpolated['arch'])

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def fetch()

      uri = URI.parse("https://www.teamspeak.com/versions/#{interpolated['type']}.json")
      response = Net::HTTP.get_response(uri)

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)

      if interpolated['changes_only'] == 'true'
        if payload != memory['last_status']
          if payload
            if "#{memory['last_status']}" == ''
              payload.each do |os,arch|
                arch.each do |version,data|
                  if os == interpolated['os'] && version == interpolated['arch']
                    event_created = data.dup
                    event_created['type'] = interpolated['type']
                    event_created['os'] = os
                    event_created['arch'] = version
                    create_event payload: event_created
                  end
                end
              end
            else
              last_status = memory['last_status']
              payload.each do |os,arch|
                found = false
                arch.each do |version,data|
                  last_status.each do |osbis,archbis|
                    archbis.each do |versionbis,databis|
                      if os == osbis && version == versionbis && data == databis
                        found = true
                      end
                      if interpolated['debug'] == 'true'
                        log "found is #{found}"
                      end
                    end
                  end
                  if found == false && os == interpolated['os'] && version == interpolated['arch']
                    if interpolated['debug'] == 'true'
                      log "found is #{found}! so event created"
                    end
                    event_created = data.dup
                    event_created['type'] = interpolated['type']
                    event_created['os'] = os
                    event_created['arch'] = version
                    create_event payload: event_created
                  else
                    if interpolated['debug'] == 'true'
                      log "found is #{found}! so nothing created"
                    end
                  end
                end
              end
            end
          end
          memory['last_status'] = payload
        end
      else
        if payload != memory['last_status']
          memory['last_status'] = payload
        end
        create_event payload: payload
      end

    end
  end
end
