#! /usr/bin/ruby

require 'optparse'
require 'highline/import'
require_relative 'report-creator'

# Defaults:
csvfile = nil
dualgpu = false

def parse_single_gpu_usage(output, csvfile)
  output.scan(/.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*/m) do |gpu, mem|
    puts "GPU% - #{gpu}"
    puts "GPU MEM% - #{mem}"
    csvfile.write("#{gpu},#{mem},") if !csvfile.nil?
    return
  end

  puts "GPU% - 0.0"
  puts "GPU MEM% - 0.0"
  csvfile.write("0.0,0.0,") if !csvfile.nil?
end

def parse_dual_gpu_usage(output, csvfile)
  output.scan(/.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*/m) do |gpu0, mem0, gpu1, mem1|
    puts "GPU0% - #{gpu0}"
    puts "GPU0 MEM% - #{mem0}"
    puts "GPU1% - #{gpu1}"
    puts "GPU1 MEM% - #{mem1}"
    csvfile.write("#{gpu0},#{mem0},#{gpu1},#{mem1},") if !csvfile.nil?
    return
  end

  puts "GPU0% - 0.0"
  puts "GPU0 MEM% - 0.0"
  puts "GPU1% - 0.0"
  puts "GPU1 MEM% - 0.0"
  csvfile.write("0.0,0.0,0.0,0.0,") if !csvfile.nil?
end

def parse_mem_usage(output, csvfile)
  usage = output.scan(/(\d+)/)
  used = (usage[6].first.to_f / usage[0].first.to_f) * 100

  puts "SYS MEM% - #{used}"
  csvfile.write("#{used},") if !csvfile.nil?
end

def parse_mem_usage(output, csvfile)
  usage = output.scan(/(\d+)/)
  used = (usage[6].first.to_f / usage[0].first.to_f) * 100

  puts "SYS MEM% - #{used}"
  csvfile.write("#{used},") if !csvfile.nil?
end

def get_google_credentials()
  username = ask("Enter Username:") {|q| q.echo = true}
  password = ask("\nEnter Password:") {|q| q.echo = false}
  {:username => username, :password => password}
end

opt_parse = OptionParser.new do |opt_parse|
  opt_parse.banner = "Usage: profile.rb [options]"
  opt_parse.separator ""
  opt_parse.separator "Options:"

  opt_parse.on("--dualgpu", "Collect usage from two GPUs.") do |arg|
    dualgpu = true
  end

  opt_parse.on("--csvfile FILENAME", "Save CPU, GPU, GPU memory usage in CSV format to FILENAME.") do |csvfilename|
    csvfile = File.open(csvfilename, 'w')
#
#    if dualgpu
#      csvfile.write("CPU%,GPU0%,GPU0 Mem%,GPU1%,GPU1 Mem%,\n")
#    else
#      csvfile.write("CPU%,GPU%,GPU Mem%,\n")
#    end
  end

  opt_parse.on("--create-report", "Create report in Google Docs, don't collect any data.") do |arg|
    creds = get_google_credentials()
    rc = ReportCreator.new
    rc.create_report(creds[:username], creds[:password])
    exit
  end

  opt_parse.on_tail("--help", "Show this message.") do
    puts opt_parse
    exit
  end
end # opt_parse = OptionParse new do |opt_parse|

opt_parse.parse!(ARGV)

# Start the usage stats collection loop:
begin
  File.open('/proc/stat', 'r') do |stat|
    stat.seek(0, IO::SEEK_SET)
    stat_output = stat.gets

    cpu_times = stat_output.scan(/cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)[0]
    cpu_total_old = cpu_times.inject{|sum, x| sum.to_i + x.to_i}
    cpu_idle_old = cpu_times[3].to_i

    loop do
      stat.seek(0, IO::SEEK_SET)
      stat_output = stat.gets

      cpu_times = stat_output.scan(/cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)[0]
      cpu_total_new = cpu_times.inject{|sum, x| sum.to_i + x.to_i}
      cpu_idle_new = cpu_times[3].to_i
      cpu_total_delta = (cpu_total_new - cpu_total_old).to_f
      cpu_idle_delta = (cpu_idle_new - cpu_idle_old).to_f

      unless cpu_total_delta == 0 # can be the case with the first entry
        cpu_usage = 100 - ((cpu_idle_new - cpu_idle_old).to_f / (cpu_total_new - cpu_total_old).to_f * 100)
        cpu_total_old = cpu_total_new
        cpu_idle_old = cpu_idle_new

        puts "CPU% - #{cpu_usage}"
        csvfile.write("#{cpu_usage},") if !csvfile.nil?

        parse_mem_usage(`free`, csvfile)

        if dualgpu
          parse_dual_gpu_usage(`nvidia-smi -q --display=UTILIZATION`, csvfile)
        else
          parse_single_gpu_usage(`nvidia-smi -q --display=UTILIZATION`, csvfile)
        end

        csvfile.write("\n") if !csvfile.nil?
        puts "--"
        sleep(1)
      end
    end
  end # File.open('/proc/stat', 'r') do |stat|

  csvfile.close if !csvfile.nil?
rescue SystemExit, Interrupt
  if !csvfile.nil?
    puts "\n########## Exiting, Creating Report ##########\n\n"
    csvfile.close
    `./copycsv.sh`

    creds = get_google_credentials()
    rc = ReportCreator.new
    rc.create_report(creds[:username], creds[:password])
  end
end
