# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def generate_forms(contents)
  contents.rewind

  template_letter = File.read('templates/form_letter.erb')
  erb_template = ERB.new template_letter

  contents.each do |row|
    id = row[0]
    name = row[:first_name]

    zipcode = clean_zipcode(row[:zipcode])

    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)
  end
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def make_phone_hash(contents)
  phone_list = {}

  contents.each do |row|
    phone_number = row[:homephone]
    phone_number.gsub!(/[^0-9A-Za-z]/, '')

    if phone_number.length == 10
      phone_list[row[:first_name]] = phone_number
    elsif phone_number.length == 11
      phone_list[row[:first_name]] = phone_number[1..10] if phone_number[0] == 1
    end
  end

  phone_list
end

def generate_phone_list(contents)
  contents.rewind

  template_phone_list = File.read('templates/phone_list.erb')
  erb_template = ERB.new template_phone_list

  phone_list = make_phone_hash(contents)

  phone_list_content = erb_template.result(binding)

  save_phone_list(phone_list_content)
end

def save_phone_list(phone_list_content)
  Dir.mkdir('phone_list') unless Dir.exist?('phone_list')

  filename = 'phone_list/phone_list.html'

  File.open(filename, 'w') do |file|
    file.puts phone_list_content
  end
end

def generate_time_overview(contents)
  template_time_overview = File.read('templates/regtime_overview.erb')
  erb_template = ERB.new template_time_overview
  
  reg_hours = hour_statistics(contents)
  reg_days = day_statistics(contents)

  time_overview_content = erb_template.result(binding)

  save_time_overview(time_overview_content)
end

def hour_statistics(contents)
  contents.rewind

  reg_hours = {}

  contents.each do |row|
    regtime = Time.strptime(row[:regdate], '%m/%d/%y %k:%M')

    hour = regtime.hour

    if reg_hours.key?(hour)
      reg_hours[hour] = reg_hours[hour] + 1
    else
      reg_hours[hour] = 1
    end
  end

  reg_hours = reg_hours.sort_by { |_k, v| -v }
end

def day_statistics(contents)
  contents.rewind

  reg_days = {}

  contents.each do |row|
    regtime = Time.strptime(row[:regdate], '%m/%d/%y %k:%M')

    day = regtime.strftime('%A')

    if reg_days.key?(day)
      reg_days[day] = reg_days[day] + 1
    else
      reg_days[day] = 1
    end
  end

  reg_days = reg_days.sort_by { |_k, v| -v }
end

def save_time_overview(time_overview_content)
  Dir.mkdir('time_overview') unless Dir.exist?('time_overview')

  filename = 'time_overview/time_overview.html'

  File.open(filename, 'w') do |file|
    file.puts time_overview_content
  end
end

puts 'Event Manager: Initialized'

contents = CSV.open(
  'event_attendees_full.csv',
  headers: true,
  header_converters: :symbol
)

 generate_forms(contents)

 generate_phone_list(contents)

generate_time_overview(contents)

puts 'Event Manager: Done'
