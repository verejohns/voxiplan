namespace :sessions do
  desc "Clear expired sessions (more than 7 days old)"
  task :cleanup => :environment do
    sql = "DELETE FROM sessions WHERE (updated_at < '#{Date.today - 7.days}')"
    ActiveRecord::Base.connection.execute(sql)
  end
  task :cleanpapertrail => :environment do
    puts 'Delete all Paper trail'
    PaperTrail::Version.delete_all
    sql = "DELETE FROM version_associations"
    ActiveRecord::Base.connection.execute(sql)
    puts 'Paper Trail Deleted!'
  end
end
