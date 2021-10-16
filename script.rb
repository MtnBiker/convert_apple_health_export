#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'time'

class Record
  attr_accessor  :systolic, :diastolic, :hr, :time

  def initialize(systolic, diastolic, hr, time)
    @systolic = systolic
    @diastolic = diastolic
    @hr = hr
    @time = time
  end

  def to_csv
    # [formatted_time, systolic, diastolic, hr]
    # At least for now I just want time as is because I store in a db that knows about time
    [time, systolic, diastolic, hr]
  end

  private

  def formatted_time
    Time.parse(time).strftime('%Y-%d-%m %H:%M:%S').to_s
  end
end

module ParseXML
  extend self

  XPATH_SYSTOLIC =  "//Record[contains(@type,'HKQuantityTypeIdentifierBloodPressureSystolic')]"
  XPATH_DIASTOLIC = "//Record[contains(@type,'HKQuantityTypeIdentifierBloodPressureDiastolic')]"
  # Withing putting HR in two different places
  XPATH_HEARTRATE_RESTING=  "//Record[contains(@type,'HKQuantityTypeIdentifierRestingHeartRate')]"
  XPATH_HEARTRATE=          "//Record[contains(@type,'HKQuantityTypeIdentifierHeartRate')]"

  def call(path)
    document = File.open(path) { |f| Nokogiri::XML(f) }
    systolic_records =   document.xpath(XPATH_SYSTOLIC).map(&:to_h)
    diastolic_records =  document.xpath(XPATH_DIASTOLIC).map(&:to_h)
    resting_hr_records = document.xpath(XPATH_HEARTRATE_RESTING).map(&:to_h)
    hr_records = document.xpath(XPATH_HEARTRATE).map(&:to_h)

    [systolic_records, diastolic_records, resting_hr_records, hr_records]
  end
end

module CreateCSV
  extend self

  def call(records, path)
    CSV.open(path, 'wb') do |csv|
      csv << %w[time systolic diastolic hr]
      records.each do |record|
        csv << record.to_csv
      end
    end
  end
end

module JoinRecords
  extend self

  def call(systolic_records, diastolic_records, resting_hr_records, hr_records)
    records = systolic_records.each_with_object([]) do |record, accu|
      count =+ 1
      pair = find_matching_value(record['creationDate'], diastolic_records)
      rhr =   find_matching_value(record['creationDate'], resting_hr_records)
      hr = find_matching_value(record['creationDate'], hr_records)
      if hr.to_i < rhr.to_i
        hr = rhr
      end
      accu << Record.new(record['value'], pair, hr, record['creationDate'])
    end

    records.uniq { |p| p.time }.sort_by(&:time)
  end

  private

  def find_matching_value(date, records)
    # Not matching complete date because heart rate is recorded slightly later. Probably show make exact match for systolic and diastolic and use this just for heart rate
    matching_item = records.find { |sr| sr['creationDate'][0..14] == date[0..14] }
    matching_item['value'] if matching_item != nil
  end
end

module ConvertXML
  extend self

  def call(input_path, export_path)
    systolic_records, diastolic_records, resting_hr_records, hr_records = ParseXML.call(input_path)
    records = JoinRecords.call(systolic_records, diastolic_records, resting_hr_records, hr_records)

    puts "Found #{records.count} records, creating CSV"

    CreateCSV.call(records, export_path)
  end
end

ConvertXML.call('export.xml', 'export.csv')