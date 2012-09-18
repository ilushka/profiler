#! /usr/bin/ruby

File.open('/proc/stat', 'r') do |stat|
  # File.open('/proc/uptime', 'r') do |uptime|
    stat.seek(0, IO::SEEK_SET)
    # uptime.seek(0, IO::SEEK_SET)
    stat_output = stat.gets
    # uptime_output = uptime.gets

    cpu_times = stat_output.scan(/cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)[0]
    cpu_time_total_old = cpu_times.inject{|sum, x| sum.to_i + x.to_i}
    cpu_idle_old = cpu_times[3].to_i
    # uptime_total_old = uptime_output.scan(/(\d+\.\d+)\s.+/)[0][0].to_f

    loop do
      # gather all data first
      stat.seek(0, IO::SEEK_SET)
      # uptime.seek(0, IO::SEEK_SET)
      stat_output = stat.gets
      # uptime_output = uptime.gets
      nvidia_output = `nvidia-smi -q --display=UTILIZATION`

      cpu_times = stat_output.scan(/cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)[0]
      cpu_time_total_new = cpu_times.inject{|sum, x| sum.to_i + x.to_i}
      cpu_idle_new = cpu_times[3].to_i
      begin
        puts "CPU% - #{100 - ((cpu_idle_new - cpu_idle_old).to_f / (cpu_time_total_new - cpu_time_total_old).to_f * 100)}"
      rescue Exception => e
        # ignore division by zero
      end

      # uptime_total_new = uptime_output.scan(/(\d+\.\d+)\s.+/)[0][0].to_f

      cpu_time_total_old = cpu_time_total_new
      cpu_idle_old = cpu_idle_new
      # uptime_total_old = uptime_total_new

      nvidia_output.scan(/.*Gpu\s+\:\s(\d+)\s\%.*Memory\s+\:\s(\d+)\s\%.*/m) do |gpu, mem|
        puts "GPU% - #{gpu}"
        puts "GPU MEM% - #{mem}"
      end

      puts "--"
      sleep(1)
    end
  # end
end
