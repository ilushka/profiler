require 'rubygems'
require 'google_drive'

class ReportCreator
  def find_most_csv_values(path = './remote*_fps.csv')
    counts = Hash.new

    Dir.glob(path) do |filename|
      #count = File.read(filename).strip.split(',').length
      count = `wc -l #{filename}`.split[0]
      counts[filename] = Integer(count)
    end

    counts.sort_by {|key, val| val}.last[1]
  end

  def pad_csv_files(count, path = './remote*_fps.csv')
    Dir.glob(path) do |filename|
      curr_count = Integer(`wc -l #{filename}`.split[0])
      diff_count = count - curr_count

      if diff_count > 0 
        File.open('temp.csv', 'w') do |file|
          while diff_count > 0
            file.puts "0\n"
            diff_count = diff_count - 1
          end 

          file.write(File.open(filename, 'r').read())
          `mv #{filename} #{filename}.bak`
          `mv temp.csv #{filename}`
        end
      end
    end
  end

  def add_csv_files_to_spreadsheet(spreadsheet, path = './remote*_fps.csv')
    highest_count = find_most_csv_values

    Dir.glob(path) do |filename|
      diff_count = highest_count - Integer(`wc -l #{filename}`.split[0])
      row_idx = 1

      print "Adding worksheet: #{File.basename(filename)}"

      worksheet = spreadsheet.add_worksheet(File.basename(filename))

      if diff_count > 0 
        while row_idx <= diff_count
          worksheet[row_idx, 1] = 0
          row_idx = row_idx + 1
        end 
      end

      File.open(filename, 'r') do |f|
        while line = f.gets
          worksheet[row_idx, 1] = Float(line.scan(/[\d\.]+/).first)
          row_idx = row_idx + 1
        end
      end

      worksheet.save()

      puts " - Done."
    end
  end

  def add_usage_file_to_spreadsheet(spreadsheet, path = './usage.csv')
    File.open(path) do |file|
      print "Adding worksheet: #{File.basename(file)}"

      worksheet = spreadsheet.add_worksheet(File.basename(file))
      cpu = 0.0
      gpu = 0.0
      mem = 0.0
      row_idx = 1

      while line = file.gets
        data = line.split(',')

        begin
          cpu = Float(data[0]) 
          gpu = Float(data[1])
          mem = Float(data[2])
        rescue => e
          next
        else
          worksheet[row_idx, 1] = cpu
          worksheet[row_idx, 2] = gpu
          worksheet[row_idx, 3] = mem
          row_idx = row_idx + 1
        end
      end

      worksheet.save()

      puts " - Done."
    end
  end

  def create_report(username, password, report_name = 'profiler_report')
    session = GoogleDrive.login(username, password)
    template = session.spreadsheet_by_url('https://docs.google.com/spreadsheet/ccc?key=0ArmaMDqoHvnNdE8zTE9pMkw1VUlZTkVYYlhNeXc4WGc')
    spreadsheet = template.duplicate(report_name)

    add_csv_files_to_spreadsheet(spreadsheet)
    add_usage_file_to_spreadsheet(spreadsheet)
  end
end
