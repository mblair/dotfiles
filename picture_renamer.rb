#!/usr/bin/env ruby

require "exifr"

DATE_FORMAT = "%Y-%m-%dT%H%M%S"

Dir.glob("*.[Jj][Pp][Gg]").each do |f|
  if !EXIFR::JPEG.new(f).date_time.nil?
    #puts "using date_time"
    new_name = "#{EXIFR::JPEG.new(f).date_time.utc.strftime(DATE_FORMAT)}"
    if !EXIFR::JPEG.new(f).subsec_time_digitized.nil?
      new_name += ".#{EXIFR::JPEG.new(f).subsec_time_digitized}"
    end

    if !EXIFR::JPEG.new(f).software.nil? && EXIFR::JPEG.new(f).software == "Instagram"
      new_name += ".instagram"
    end

    new_name += ".jpg"
    File.rename(f, new_name)
  elsif !EXIFR::JPEG.new(f).gps_date_stamp.nil?
    #puts "using gps_date_stamp"
    year, month, date = EXIFR::JPEG.new(f).gps_date_stamp.split(':')[0..2]
    time_as_integers = EXIFR::JPEG.new(f).gps_time_stamp.map { |i| i.to_i }
    hour, minutes, seconds = time_as_integers.map { |i| sprintf("%02d", i) }
    new_name = "#{year}-#{month}-#{date}T#{hour}#{minutes}#{seconds}"

    if !EXIFR::JPEG.new(f).software.nil? && EXIFR::JPEG.new(f).software == "Instagram"
      new_name += ".instagram"
    end

    new_name += ".jpg"
    File.rename(f, new_name)
  else
    #puts "using File.mtime"
    new_name = File.mtime(f).utc.strftime(DATE_FORMAT)

    if !EXIFR::JPEG.new(f).software.nil? && EXIFR::JPEG.new(f).software == "Instagram"
      new_name += ".instagram"
    end

    new_name += ".jpg"
    File.rename(f, new_name)
  end
end

Dir.glob("*.MOV").each do |f|
  File.rename(f, "#{File.mtime(f).utc.strftime(DATE_FORMAT)}.mov")
end

# TODO: port to ES2015
# TODO: add MP4/THM support
