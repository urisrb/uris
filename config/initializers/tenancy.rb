require_relative "../../lib/tenancy/job"

ActiveSupport.on_load(:active_job) { include Tenancy::Job }
