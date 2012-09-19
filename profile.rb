#! /usr/bin/ruby

require 'optparse'

csvfile = nil

opt_parse = OptionParser.new do |opt_parse|
  opt_parse.banner = "Usage: profile.rb [options]"
  opt_parse.separator ""
  opt_parse.separator "Options:"

  opt_parse.on("--csvfile FILENAME", "Save CPU, GPU, GPU memory usage in CSV format to FILENAME.") do |csvfilename|
    csvfile = File.open(csvfilename, 'w')
  end

  opt_parse.on_tail("--help", "Show this message.") do
    puts opt_parse
    exit
  end
end # opt_parse = OptionParse new do |opt_parse|

opt_parse.parse!(ARGV)

File.open('/proc/stat', 'r') do |stat|
  stat.seek(0, IO::SEEK_SET)
  stat_output = stat.gets

  cpu_times = stat_output.scan(/cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)[0]
  cpu_total_old = cpu_times.inject{|sum, x| sum.to_i + x.to_i}
  cpu_idle_old = cpu_times[3].to_i

  loop do
    stat.seek(0, IO::SEEK_SET)
    stat_output = stat.gets
    nvidia_output = `nvidia-smi -q --display=UTILIZATION`

    cpu_times = stat_output.scan(/cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)[0]
    cpu_total_new = cpu_times.inject{|sum, x| sum.to_i + x.to_i}
    cpu_idle_new = cpu_times[3].to_i

    cpu_total_delta = (cpu_total_new - cpu_total_old).to_f
    cpu_idle_delta = (cpu_idle_new - cpu_idle_old).to_f
    unless cpu_total_delta == 0
      cpu_usage = 100 - ((cpu_idle_new - cpu_idle_old).to_f / (cpu_total_new - cpu_total_old).to_f * 100)
      puts "CPU% - #{cpu_usage}"

      if !csvfile.nil?
        csvfile.write("#{cpu_usage},")
      end

      cpu_total_old = cpu_total_new
      cpu_idle_old = cpu_idle_new

      nvidia_output.scan(/.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*/m) do |gpu, mem|
        puts "GPU% - #{gpu}"
        puts "GPU MEM% - #{mem}"

        if !csvfile.nil?
          csvfile.write("#{gpu},#{mem},\n")
        end
      end

      puts "--"
      sleep(1)
    end
  end
end # File.open('/proc/stat', 'r') do |stat|

if !csvfile.nil?
  csvfile.close
end
