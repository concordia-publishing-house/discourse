require 'csv'
require_relative 'mailers/report_mailer'

class UserReport
  
  attr_reader :email
  
  def initialize(start_time, end_time, options = {})
    @start_time = start_time.to_time
    @end_time = end_time.to_time
    raise StandardError, "Dates provided are not a valid range" if start_time >= end_time
    @users = []
    @path = nil
    @columns = [:username, :email, :last_seen_at, :topics_created, :topics_entered, :posts_created]
    @email = options[:email]
  end
  
  def generate!
    save_file!(build_csv)
    ReportMailer.csv(self).deliver if @email
  end
  
  def file_name
    name + ".csv"
  end
  
  def to_path
    @path
  end
  
  # email attrs
  def subject
    format = "%m/%d/%Y"
    "Innovation blog usage report for #{@start_time.strftime(format)}-#{@end_time.strftime(format)}"
  end

private
  
  def name
    format = "%m-%d-%Y"
    "user_report_#{@start_time.strftime(format)}_#{@end_time.strftime(format)}"
  end
  
  def save_file!(contents)
    fpath = "#{Rails.root}/tmp/reports/users/"
    FileUtils.mkdir_p(fpath)
    @path = fpath << name << ".csv"
    File.open(@path, File::WRONLY|File::CREAT) do |file|
      file.write(contents)
    end
  end
  
  def build_csv
    rows = []
    User.where("last_seen_at > ?", @start_time).find_each do |user|
      rows << row_for(user)
    end
    
    rows.unshift(@columns.map{ |column| column.to_s.gsub(/_/, ' ').capitalize })
    rows.map(&CSV.method(:generate_line)).join
  end
  
  def row_for(user)
    row = []
    @columns.each do |column|
      row << csv_value_for(user, column)
    end
    row
  end 
  
  def csv_value_for(user, column)
    case column
    when :username, :email, :last_seen_at
      user.send(column)
    when :topics_created
      user.topics.created_during(@start_time, @end_time).count
    when :topics_entered
      user.topic_users.visited_during(@start_time, @end_time).count
    when :posts_created
      user.posts.created_during(@start_time, @end_time).count
    else
      raise StandardError, "UserReport doesn't know how to convert column `#{column}`"
    end
  end
  
end
