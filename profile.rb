#! /usr/bin/ruby

require 'optparse'

csvfile = nil
dualgpu = false

opt_parse = OptionParser.new do |opt_parse|
  opt_parse.banner = "Usage: profile.rb [options]"
  opt_parse.separator ""
  opt_parse.separator "Options:"

  opt_parse.on("--dualgpu", "Collect usage from two GPUs.") do |arg|
    dualgpu = true
  end

  opt_parse.on("--csvfile FILENAME", "Save CPU, GPU, GPU memory usage in CSV format to FILENAME.") do |csvfilename|
    csvfile = File.open(csvfilename, 'w')
    if dualgpu
      csvfile.write("CPU%,GPU0%,GPU0 Mem%,GPU1%,GPU1 Mem%,\n")
    else
      csvfile.write("CPU%,GPU%,GPU Mem%,\n")
    end
  end

  opt_parse.on_tail("--help", "Show this message.") do
    puts opt_parse
    exit
  end
end # opt_parse = OptionParse new do |opt_parse|

opt_parse.parse!(ARGV)

def parse_single_gpu_usage(output, csvfile)
  output.scan(/.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*/m) do |gpu, mem|
    puts "GPU% - #{gpu}"
    puts "GPU MEM% - #{mem}"

    if !csvfile.nil?
      csvfile.write("#{gpu},#{mem},\n")
    end
  end
end

def parse_dual_gpu_usage(output, csvfile)
  output.scan(/.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*/m) do |gpu0, mem0, gpu1, mem1|
    puts "GPU0% - #{gpu0}"
    puts "GPU0 MEM% - #{mem0}"
    puts "GPU1% - #{gpu1}"
    puts "GPU1 MEM% - #{mem1}"

    if !csvfile.nil?
      csvfile.write("#{gpu0},#{mem0},#{gpu1},#{mem1},\n")
    end
  end
end

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

        if dualgpu
          parse_dual_gpu_usage(nvidia_output, csvfile)
        else
          parse_single_gpu_usage(nvidia_output, csvfile)
        end

        puts "--"
        sleep(1)
      end
    end
  end # File.open('/proc/stat', 'r') do |stat|

  if !csvfile.nil?
    csvfile.close
  end
rescue SystemExit, Interrupt
  puts "\n ### EXITING ###"
  `./copycsv.sh`
end
