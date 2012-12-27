require 'rubygems'
require 'google_drive'

class ReportCreator
  REPORT_TEMPLATE_ADDR = 'https://docs.google.com/spreadsheet/ccc?key=0ArmaMDqoHvnNdE8zTE9pMkw1VUlZTkVYYlhNeXc4WGc'

  def get_line_count(filename)
    Integer(`wc -l #{filename}`.split[0])
  end

  def get_csv_counts(path = './remote*_fps.csv')
    counts = Hash.new

    Dir.glob(path) do |filename|
      counts[filename] = get_line_count(filename)
    end

    #counts.sort_by {|key, val| val}.last[1]
    counts
  end

  #def pad_csv_files(count, path = './remote*_fps.csv')
  #  Dir.glob(path) do |filename|
  #    diff_count = count - get_line_count(filename)
  #
  #    if diff_count > 0 
  #      File.open('temp.csv', 'w') do |file|
  #        while diff_count > 0
  #          file.puts "0\n"
  #          diff_count = diff_count - 1
  #        end 
  #
  #        file.write(File.open(filename, 'r').read())
  #        `mv #{filename} #{filename}.bak`
  #        `mv temp.csv #{filename}`
  #      end
  #    end
  #  end
  #end

  def add_fps_files_to_spreadsheet(spreadsheet, path = './remote*_fps.csv')
    csv_counts = get_csv_counts(path).sort_by {|key, val| val}.reverse!
    highest_count = csv_counts.first[1]
    ws_num = 1

    csv_counts.each do |fc|
      diff_count = highest_count - fc[1]
      row_idx = 1
      ws_name = "Session #{ws_num}"

      print "Adding worksheet: #{ws_name}"

      worksheet = spreadsheet.add_worksheet(ws_name)
      worksheet[row_idx, 1] = ws_name
      row_idx += 1

      if diff_count > 0 
        while diff_count > 0
          worksheet[row_idx, 1] = 0
          row_idx += 1
          diff_count -= 1
        end 
      end

      File.open(fc[0], 'r') do |f|
        while line = f.gets
          worksheet[row_idx, 1] = Float(line.scan(/[\d\.]+/).first)
          row_idx += 1
        end
      end

      ws_num += 1
      worksheet.save()

      puts " - Done."
    end
  end

  def add_usage_file_to_spreadsheet(spreadsheet, path = './usage.csv')
    File.open(path) do |file|
      row_idx = 1

      print "Adding worksheet: #{File.basename(file)}"

      worksheet = spreadsheet.add_worksheet(File.basename(file))
      worksheet[row_idx, 1] = "CPU%"
      worksheet[row_idx, 2] = "GPU%"
      worksheet[row_idx, 3] = "MEM%"
      row_idx += 1

      while line = file.gets
        data = line.split(',')

        begin
          worksheet[row_idx, 1] = Float(data[0])
          worksheet[row_idx, 2] = Float(data[1])
          worksheet[row_idx, 3] = Float(data[2])
        rescue => e
          next
        else
          row_idx += 1
        end
      end

      worksheet.save()

      puts " - Done."
    end
  end

  def create_report(username, password, report_name = 'profiler_report')
    session = GoogleDrive.login(username, password)
    template = session.spreadsheet_by_url(REPORT_TEMPLATE_ADDR)
    spreadsheet = template.duplicate(report_name)

    add_fps_files_to_spreadsheet(spreadsheet)
    add_usage_file_to_spreadsheet(spreadsheet)
  end

  private :get_line_count
  private :get_csv_counts
  private :add_fps_files_to_spreadsheet
  private :add_usage_file_to_spreadsheet
end

